import os

from pyreisejl.utility import const, parser
from pyreisejl.utility.extract_data import extract_scenario
from pyreisejl.utility.helpers import (
    WrongNumberOfArguments,
    get_scenario,
    insert_in_file,
    sec2hms,
)
from pyreisejl.utility.launchers import GLPKLauncher, GurobiLauncher


def _record_scenario(scenario_id, runtime):
    """Updates execute and scenario list on server after simulation.

    :param str scenario_id: scenario index.
    :param int runtime: runtime of simulation in seconds.
    """

    # Update status in ExecuteList.csv on server
    insert_in_file(const.EXECUTE_LIST, scenario_id, "status", "finished")

    hours, minutes, seconds = sec2hms(runtime)
    insert_in_file(
        const.SCENARIO_LIST, scenario_id, "runtime", "%d:%02d" % (hours, minutes)
    )


def _get_launcher(solver):
    """Determine the launcher type given value from command line

    :param str solver: user provided solver name
    :return: (*type*) -- the launcher type, which can be instantiated
    """
    launch_map = {"gurobi": GurobiLauncher, "glpk": GLPKLauncher}
    if solver is None:
        return GurobiLauncher
    return launch_map[solver]


def main(args):
    # Get scenario info if using PowerSimData
    if args.scenario_id:
        scenario_args = get_scenario(args.scenario_id)

        args.start_date = scenario_args[0]
        args.end_date = scenario_args[1]
        args.interval = scenario_args[2]
        args.input_dir = scenario_args[3]
        args.execute_dir = scenario_args[4]

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

    launcher = _get_launcher(args.solver)(
        args.start_date,
        args.end_date,
        args.interval,
        args.input_dir,
    )
    runtime = launcher.launch_scenario(args.execute_dir, args.threads)

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
