import os
from time import time

import pandas as pd

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
    :raises InvalidDateArgument: if start_date is posterior to end_date
    :raises InvalidInterval: if the interval doesn't evently divide the given date range
    """

    def __init__(self, start_date, end_date, interval, input_dir):
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

    def _print_settings(self):
        print("Launching scenario with parameters:")
        print(
            {
                "interval": self.interval,
                "n_interval": self.n_interval,
                "start_index": self.start_index,
                "input_dir": self.input_dir,
                "execute_dir": self.execute_dir,
                "threads": self.threads,
            }
        )

    def launch_scenario(self):
        # This should be defined in sub-classes
        raise NotImplementedError


class GLPKLauncher(Launcher):
    def launch_scenario(self, execute_dir=None, threads=None, solver_kwargs=None):
        """Launches the scenario.

        :param None/str execute_dir: directory for execute data. None defaults to an
            execute folder that will be created in the input directory
        :param None/int threads: number of threads to use.
        :param None/dict solver_kwargs: keyword arguments to pass to solver (if any).
        :return: (*int*) runtime of scenario in seconds
        """
        self.execute_dir = execute_dir
        self.threads = threads
        self._print_settings()

        from julia.api import Julia

        Julia(compiled_modules=False)
        from julia import GLPK  # noqa: F401
        from julia import REISE

        start = time()
        REISE.run_scenario(
            interval=self.interval,
            n_interval=self.n_interval,
            start_index=self.start_index,
            inputfolder=self.input_dir,
            outputfolder=self.execute_dir,
            threads=self.threads,
            optimizer_factory=GLPK.Optimizer,
        )
        end = time()

        runtime = round(end - start)
        hours, minutes, seconds = sec2hms(runtime)
        print(f"Run time: {hours}:{minutes:02d}:{seconds:02d}")

        return runtime


class GurobiLauncher(Launcher):
    def launch_scenario(self, execute_dir=None, threads=None, solver_kwargs=None):
        """Launches the scenario.

        :param None/str execute_dir: directory for execute data. None defaults to an
            execute folder that will be created in the input directory
        :param None/int threads: number of threads to use.
        :param None/dict solver_kwargs: keyword arguments to pass to solver (if any).
        :return: (*int*) runtime of scenario in seconds
        """
        self.execute_dir = execute_dir
        self.threads = threads
        self._print_settings()
        # Import these within function because there is a lengthy compilation step
        from julia.api import Julia

        Julia(compiled_modules=False)
        from julia import Gurobi  # noqa: F401
        from julia import REISE

        start = time()
        REISE.run_scenario_gurobi(
            interval=self.interval,
            n_interval=self.n_interval,
            start_index=self.start_index,
            inputfolder=self.input_dir,
            outputfolder=self.execute_dir,
            threads=self.threads,
        )
        end = time()

        runtime = round(end - start)
        hours, minutes, seconds = sec2hms(runtime)
        print(f"Run time: {hours}:{minutes:02d}:{seconds:02d}")

        return runtime
