import glob
import os
import re
import time

import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat
from tqdm import tqdm

from pyreisejl.utility import const, parser
from pyreisejl.utility.helpers import (
    WrongNumberOfArguments,
    get_scenario,
    insert_in_file,
    load_mat73,
    validate_time_format,
)


def copy_input(execute_dir, mat_dir=None, scenario_id=None):
    """Copies Julia-saved input matfile (input.mat), converting matfile from v7.3 to v7 on the way.

    :param str execute_dir: the directory containing the original input file
    :param str mat_dir: the optional directory to which to save the converted input file, Defaults to execute_dir
    :param str filename: optional name for the copied input.mat file. Defaults to "grid.mat"
    """
    if not mat_dir:
        mat_dir = execute_dir

    src = os.path.join(execute_dir, "input.mat")

    filename = scenario_id + "_grid.mat" if scenario_id else "grid.mat"
    dst = os.path.join(mat_dir, filename)
    print("loading and parsing input.mat")
    input_mpc = load_mat73(src)
    print(f"saving converted input.mat as {filename}")
    savemat(dst, input_mpc, do_compression=True)

    return dst


def result_num(filename):
    """Parses the number out of a filename in the format *result_{number}.mat

    :param str filename: the filename from which to extract the result number
    :return: (*int*) the result number
    """
    match = re.match(r".*?result_(?P<num>\d+)\.mat$", filename)

    return int(match.group("num"))


def extract_data(results):
    """Builds data frames of {PG, PF, LMP, CONGU, CONGL} from Julia simulation
        output binary files produced by REISE.jl.

    :param list results: list of result files
    :return: (*tuple*) -- first element is a dictionary of Pandas data frames of:
        PG, PF, LMP, CONGU, CONGL, LOAD_SHED, second is a list of strings of infeasibilities,
        and the third element is a list of numpy.float64 costs for each file in the input results list
    """

    infeasibilities = []
    cost = []

    extraction_vars = {"pf", "pg", "lmp", "congu", "congl"}
    sparse_extraction_vars = {"congu", "congl", "load_shed"}
    temps = {}
    outputs = {}

    tic = time.process_time()
    for i, filename in tqdm(enumerate(results)):
        # For each result_#.mat file
        output = load_mat73(filename)

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
        try:
            temps["load_shift_dn"] = output_mpc["flexible_demand"]["load_shift_dn"].T
            temps["load_shift_up"] = output_mpc["flexible_demand"]["load_shift_up"].T
            extraction_vars |= {"load_shift_dn", "load_shift_up"}
        except KeyError:
            pass

        # Extract which number result currently being processed
        i = result_num(filename)

        for v in extraction_vars:
            # Determine start, end indices of the outputs where this iteration belongs
            interval_length, n_columns = temps[v].shape
            start_hour, end_hour = (i * interval_length), ((i + 1) * interval_length)
            # If this extraction variables hasn't been seen yet, initialize all zeros
            if v not in outputs:
                total_length = len(results) * interval_length
                outputs[v] = pd.DataFrame(np.zeros((total_length, n_columns)))
            # Update the output variables for the time frame with the extracted data
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


def _get_pkl_path(output_dir, scenario_id=None):
    """Generates a function to create the path for a .pkl file given

    :param str output_dir: the directory to save all the .pkl files
    :param str scenario_id: optional scenario ID number to prepend to each pickle file. Defaults to None.
    :return: (*func*) a function that take a (*str*) attribute name
    and returns a (*str*) path to the .pkl where it should be saved
    """
    prepend = scenario_id + "_" if scenario_id else ""

    return lambda x: os.path.join(output_dir, prepend + x.upper() + ".pkl")


def build_log(mat_results, costs, output_dir, scenario_id=None):
    """Build log recording the cost, filesize, and time for each mat file

    :param list mat_results: list of filenames for which to log information
    :param list costs: list of costs from extract_data corresponding to the mat files
    :param str output_dir: directory to save the log file
    :param str scenario_id: optional scenario ID number to prepend to the log
    """

    # Create log name
    log_filename = scenario_id + "_log.csv" if scenario_id else "log.csv"

    os.makedirs(output_dir, exist_ok=True)
    with open(os.path.join(output_dir, log_filename), "w") as log:
        # Write headers
        log.write(",cost,filesize,write_datetime\n")
        for i in range(len(costs)):
            result = mat_results[i]
            # Get filesize
            filesize = str(os.stat(result).st_size)
            # Get formatted ctime
            write_datetime = os.stat(result).st_ctime
            write_datetime = time.strftime(
                "%Y-%m-%d %H:%M:%S", time.localtime(write_datetime)
            )

            log_vals = [i, costs[i], filesize, write_datetime]
            log.write(",".join([str(val) for val in log_vals]) + "\n")


def _get_outputs_from_converted(matfile):
    """Get output id for each applicate output.

    :param dict matfile: dictionary representing the converted input.mat file outputted by REISE.jl
    :return: (*dict*) -- dictionary of {output_name: column_indices}
    """

    case = matfile["mdi"]

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
        storage_index = case.Storage.UnitIdx
        num_storage = 1 if isinstance(storage_index, float) else len(storage_index)
        outputs_id["storage_pg"] = np.arange(num_storage)
        outputs_id["storage_e"] = np.arange(num_storage)
    except AttributeError:
        pass

    try:
        outputs_id["load_shift_dn"] = case.mpc.bus[:, 0].astype(np.int64)
        outputs_id["load_shift_up"] = case.mpc.bus[:, 0].astype(np.int64)
    except AttributeError:
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


def _update_outputs_labels(outputs, start_date, end_date, freq, matfile):
    """Updates outputs with the correct date index and column names

    :param dict outputs: dictionary of pandas.DataFrames outputted by extract_data
    :param str start_date: start date used for the simulation
    :param str end_date: end date used for the simulation
    :param str freq: the frequency of timestamps in the input profiles as a pandas frequency alias
    :param dict matfile: dictionary representing the converted input.mat file outputted by REISE.jl
    """
    # Set index of data frame
    start_ts = validate_time_format(start_date)
    end_ts = validate_time_format(end_date, end_date=True)

    date_range = pd.date_range(start_ts, end_ts, freq=freq)

    outputs_id = _get_outputs_from_converted(matfile)

    for k in outputs:
        outputs[k].index = date_range
        outputs[k].index.name = "UTC"

        outputs[k].columns = outputs_id[k]


def extract_scenario(
    execute_dir,
    start_date,
    end_date,
    scenario_id=None,
    output_dir=None,
    mat_dir=None,
    freq="H",
    keep_mat=True,
):
    """Extracts data and save data as pickle files to the output directory

    :param str execute_dir: directory containing all of the result.mat files from REISE.jl
    :param str start_date: the start date of the simulation run
    :param str end_date: the end date of the simulation run
    :param str scenario_id: optional identifier for the scenario, used to label output files
    :param str output_dir: optional directory in which to store the outputs. defaults to the execute_dir
    :param str mat_dir: optional directory in which to store the converted grid.mat file. defaults to the execute_dir
    :param bool keep_mat: optional parameter to keep the large result*.mat files after the data has been extracted. Defaults to True.
    """

    # If output or input dir were not specified, default to the execute_dir
    output_dir = output_dir or execute_dir
    mat_dir = mat_dir or execute_dir

    # Copy input.mat from REISE.jl and convert to .mat v7 for scipy compatibility
    converted_mat_path = copy_input(execute_dir, mat_dir, scenario_id)

    # Extract outputs, infeasibilities, cost
    mat_results = glob.glob(os.path.join(execute_dir, "result_*.mat"))
    mat_results = sorted(mat_results, key=result_num)

    outputs, infeasibilities, cost = extract_data(mat_results)

    # Write log file with costs for each result*.mat file
    build_log(mat_results, cost, output_dir, scenario_id)

    # Update outputs with date indices from the copied input.mat file
    matfile = loadmat(converted_mat_path, squeeze_me=True, struct_as_record=False)
    _update_outputs_labels(outputs, start_date, end_date, freq, matfile)

    # Save pickles
    pkl_path = _get_pkl_path(output_dir, scenario_id)

    for k, v in outputs.items():
        v.to_pickle(pkl_path(k.upper()))

    # Calculate and save averaged congestion
    calculate_averaged_congestion(outputs["congl"], outputs["congu"]).to_pickle(
        pkl_path("AVERAGED_CONG")
    )

    if scenario_id:
        # Record infeasibilities
        insert_in_file(
            const.SCENARIO_LIST,
            scenario_id,
            "infeasibilities",
            "_".join(infeasibilities),
        )

        # Update execute and scenario list
        insert_in_file(const.EXECUTE_LIST, scenario_id, "status", "extracted")
        insert_in_file(const.SCENARIO_LIST, scenario_id, "state", "analyze")

    if not keep_mat:
        print("deleting matfiles")
        for matfile in mat_results:
            os.remove(matfile)


if __name__ == "__main__":
    args = parser.parse_extract_args()

    # Get scenario info if using PowerSimData
    if args.scenario_id:
        args.start_date, args.end_date, _, _, args.execute_dir = get_scenario(
            args.scenario_id
        )

        args.matlab_dir = const.INPUT_DIR
        args.output_dir = const.OUTPUT_DIR

    # Check to make sure all necessary arguments are there
    # (start_date, end_date, execute_dir)
    if not (args.start_date and args.end_date and args.execute_dir):
        err_str = (
            "The following arguments are required: start-date, end-date, execute-dir"
        )
        raise WrongNumberOfArguments(err_str)

    extract_scenario(
        args.execute_dir,
        args.start_date,
        args.end_date,
        args.scenario_id,
        args.output_dir,
        args.matlab_dir,
        args.frequency,
        args.keep_matlab,
    )
