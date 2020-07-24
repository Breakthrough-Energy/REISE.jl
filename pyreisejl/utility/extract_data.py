from collections import OrderedDict
import datetime as dt
import glob
import io
import os
import subprocess
import time

import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat
from tqdm import tqdm

from pyreisejl.utility import const
from pyreisejl.utility.helpers import load_mat73


def get_scenario(scenario_id):
    """Returns scenario information.

    :param str scenario_id: scenario index.
    :return: (*dict*) -- scenario information.
    """
    scenario_list = pd.read_csv(const.SCENARIO_LIST, dtype=str)
    scenario_list.fillna("", inplace=True)
    scenario = scenario_list[scenario_list.id == scenario_id]

    return scenario.to_dict("records", into=OrderedDict)[0]


def insert_in_file(filename, scenario_id, column_number, column_value):
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


def _get_outputs_id(folder):
    """Get output id for each applicate output.

    :param str folder: path to folder with input case files.
    :return: (*dict*) -- dictionary of {output_name: column_indices}
    """
    case = loadmat(
        os.path.join(folder, "case.mat"), squeeze_me=True, struct_as_record=False
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

    return outputs_id


def extract_data(scenario_info):
    """Builds data frames of {PG, PF, LMP, CONGU, CONGL} from Julia simulation
        output binary files produced by REISE.jl.

    :param dict scenario_info: scenario information.
    :return: (*pandas.DataFrame*) -- data frames of:
        PG, PF, LMP, CONGU, CONGL, LOAD_SHED.
    """
    infeasibilities = []
    cost = []
    setup_time = []
    solve_time = []
    optimize_time = []

    extraction_vars = {"pf", "pg", "lmp", "congu", "congl"}
    sparse_extraction_vars = {"congu", "congl", "load_shed"}
    temps = {}
    outputs = {}

    folder = os.path.join(const.EXECUTE_DIR, "scenario_%s" % scenario_info["id"])
    end_index = len(glob.glob(os.path.join(folder, "output", "result_*.mat")))

    tic = time.process_time()
    for i in tqdm(range(end_index)):
        filename = "result_" + str(i) + ".mat"

        output = load_mat73(os.path.join(folder, "output", filename))

        try:
            cost.append(output["mdo_save"]["results"]["f"][0][0])
        except KeyError:
            pass

        demand_scaling = output["mdo_save"]["demand_scaling"][0][0]
        if demand_scaling < 1:
            demand_change = round(100 * (1 - demand_scaling))
            infeasibilities.append("%s:%s" % (str(i), str(demand_change)))
        output_mpc = output["mdo_save"]["flow"]["mpc"]
        temps["pg"] = output_mpc["gen"]["PG"].T
        temps["pf"] = output_mpc["branch"]["PF"].T
        temps["lmp"] = output_mpc["bus"]["LAM_P"].T
        temps["congu"] = output_mpc["branch"]["MU_SF"].T
        temps["congl"] = output_mpc["branch"]["MU_ST"].T
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
            if v not in outputs:
                interval_length, n_columns = temps[v].shape
                total_length = end_index * interval_length
                outputs[v] = pd.DataFrame(np.zeros((total_length, n_columns)))
                outputs[v].name = str(scenario_info["id"]) + "_" + v.upper()
            start_hour, end_hour = (i * interval_length), ((i + 1) * interval_length)
            outputs[v].iloc[start_hour:end_hour, :] = temps[v]

    print(extraction_vars)

    toc = time.process_time()
    print("Reading time " + str(round(toc - tic)) + "s")

    # Write infeasibilities
    insert_in_file(
        const.SCENARIO_LIST, scenario_info["id"], "16", "_".join(infeasibilities)
    )

    # Build log: costs from matfiles, file attributes from ls/awk
    log = pd.DataFrame(data={"cost": cost})
    file_filter = os.path.join(folder, "output", "result_*.mat")
    ls_options = '-lrt --time-style="+%Y-%m-%d %H:%M:%S" ' + file_filter
    awk_options = "-v OFS=','"
    awk_program = (
        '\'BEGIN{print "filesize,datetime,filename"}; '
        'NR >0 {print $5, $6" "$7, $8}\''
    )
    ls_call = "ls %s | awk %s %s" % (ls_options, awk_options, awk_program)
    ls_output = subprocess.Popen(ls_call, shell=True, stdout=subprocess.PIPE)
    utf_ls_output = io.StringIO(ls_output.communicate()[0].decode("utf-8"))
    properties_df = pd.read_csv(utf_ls_output, sep=",", dtype=str)
    log["filesize"] = properties_df.filesize
    log["write_datetime"] = properties_df.datetime
    # Write log
    log_filename = scenario_info["id"] + "_log.csv"
    log.to_csv(os.path.join(const.OUTPUT_DIR, log_filename), header=True)

    # Set index of data frame
    date_range = pd.date_range(
        scenario_info["start_date"], scenario_info["end_date"], freq="H"
    )

    for v in extraction_vars:
        outputs[v].index = date_range
        outputs[v].index.name = "UTC"

    # Get/set index column name of data frame
    outputs_id = _get_outputs_id(folder)
    for k in outputs:
        index = outputs_id[k]
        if isinstance(index, int):
            outputs[k].columns = [index]
        else:
            outputs[k].columns = index.tolist()

    print("converting to float32")
    for v in extraction_vars:
        outputs[v] = outputs[v].astype(np.float32)

    # Convert outputs with many zero or near-zero values to sparse dtype
    to_sparsify = set(extraction_vars) & sparse_extraction_vars
    print("sparsifying", to_sparsify)
    for v in to_sparsify:
        outputs[v] = outputs[v].round(6).astype(pd.SparseDtype("float", 0))

    return outputs


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
            raise TypeError("%s must be a pandas data frame" % k)

    if congl.shape != congu.shape:
        raise ValueError("%data frame must have same shape")

    if not all(congl.columns == congu.columns):
        raise ValueError("%data frame must have same indices")

    mean_congl = congl.mean()
    mean_congl.name = "CONGL"
    mean_congu = congu.mean()
    mean_congu.name = "CONGU"

    return pd.merge(mean_congl, mean_congu, left_index=True, right_index=True)


def copy_input(scenario_id):
    """Copies input file, converting matfile from v7.3 to v7 on the way.

    :param str scenario_id: scenario id
    """
    src = os.path.join(
        const.EXECUTE_DIR, "scenario_%s" % scenario_id, "output", "input.mat"
    )
    dst = os.path.join(const.INPUT_DIR, "%s_grid.mat" % scenario_id)
    print("loading and parsing input.mat")
    input_mpc = load_mat73(src)
    print("saving converted input.mat as %s_grid.mat" % scenario_id)
    savemat(dst, input_mpc, do_compression=True)


def delete_output(scenario_id):
    """Deletes output MAT-files.

    :param str scenario_id: scenario id.
    """
    folder = os.path.join(const.EXECUTE_DIR, "scenario_%s" % scenario_id, "output")
    files = glob.glob(os.path.join(folder, "result_*.mat"))
    for f in files:
        os.remove(f)


def extract_scenario(scenario_id):
    """Extracts data and save data as pickle files.

    :param str scenario_id: scenario id.
    """

    scenario_info = get_scenario(scenario_id)

    copy_input(scenario_id)

    outputs = extract_data(scenario_info)
    print("saving pickles")
    for k, v in outputs.items():
        pickle_filename = scenario_info["id"] + "_" + k.upper() + ".pkl"
        v.to_pickle(os.path.join(const.OUTPUT_DIR, pickle_filename))

    calculate_averaged_congestion(outputs["congl"], outputs["congu"]).to_pickle(
        os.path.join(const.OUTPUT_DIR, scenario_info["id"] + "_AVERAGED_CONG.pkl")
    )

    insert_in_file(const.EXECUTE_LIST, scenario_info["id"], "2", "extracted")
    insert_in_file(const.SCENARIO_LIST, scenario_info["id"], "4", "analyze")

    print("deleting matfiles")
    delete_output(scenario_id)


if __name__ == "__main__":
    import sys

    extract_scenario(sys.argv[1])
