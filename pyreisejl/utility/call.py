import argparse
import os
from time import time

import pandas as pd

from pyreisejl.utility import const
from pyreisejl.utility.extract_data import extract_scenario
from pyreisejl.utility.helpers import (
    InvalidDateArgument,
    InvalidInterval,
    WrongNumberOfArguments,
    extract_date_limits,
    get_scenario,
    insert_in_file,
    sec2hms,
    validate_time_format,
    validate_time_range,
)


def _record_scenario(scenario_id, runtime):
    """Updates execute and scenario list on server after simulation.

    :param str scenario_id: scenario index.
    :param int runtime: runtime of simulation in seconds.
    """

    # Update status in ExecuteList.csv on server
    insert_in_file(const.EXECUTE_LIST, scenario_id, "2", "finished")

    hours, minutes, seconds = sec2hms(runtime)
    insert_in_file(const.SCENARIO_LIST, scenario_id, "15", "%d:%02d" % (hours, minutes))


def launch_scenario(
    start_date, end_date, interval, input_dir, execute_dir=None, threads=None
):
    """Launches the scenario.

    :param str start_date: start date of simulation as 'YYYY-MM-DD HH:MM:SS',
    where HH, MM, and SS are optional.
    :param str end_date: end date of simulation as 'YYYY-MM-DD HH:MM:SS',
    where HH, MM, and SS are optional.
    :param int interval: length of each interval in hours
    :param str input_dir: directory with input data
    :param None/str execute_dir: directory for execute data. None defaults to an
    execute folder that will be created in the input directory
    :param None/int threads: number of threads to use, None defaults to auto.
    :return: (*int*) runtime of scenario in seconds
    :raises InvalidDateArgument: if start_date is posterior to end_date
    :raises InvalidInterval: if the interval does not evently divide the given date range
    """
    # extract time limits from 'demand.csv'
    with open(os.path.join(input_dir, "demand.csv")) as profile:
        min_ts, max_ts, freq = extract_date_limits(profile)

    dates = pd.date_range(start=min_ts, end=max_ts, freq=freq)

    start_ts = validate_time_format(start_date)
    end_ts = validate_time_format(end_date, end_date=True)

    # make sure the dates are within the time frame we have data for
    validate_time_range(start_ts, min_ts, max_ts)
    validate_time_range(end_ts, min_ts, max_ts)

    if start_ts > end_ts:
        raise InvalidDateArgument(
            f"The start date ({start_ts}) cannot be after the end date ({end_ts})."
        )

    # Julia starts at 1
    start_index = dates.get_loc(start_ts) + 1
    end_index = dates.get_loc(end_ts) + 1

    # Calculate number of intervals
    ts_range = end_index - start_index + 1
    if ts_range % interval > 0:
        raise InvalidInterval(
            "This interval does not evenly divide the given date range."
        )

    n_interval = int(ts_range / interval)

    # Import these within function because there is a lengthy compilation step
    from julia.api import Julia

    Julia(compiled_modules=False)
    from julia import REISE

    start = time()
    REISE.run_scenario(
        interval=interval,
        n_interval=n_interval,
        start_index=start_index,
        inputfolder=input_dir,
        outputfolder=execute_dir,
        threads=threads,
    )
    end = time()

    runtime = round(end - start)
    hours, minutes, seconds = sec2hms(runtime)
    print(f"Run time: {hours}:{minutes:02d}:{seconds:02d}")

    return runtime


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run REISE.jl simulation.")

    # Arguments needed to run REISE.jl
    parser.add_argument(
        "-s",
        "--start-date",
        help="The start date for the simulation in format 'YYYY-MM-DD'. 'YYYY-MM-DD HH'. "
        "'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'.",
    )
    parser.add_argument(
        "-e",
        "--end-date",
        help="The end date for the simulation in format 'YYYY-MM-DD'. 'YYYY-MM-DD HH'. "
        "'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'. If only the date is specified "
        "(without any hours), the entire end-date will be included in the simulation.",
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
        "-x",
        "--execute-dir",
        help="The directory to store the results. This is optional and defaults "
        "to an execute folder that will be created in the input directory "
        "if it does not exist.",
    )
    parser.add_argument(
        "-t",
        "--threads",
        type=int,
        help="The number of threads to run the simulation with. "
        "This is optional and defaults to Auto.",
    )
    parser.add_argument(
        "-d",
        "--extract-data",
        action="store_true",
        help="If this flag is used, the data generated by the simulation after the engine "
        "has finished running will be automatically extracted into .pkl files, "
        "and the result.mat files will be deleted. "
        "The extraction process can be memory intensive. "
        "This is optional and defaults to False.",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        help="The directory to store the extracted data. This is optional and defaults "
        "to the execute directory. This flag is only used if the extract-data flag is set.",
    )
    parser.add_argument(
        "-m",
        "--matlab-dir",
        help="The directory to store the modified case.mat used by the engine. "
        "This is optional and defaults to the execute directory. "
        "This flag is only used if the extract-data flag is set.",
    )
    parser.add_argument(
        "-k",
        "--keep-matlab",
        action="store_true",
        help="The result.mat files found in the execute directory will be kept "
        "instead of deleted after extraction. "
        "This flag is only used if the extract-data flag is set.",
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
        scenario_args = get_scenario(args.scenario_id)

        args.start_date = scenario_args[0]
        args.end_date = scenario_args[1]
        args.interval = scenario_args[2]
        args.input_dir = scenario_args[3]
        args.execute_dir = scenario_args[4]
        if not args.threads:
            args.threads = args.powersim_threads

        # Update status in ExecuteList.csv on server
        insert_in_file(const.EXECUTE_LIST, args.scenario_id, "2", "running")

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
        args.execute_dir,
        args.threads,
    )

    # If using PowerSimData, record the runtime
    if args.scenario_id:
        _record_scenario(args.scenario_id, runtime)
        args.matlab_dir = const.INPUT_DIR
        args.output_dir = const.OUTPUT_DIR

    if args.extract_data:

        extract_scenario(
            args.execute_dir,
            args.start_date,
            args.end_date,
            scenario_id=args.scenario_id,
            output_dir=args.output_dir,
            mat_dir=args.matlab_dir,
            keep_mat=args.keep_matlab,
        )
