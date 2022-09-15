import os
import pickle

from pyreisejl.utility import const, parser
from pyreisejl.utility.converters import create_case_mat
from pyreisejl.utility.extract_data import extract_scenario
from pyreisejl.utility.helpers import (
    WrongNumberOfArguments,
    get_scenario,
    insert_in_file,
    sec2hms,
)
from pyreisejl.utility.launchers import get_launcher


def _record_scenario(scenario_id, runtime):
    """Updates execute and scenario list on server after simulation.

    :param str scenario_id: scenario index.
    :param int runtime: runtime of simulation in seconds.
    """

    # Update status in ExecuteList.csv on server
    insert_in_file(const.EXECUTE_LIST, scenario_id, "status", "finished")

    hours, minutes, _ = sec2hms(runtime)
    insert_in_file(
        const.SCENARIO_LIST, scenario_id, "runtime", "%d:%02d" % (hours, minutes)
    )


cols = {
    "branch": ["branch_id", "from_bus_id", "to_bus_id", "x", "rateA"],
    "dcline": ["dcline_id", "from_bus_id", "to_bus_id", "Pmin", "Pmax"],
    "bus": ["bus_id", "Pd", "zone_id"],
    "plant": [
        "plant_id",
        "bus_id",
        "status",
        "Pmin",
        "Pmax",
        "type",
        "ramp_30",
        "GenFuelCost",
        "GenIOB",
        "GenIOC",
        "GenIOD",
    ],
}

drop_cols = {"gencost": ["interconnect"]}


def _save(path, name, df):
    df = df.reset_index()
    df = df.loc[:, cols.get(name, df.columns)]
    df = df.drop(drop_cols.get(name, []), axis=1)
    df.to_csv(os.path.join(path, f"{name}.csv"), index=False)


def pkl_to_csv(path):
    with open(os.path.join(path, "grid.pkl"), "rb") as f:
        grid = pickle.load(f)
    _save(path, "branch", grid.branch)
    _save(path, "dcline", grid.dcline)
    _save(path, "bus", grid.bus)
    _save(path, "plant", grid.plant)
    _save(path, "gencost", grid.gencost["before"])


def pkl_to_case_mat(path):
    with open(os.path.join(path, "grid.pkl"), "rb") as f:
        grid = pickle.load(f)

    _, _ = create_case_mat(
        grid,
        filepath=os.path.join(path, "case.mat"),
        storage_filepath=os.path.join(path, "case_storage.mat"),
    )


def main(args):
    # If using PowerSimData, get scenario info, prepare grid data and update status
    if args.scenario_id:
        # Get scenario info
        scenario_args = get_scenario(args.scenario_id)

        args.start_date = scenario_args[0]
        args.end_date = scenario_args[1]
        args.interval = scenario_args[2]
        args.input_dir = scenario_args[3]
        args.execute_dir = scenario_args[4]

        pkl_to_csv(args.input_dir)
        pkl_to_case_mat(args.input_dir)

        # Update status in ExecuteList.csv on server
        insert_in_file(const.EXECUTE_LIST, args.scenario_id, "status", "running")

    # Check to make sure all necessary arguments are there
    # (start_date, end_date, interval, input_dir)
    if not (args.start_date and args.end_date and args.interval and args.input_dir):
        err_str = (
            "The following arguments are required: "
            "start-date, end-date, interval, input-dir"
        )
        raise WrongNumberOfArguments(err_str)

    # launch simulation
    launcher = get_launcher(args.solver)(
        args.start_date,
        args.end_date,
        args.interval,
        args.input_dir,
        execute_dir=args.execute_dir,
        threads=args.threads,
        julia_env=args.julia_env,
        num_segments=args.linearization_segments,
    )
    runtime = launcher.launch_scenario()

    # If using PowerSimData, record the runtime
    if args.scenario_id:
        _record_scenario(args.scenario_id, runtime)
        args.matlab_dir = const.INPUT_DIR
        args.output_dir = const.OUTPUT_DIR

    if args.extract_data:
        if not args.execute_dir:
            args.execute_dir = os.path.join(args.input_dir, "output")

        extract_scenario(
            args.execute_dir,
            args.start_date,
            args.end_date,
            scenario_id=args.scenario_id,
            output_dir=args.output_dir,
            mat_dir=args.matlab_dir,
            keep_mat=args.keep_matlab,
        )


if __name__ == "__main__":
    args = parser.parse_call_args()
    try:
        main(args)
    except Exception as ex:
        print(ex)  # sent to redirected stdout/stderr
        if args.scenario_id:
            insert_in_file(const.EXECUTE_LIST, args.scenario_id, "status", "failed")
