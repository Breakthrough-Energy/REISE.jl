from collections import OrderedDict
import datetime as dt
import glob
import os
import subprocess
import time

import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat
from tqdm import tqdm

import const
from helpers import load_mat73

def copy_input(execute_dir, output_dir=None, filename = "grid.mat"):
    """Copies Julia-saved input file, converting matfile from v7.3 to v7 on the way.

    :param str execute_dir: the directory containing the original input file
    :param str output_dir: the optional directory to which to save the converted input file, Defaults to execute_dir
    :param str filename: optional name for the copied input.mat file. Defaults to "grid.mat"
    """
    if not output_dir:
        output_dir = execute_dir
        
    src = os.path.join(execute_dir, "input.mat")
    dst = os.path.join(output_dir, filename)
    print("loading and parsing input.mat")
    input_mpc = load_mat73(src)
    print(f"saving converted input.mat as {filename}")
    savemat(dst, input_mpc, do_compression=True)

def extract_data(execute_dir):
    """Builds data frames of {PG, PF, LMP, CONGU, CONGL} from Julia simulation
        output binary files produced by REISE.jl.

    :param dict scenario_info: scenario information.
    :return: (*pandas.DataFrame*) -- data frames of:
        PG, PF, LMP, CONGU, CONGL, LOAD_SHED.
    """

    end_index = len(glob.glob(os.path.join(execute_dir, "result_*.mat")))

    infeasibilities = []
    cost = []
    
    extraction_vars = {"pf", "pg", "lmp", "congu", "congl"}
    sparse_extraction_vars = {"congu", "congl", "load_shed"}
    temps = {}
    outputs = {}

    tic = time.process_time()
    for i in tqdm(range(end_index)):
        # For each result_#.mat file
        filename = "result_" + str(i) + ".mat"
        output = load_mat73(os.path.join(execute_dir, filename))

        # Record cost for this mat file
        try:
            cost.append(output["mdo_save"]["results"]["f"][0][0])
        except KeyError:
            pass

        # Check for infeasibilities
        demand_scaling = output["mdo_save"]["demand_scaling"][0][0]
        if demand_scaling < 1:
            demand_change = round(100 * (1 - demand_scaling))
            infeasibilities.append(f"{i}:{demand_change}")

        # Extract various variables
        output_mpc = output["mdo_save"]["flow"]["mpc"]

        temps["pg"] = output_mpc["gen"]["PG"].T
        temps["pf"] = output_mpc["branch"]["PF"].T
        temps["lmp"] = output_mpc["bus"]["LAM_P"].T
        temps["congu"] = output_mpc["branch"]["MU_SF"].T
        temps["congl"] = output_mpc["branch"]["MU_ST"].T

        # Extract optional variables (not present in all scenarios)
        try:
            temps["pf_dcline"] = output_mpc["dcline"]["PF_dcline"].T
            extraction_vars |= {"pf_dcline"}
        except KeyError:
            pass

        try:
            temps["storage_pg"] = output_mpc["storage"]["PG"].T
            temps["storage_e"] = output_mpc["storage"]["Energy"].T
            extraction_vars |= {"storage_pg", "storage_e"}
        except KeyError:
            pass
        try:
            temps["load_shed"] = output_mpc["load_shed"]["load_shed"].T
            extraction_vars |= {"load_shed"}
        except KeyError:
            pass


        for v in extraction_vars:
            # If this extraction variables hasn't been seen yet, initialize all zeros            
            if v not in outputs:
                interval_length, n_columns = temps[v].shape
                total_length = end_index * interval_length
                outputs[v] = pd.DataFrame(np.zeros((total_length, n_columns)))
            # Update the temp variables for the time frame with the extracted data
            start_hour, end_hour = (i * interval_length), ((i + 1) * interval_length)
            outputs[v].iloc[start_hour:end_hour, :] = temps[v]

    # Record time to read all the data
    toc = time.process_time()
    print("Reading time " + str((toc - tic)) + "s")
    
    # Convert everything except sparse variables to float32
    for v in extraction_vars - sparse_extraction_vars:
        outputs[v] = outputs[v].astype(np.float32)
 
    # Convert outputs with many zero or near-zero values to sparse dtype
    # As identified in sparse_extraction_vars
    to_sparsify = extraction_vars & sparse_extraction_vars
    print("sparsifying", to_sparsify)
    for v in to_sparsify:
        outputs[v] = outputs[v].round(6).astype(pd.SparseDtype("float", 0))

    return outputs, infeasibilities, cost


def calculate_averaged_congestion(congl, congu):
    """Calculates the averaged congestion lower (upper) flow limit.

    :param pandas.DataFrame congl: congestion lower power flow limit.
    :param pandas.DataFrame congu: congestion upper power flow limit.
    :return: (*pandas.DataFrame*) -- averaged congestion power flow limit.
        Indices are the branch id and columns are the averaged congestion lower
        and upper power flow limit.
    :raises TypeError: if arguments are not data frame.
    :raises ValueError: if shape or indices of data frames differ.
    """

    for k, v in locals().items():
        if not isinstance(v, pd.DataFrame):
            raise TypeError(f"{k} must be a pandas data frame")

    if congl.shape != congu.shape:
        raise ValueError("Data frames congu and congl must have same shape")

    if not all(congl.columns == congu.columns):
        raise ValueError("Data frames congu and congl must have same indices")

    mean_congl = congl.mean()
    mean_congl.name = "CONGL"
    mean_congu = congu.mean()
    mean_congu.name = "CONGU"

    return pd.merge(mean_congl, mean_congu, left_index=True, right_index=True)



def _insert_in_file(filename, scenario_id, column_number, column_value):
    """Updates status in execute list on server.

    :param str filename: path to execute or scenario list.
    :param str scenario_id: scenario index.
    :param str column_number: id of column (indexing starts at 1).
    :param str column_value: value to insert.
    """
    options = "-F, -v OFS=',' -v INPLACE_SUFFIX=.bak -i inplace"
    program = "'{for(i=1; i<=NF; i++){if($1==%s) $%s=\"%s\"}};1'" % (
        scenario_id,
        column_number,
        column_value,
    )
    command = "awk %s %s %s" % (options, program, filename)
    os.system(command)

def _get_pkl_path(output_dir, scenario_id=None):
    prepend = scenario_id + '_' if scenario_id else ''

    return (lambda x: os.path.join(output_dir, prepend + x + '.pkl'))

def build_log(execute_dir, cost, output_dir, scenario_id):
    """Build log recording the cost, filesize, and time for each mat file

    :param list cost: list of costs
    """

    # Build log: costs from matfiles, file attributes
    log = pd.DataFrame(data={"cost": cost})
    results = glob.glob(os.path.join(execute_dir, "result_*.mat"))

    # Sort the result files so the log file is in order
    results = sorted(results, key=os.path.getmtime())
    
    for result in results:
        log["filesize"] = os.stat(result).st_size
        log["write_datetime"] = os.stat(result).st_mtime

    # Write log
    log_filename = scenario_id + "_log.csv" if scenario_id else "log.csv"

    log.to_csv(os.path.join(output_dir, log_filename), header=True)


def _get_outputs_id(folder):
    """Get output id for each applicate output.

    :param str folder: path to folder with input case files.
    :return: (*dict*) -- dictionary of {output_name: column_indices}
    """
    case = loadmat(folder + "/case.mat", squeeze_me=True, struct_as_record=False
    )

    outputs_id = {
        "pg": case["mpc"].genid,
        "pf": case["mpc"].branchid,
        "lmp": case["mpc"].bus[:, 0].astype(np.int64),
        "load_shed": case["mpc"].bus[:, 0].astype(np.int64),
        "congu": case["mpc"].branchid,
        "congl": case["mpc"].branchid,
    }
    
    try:
        outputs_id["pf_dcline"] = case["mpc"].dclineid
    except AttributeError:
        pass
    
    try:
        case_storage = loadmat(
            os.path.join(folder, "case_storage"),
            squeeze_me=True,
            struct_as_record=False,
        )
        num_storage = len(case_storage["storage"].gen)
        outputs_id["storage_pg"] = np.arange(num_storage)
        outputs_id["storage_e"] = np.arange(num_storage)
    except FileNotFoundError:
        pass

    _cast_keys_as_lists(outputs_id)
    
    return outputs_id

def _get_outputs_from_converted(matfile):
    """Need to double check, but uses the converted grid.mat instead of the og case.mat and case_storage.mat files
    """
    case = loadmat(matfile, squeeze_me=True, struct_as_record=False)['mdi']

    outputs_id = {
        "pg": case.mpc.genid,
        "pf": case.mpc.branchid,
        "lmp": case.mpc.bus[:, 0].astype(np.int64),
        "load_shed": case.mpc.bus[:, 0].astype(np.int64),
        "congu": case.mpc.branchid,
        "congl": case.mpc.branchid,
    }
    
    try:
        outputs_id["pf_dcline"] = case.mpc.dclineid
    except AttributeError:
        pass
    
    try:
        num_storage = len(case.Storage.UnitIdx)
        outputs_id["storage_pg"] = np.arange(num_storage)
        outputs_id["storage_e"] = np.arange(num_storage)
    except FileNotFoundError:
        pass

    _cast_keys_as_lists(outputs_id)
    
    return outputs_id


def _cast_keys_as_lists(dictionary):
    """Converts dictionary with values that are ints or numpy arrays to lists.

    :param dict dictionary: dictionary with values that are ints or numpy arrays
    :return: (*dict*) -- the same dictionary where the values are lists
    """
    for key, value in dictionary.items():
        if type(value) == int:
            dictionary[key] = [value]
        else:
            dictionary[key] = value.tolist()



def delete_output(execute_dir):
    """Deletes output MAT-files.

    :param str scenario_id: scenario id.
    """
    files = glob.glob(os.path.join(execute_dir, "result_*.mat"))
    for f in files:
        os.remove(f)

def _update_outputs_labels(outputs, start_date, end_date, freq, matfile):
    """Updates outputs with the correct date index and column names

    :param pandas.DataFrame outputs: 
    :param str start_date:
    :param str end_date:
    :param str matfile:
    """
    # Set index of data frame
    date_range = pd.date_range(start_date, end_date, freq)

    outputs_id = _get_outputs_from_converted(matfile)

    for k in outputs:
        outputs[k].index = date_range
        outputs[k].index.name = "UTC"

        outputs[k].columns = outputs_id[k]


def extract_scenario(execute_dir, start_date, end_date, scenario_id=None, output_dir=None, input_dir=None, freq="H"):
    """Extracts data and save data as pickle files to the output directory

    :param str execute_dir: directory containing all of the result.mat files from REISE.jl
    :param str start_date: the start date of the simulation run
    :param str end_date: the end date of the simulation run
    :param str scenario_id: optional identifier for the scenario, used to label output files
    :param str output_dir: optional directory in which to store the outputs. defaults to the execute_dir
    :param str input_dir: optional directory in which to store the converted grid.mat file. defaults to the execute_dir
    """

    # If output or input dir were not specified, default to the execute_dir
    output_dir = output_dir or execute_dir
    input_dir = input_dir or execute_dir

    # Copy input.mat from REISE.jl and convert to .mat v7 for scipy compatibility
    copy_input(execute_dir, input_dir)

    # Extract outputs, infeasibilities, cost
    outputs, infeasibilities, cost = extract_data(execute_dir)

    # Write infeasibilities
    print(infeasibilities)
    # insert_in_file(
    #     const.SCENARIO_LIST, scenario_info["id"], "16", "_".join(infeasibilities)
    # )    
    
    # Write log file with costs
    build_log(execute_dir, cost, output_dir, scenario_id)


    # Update outputs with date indices
    _update_outputs_labels(outputs, start_date, end_date, freq, output_dir + '/grid.mat')

    # Save pickles
    pkl_path = _get_pkl_path(output_dir, scenario_id)
    
    for k, v in outputs.items():
        v.to_pickle(pkl_path(k.upper()))

    # Calculate and save averaged congestion
    calculate_averaged_congestion(outputs["congl"], outputs["congu"]).to_pickle(
        pkl_path("AVERAGED_CONG")
    )


    # insert_in_file(const.EXECUTE_LIST, scenario_info["id"], "2", "extracted")
    # insert_in_file(const.SCENARIO_LIST, scenario_info["id"], "4", "analyze")

    print("deleting matfiles")
    delete_output(output_dir)


# if __name__ == "__main__":
#     import sys

#     extract_scenario(sys.argv[1])
