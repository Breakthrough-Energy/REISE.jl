import importlib
import os
from time import time

import pandas as pd
from julia.api import LibJulia

from pyreisejl.utility.helpers import (
    InvalidDateArgument,
    InvalidInterval,
    extract_date_limits,
    sec2hms,
    validate_time_format,
    validate_time_range,
)


class Launcher:
    """Parent class for solver-specific scenario launchers.

    :param str start_date: start date of simulation as 'YYYY-MM-DD HH:MM:SS',
        where HH, MM, and SS are optional.
    :param str end_date: end date of simulation as 'YYYY-MM-DD HH:MM:SS',
        where HH, MM, and SS are optional.
    :param int interval: length of each interval in hours
    :param str input_dir: directory with input data
    :param int threads: number of threads to use. None defaults to letting the solver
        decide.
    :param dict solver_kwargs: keyword arguments to pass to solver (if any).
    :param str julia_env: path to the julia environment to be used to run simulation.
    :raises InvalidDateArgument: if start_date is posterior to end_date
    :raises InvalidInterval: if the interval doesn't evently divide the given date range
    """

    def __init__(
        self,
        start_date,
        end_date,
        interval,
        input_dir,
        threads=None,
        solver_kwargs=None,
        julia_env=None,
    ):
        """Constructor."""
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
        self.start_index = start_index
        self.interval = interval
        self.n_interval = int(ts_range / interval)
        self.input_dir = input_dir
        print("Validation complete!")
        # These parameters are not validated
        self.threads = threads
        self.solver_kwargs = solver_kwargs
        self.julia_env = julia_env
        self.execute_dir = os.path.join(self.input_dir, "output")

    def _print_settings(self):
        print("Launching scenario with parameters:")
        print(
            {
                "interval": self.interval,
                "n_interval": self.n_interval,
                "start_index": self.start_index,
                "input_dir": self.input_dir,
                "threads": self.threads,
                "julia_env": self.julia_env,
                "solver_kwargs": self.solver_kwargs,
            }
        )

    def init_julia(self, imports=["REISE"]):
        """Initialize a Julia session in the specified environment and import.

        :param list imports: julia packages to import.
        :return: (*tuple*) -- imported names.
        """
        api = LibJulia.load()
        julia_command_line_options = ["--compiled-modules=no"]
        if self.julia_env is not None:
            julia_command_line_options += [f"--project={self.julia_env}"]
        api.init_julia(julia_command_line_options)

        return tuple([importlib.import_module(f"julia.{i}") for i in imports])

    def parse_runtime(self, start, end):
        runtime = round(end - start)
        hours, minutes, seconds = sec2hms(runtime)
        print(f"Run time: {hours}:{minutes:02d}:{seconds:02d}")
        return runtime

    def launch_scenario(self):
        # This should be defined in sub-classes
        raise NotImplementedError


class ClpLauncher(Launcher):
    def launch_scenario(self):
        """Launches the scenario.

        :return: (*int*) runtime of scenario in seconds
        """
        self._print_settings()
        print("INFO: Clp functionality is still in the testing stage, no guarantees")
        print("INFO: threads not supported by Clp, ignoring")

        Clp, REISE = self.init_julia(imports=["Clp", "REISE"])

        start = time()
        REISE.run_scenario(
            interval=self.interval,
            n_interval=self.n_interval,
            start_index=self.start_index,
            inputfolder=self.input_dir,
            outputfolder=self.execute_dir,
            optimizer_factory=Clp.Optimizer,
            solver_kwargs=self.solver_kwargs,
        )
        end = time()

        return self.parse_runtime(start, end)


class GLPKLauncher(Launcher):
    def launch_scenario(self):
        """Launches the scenario.

        :return: (*int*) runtime of scenario in seconds
        """
        self._print_settings()
        print("INFO: threads not supported by GLPK, ignoring")

        GLPK, REISE = self.init_julia(imports=["GLPK", "REISE"])

        start = time()
        REISE.run_scenario(
            interval=self.interval,
            n_interval=self.n_interval,
            start_index=self.start_index,
            inputfolder=self.input_dir,
            outputfolder=self.execute_dir,
            optimizer_factory=GLPK.Optimizer,
            solver_kwargs=self.solver_kwargs,
        )
        end = time()

        return self.parse_runtime(start, end)


class GurobiLauncher(Launcher):
    def launch_scenario(self):
        """Launches the scenario.

        :return: (*int*) runtime of scenario in seconds
        """
        self._print_settings()

        # Gurobi needs to be imported in the Julia environment, but not used in Python.
        _, REISE = self.init_julia(imports=["Gurobi", "REISE"])

        start = time()
        REISE.run_scenario_gurobi(
            interval=self.interval,
            n_interval=self.n_interval,
            start_index=self.start_index,
            inputfolder=self.input_dir,
            outputfolder=self.execute_dir,
            threads=self.threads,
            solver_kwargs=self.solver_kwargs,
        )
        end = time()

        return self.parse_runtime(start, end)


_launch_map = {"clp": ClpLauncher, "glpk": GLPKLauncher, "gurobi": GurobiLauncher}


def get_available_solvers():
    return list(_launch_map.keys())


def get_launcher(solver):
    if solver is None:
        return GurobiLauncher
    if solver.lower() not in _launch_map.keys():
        raise ValueError("Invalid solver")
    return _launch_map[solver.lower()]
