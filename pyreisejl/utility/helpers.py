import os
import re
import shutil
from collections import OrderedDict

import h5py
import numpy as np
import pandas as pd

from pyreisejl.utility import const


class WrongNumberOfArguments(TypeError):
    """To be used when the wrong number of arguments are specified at command line."""

    pass


class InvalidDateArgument(TypeError):
    """To be used when an invalid string is passed for the start or end date."""

    pass


class InvalidInterval(TypeError):
    """To be used when the interval does not evenly divide the date range given."""

    pass


def sec2hms(seconds):
    """Converts seconds to hours, minutes, seconds

    :param int seconds: number of seconds
    :return: (*tuple*) -- first element is number of hour(s), second is number
        of minutes(s) and third is number of second(s)
    :raises TypeError: if argument is not an integer.
    """
    if not isinstance(seconds, int):
        raise TypeError("seconds must be an integer")

    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)

    return hours, minutes, seconds


def load_mat73(filename):
    """Load a HDF5 matfile, and convert to a nested dict of numpy arrays.

    :param str filename: path to file which will be loaded.
    :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
    """

    def convert(path="/"):
        """A recursive walk through the HDF5 structure.

        :param str path: traverse from where in the HDF5 tree, default is '/'.
        :return: (*dict*) -- A possibly nested dictionary of numpy arrays.
        """
        output = {}
        references[path] = output = {}
        for k, v in f[path].items():
            if type(v).__name__ == "Group":
                output[k] = convert("{path}/{k}".format(path=path, k=k))
                continue
            # Retrieve numpy array from h5py_hl.dataset.Dataset
            data = v[()]
            if data.dtype == "object":
                # Extract values from HDF5 object references
                original_dims = data.shape
                data = np.array([f[r][()] for r in data.flat])
                # For any entry that is a uint16 array object, convert to str
                data = np.array(
                    [
                        "".join([str(c[0]) for c in np.char.mod("%c", array)])
                        if array.dtype == np.uint16
                        else array
                        for array in data
                    ]
                )
                # If data is all strs, set dtype to object to save a cell array
                if data.dtype.kind in {"U", "S"}:
                    data = np.array(data, dtype=np.object)
                # Un-flatten arrays which had been flattened
                if len(original_dims) > 1:
                    data = data.reshape(original_dims)
            if data.ndim >= 2:
                # Convert multi-dimensional arrays into numpy indexing
                data = data.swapaxes(-1, -2)
            else:
                # Convert single-dimension arrays to N x 1, avoid saving 1 x N
                data = np.expand_dims(data, axis=1)
            output[k] = data
        return output

    references = {}
    with h5py.File(filename, "r") as f:
        return convert()


def extract_date_limits(profile_csv):
    """Parses a profile csv to extract the first and last time stamp
    as well as the time

    :param  iterator: iterator containing the data of a profile.csv
    :return: (*tuple*) -- (min timestamp, max timestamp, timestamp frequency) as pandas.Timestamp
    """

    profile = pd.read_csv(profile_csv, index_col=0, parse_dates=True)
    min_ts = profile.index.min()
    max_ts = profile.index.max()
    freq = pd.infer_freq(profile.index)

    return (min_ts, max_ts, freq)


def validate_time_format(date, end_date=False):
    """Validates that the given dates are valid,
    and adds 23 hours if an end date is specified without hours.

    :param str date: date string as 'YYYY-MM-DD HH:MM:SS',
    where HH, MM, and SS are optional.
    :param bool end_date: whether or not this date is an end date
    :return: (*pandas.Timestamp*) -- the valid date as a pandas timestamp
    :raises InvalidDateArgument: if the date given is not one of the accepted formats
    """
    regex = r"^\d{4}-\d{1,2}-\d{1,2}( (?P<hour>\d{1,2})(:\d{1,2})?(:\d{1,2})?)?$"
    match = re.match(regex, date)

    if match:
        # if pandas won't convert the regex match, it's not a valid date
        # (i.e. invalid month or date)
        try:
            valid_date = pd.Timestamp(date)
        except ValueError:
            raise InvalidDateArgument(f"{date} is not a valid timestamp.")

        # if an end_date is given with no hours,
        # assume date range is until the end of the day (23h)
        if end_date and not match.group("hour"):
            valid_date += pd.Timedelta(hours=23)

    else:
        err_str = f"'{date}' is an invalid date. It needs to be in the form YYYY-MM-DD."
        raise InvalidDateArgument(err_str)

    return valid_date


def validate_time_range(date, min_ts, max_ts):
    """Validates that a date is within the given time range.

    :param pandas.Timestamp date: date to validate
    :param pandas.Timestamp date: start date of time range
    :param pandas.Timestamp date: end date of time range
    :raises InvalidDateArgument: if the date is not between
    the minimum and maximum timestamps
    """
    # make sure the dates are within the time frame we have data for
    if date < min_ts or date > max_ts:
        err_str = f"'{date}' is an invalid date. Valid dates are between {min_ts} and {max_ts}."
        raise InvalidDateArgument(err_str)


def get_scenario(scenario_id):
    """Returns scenario information.

    :param int/str scenario_id: scenario index.
    :return: (*tuple*) -- scenario start_date, end date, interval, input_dir, execute_dir
    """
    # Parses scenario info out of scenario list
    scenario_list = pd.read_csv(const.SCENARIO_LIST, dtype=str)
    scenario_list.fillna("", inplace=True)
    scenario = scenario_list[scenario_list.id == str(scenario_id)]
    scenario_info = scenario.to_dict("records", into=OrderedDict)[0]

    # Determine input and execute directory for data
    input_dir = os.path.join(const.EXECUTE_DIR, "scenario_%s" % scenario_info["id"])
    execute_dir = os.path.join(
        const.EXECUTE_DIR, f"scenario_{str(scenario_id)}", "output"
    )

    # Grab start and end date for scenario
    start_date = scenario_info["start_date"]
    end_date = scenario_info["end_date"]

    # Grab interval for scenario
    interval = int(scenario_info["interval"].split("H", 1)[0])

    return start_date, end_date, interval, input_dir, execute_dir


def insert_in_file(filename, scenario_id, column_name, column_value):
    """Updates status in execute list on server.

    :param str filename: path to execute or scenario list.
    :param int/str scenario_id: scenario index.
    :param str column_name: name of column to modify.
    :param str column_value: value to insert.
    """
    _ = shutil.copyfile(filename, filename + ".bak")

    table = pd.read_csv(filename, dtype=str)
    table.set_index("id", inplace=True)
    table.loc[str(scenario_id), column_name] = column_value
    table.to_csv(filename)


def get_scenario_status(scenario_id):
    try:
        table = pd.read_csv(const.EXECUTE_LIST, index_col="id")
        return table.loc[scenario_id, "status"]
    except KeyError:
        return None
