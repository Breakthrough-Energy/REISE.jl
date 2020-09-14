from pyreisejl.utility import const
from pyreisejl.utility.helpers import sec2hms, WrongNumberOfArguments

import numpy as np
import os
import pandas as pd
import argparse

from collections import OrderedDict
from time import time


def _get_scenario(scenario_id):
    """Returns scenario information.

    :param str scenario_id: scenario index.
    :return: (*tuple*) -- scenario start_date, end date, interval, input_dir, output_dir
    """
    # Parses scenario info out of scenario list
    scenario_list = pd.read_csv(const.SCENARIO_LIST, dtype=str)
    scenario_list.fillna("", inplace=True)
    scenario = scenario_list[scenario_list.id == scenario_id]
    scenario_info = scenario.to_dict("records", into=OrderedDict)[0]

    # Determine input and output directory for data
    input_dir = os.path.join(const.EXECUTE_DIR, "scenario_%s" % scenario_info["id"])
    output_dir = os.path.join(
        const.EXECUTE_DIR, "scenario_%s/output" % scenario_info["id"]
    )

    # Create save data folder if does not exist
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)

    # Grab start and end date for scenario
    start_date = scenario_info["start_date"]
    end_date = scenario_info["end_date"]

    # Grab interval for scenario
    interval = int(scenario_info["interval"].split("H", 1)[0])

    return start_date, end_date, interval, input_dir, output_dir


def _record_scenario(scenario_id, runtime):
    """Updates execute and scenario list on server after simulation.

    :param str scenario_id: scenario index.
    :param int runtime: runtime of simulation in seconds.
    """

    # Update status in ExecuteList.csv on server
    _insert_in_file(const.EXECUTE_LIST, scenario_id, "2", "finished")

    hours, minutes, seconds = sec2hms(runtime)
    _insert_in_file(
        const.SCENARIO_LIST, scenario_id, "15", "%d:%02d" % (hours, minutes)
    )


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

    return


def launch_scenario(
    start_date, end_date, interval, input_dir, output_dir=None, threads=None
):
    """Launches the scenario.

    :param str start_date: start date of simulation as 'YYYY-MM-DD HH:MM:SS'
    :param str end_date: end date of simulation as 'YYYY-MM-DD HH:MM:SS'
    :param int interval: length of each interval in hours
    :param str input_dir: directory with input data
    :param None/str output_dir: directory for output data. None defaults to input directory
    :param None/int threads: number of threads to use, None defaults to auto.
    :return: (*int*) runtime of scenario in seconds
    """
    # we need n_interval, start_index
    min_ts = pd.Timestamp("2016-01-01 00:00:00")
    max_ts = pd.Timestamp("2016-12-31 23:00:00")
    dates = pd.date_range(start=min_ts, end=max_ts, freq="1H")

    start_ts = pd.Timestamp(start_date)
    end_ts = pd.Timestamp(end_date)

    # Julia starts at 1
    start_index = dates.get_loc(start_ts) + 1
    end_index = dates.get_loc(end_ts) + 1

    # Calculate number of intervals
    ts_range = end_index - start_index + 1
    n_interval = int(ts_range / interval)

    if ts_range % interval > 0:
        print("WARNING: The interval you chose does not evenly divide your date range.")

    # Import these within function because there is a lengthy compilation step
    from julia.api import Julia

    jl = Julia(compiled_modules=False)
    from julia import Main
    from julia import REISE

    start = time()
    REISE.run_scenario(
        interval=interval,
        n_interval=n_interval,
        start_index=start_index,
        inputfolder=input_dir,
        outputfolder=output_dir,
        threads=threads,
    )
    end = time()

    runtime = round(end - start)
    print("Run time: %ss" % str(runtime))

    return runtime


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run REISE.jl simulation.")

    # Arguments needed to run REISE.jl
    parser.add_argument(
        "-s",
        "--start-date",
        help="The start date for the simulation in format 'YYYY-MM-DD HH:MM:SS'",
    )
    parser.add_argument(
        "-e",
        "--end-date",
        help="The end date for the simulation in format 'YYYY-MM-DD HH:MM:SS'",
    )
    parser.add_argument(
        "-int", "--interval", help="The length of each interval in hours.", type=int
    )
    parser.add_argument(
        "-i",
        "--input-dir",
        help="The directory containing the input data files. "
        "Required files are 'case.mat', 'demand.csv', "
        "'hydro.csv', 'solar.csv', and 'wind.csv'.",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        help="The directory to store the results. This is optional and defaults "
        "to an output folder that will be created in the input directory "
        "if it does not exist.",
    )
    parser.add_argument(
        "-t",
        "--threads",
        help="The number of threads to run the simulation with. "
        "This is optional and defaults to Auto.",
    )

    # For backwards compatability with PowerSimData
    parser.add_argument(
        "scenario_id",
        nargs="?",
        default=None,
        help="Scenario ID only if using PowerSimData. ",
    )

    parser.add_argument(
        "powersim_threads",
        nargs="?",
        type=int,
        default=None,
        help="Number of threads only if using PowerSimData. ",
    )
    args = parser.parse_args()

    # Get scenario info if using PowerSimData
    if args.scenario_id:
        scenario_args = _get_scenario(args.scenario_id)

        args.start_date = scenario_args[0]
        args.end_date = scenario_args[1]
        args.interval = scenario_args[2]
        args.input_dir = scenario_args[3]
        args.output_dir = scenario_args[4]
        args.threads = args.powersim_threads

        # Update status in ExecuteList.csv on server
        _insert_in_file(const.EXECUTE_LIST, args.scenario_id, "2", "running")

    # Check to make sure all necessary arguments are there
    # (start_date, end_date, interval, input_dir)
    if not (args.start_date and args.end_date and args.interval and args.input_dir):
        err_str = (
            "The following arguments are required: "
            "start-date, end-date, interval, input-dir"
        )
        raise WrongNumberOfArguments(err_str)

    runtime = launch_scenario(
        args.start_date,
        args.end_date,
        args.interval,
        args.input_dir,
        args.output_dir,
        args.threads,
    )

    # If using PowerSimData, record the runtime
    if args.scenario_id:
        _record_scenario(args.scenario_id, runtime)
