from io import StringIO

import pandas as pd
import pytest

from pyreisejl.utility.helpers import (
    InvalidDateArgument,
    extract_date_limits,
    sec2hms,
    validate_time_format,
    validate_time_range,
)


def test_sec2hms_arg_type():
    seconds = 3.1
    with pytest.raises(TypeError):
        sec2hms(seconds)


def test_sec2hms_returned_value_type():
    seconds = 33
    assert isinstance(sec2hms(seconds), tuple)
    assert len(sec2hms(seconds)) == 3


def test_sec2hms_seconds_only():
    seconds = 33
    assert sec2hms(seconds) == (0, 0, seconds)


def test_sec2hms_minutes_only():
    seconds = 120
    assert sec2hms(seconds) == (0, 2, 0)


def test_sec2hms_hours_only():
    seconds = 7200
    assert sec2hms(seconds) == (2, 0, 0)


def test_sec2hms_hms():
    seconds = 72 * 3600 + 45 * 60 + 15
    assert sec2hms(seconds) == (72, 45, 15)


def test_validate_time_format_type():
    date = "2016/01/01"
    with pytest.raises(InvalidDateArgument):
        validate_time_format(date)


def test_validate_time_format_day():
    date = "2016-01-01"
    assert validate_time_format(date) == pd.Timestamp("2016-01-01 00:00:00")


def test_validate_time_format_hours():
    date = "2016-01-01 12"
    assert validate_time_format(date) == pd.Timestamp("2016-01-01 12:00:00")


def test_validate_time_format_min():
    date = "2016-01-01 12:30"
    assert validate_time_format(date) == pd.Timestamp("2016-01-01 12:30:00")


def test_validate_time_format_sec():
    date = "2016-01-01 12:30:30"
    assert validate_time_format(date) == pd.Timestamp("2016-01-01 12:30:30")


def test_validate_time_format_end_date():
    date = "2016-01-01"
    assert validate_time_format(date, end_date=True) == pd.Timestamp(
        "2016-01-01 23:00:00"
    )


def test_validate_time_range():
    date = "2020-06-01"
    min_ts = "2016-01-01"
    max_ts = "2016-12-31"
    with pytest.raises(InvalidDateArgument):
        validate_time_range(date, min_ts, max_ts)


def test_extract_date_limits():
    example_csv = StringIO()
    example_csv.write(
        """UTC, 301, 302, 303, 304, 305, 306, 307, 308
1/1/16 0:00, 2965.292134, 1184.906904, 1676.760454, 4556.579997, 18295.21119, 8611.226983, 14600.71, 1830.2
1/1/16 1:00, 3010.513011, 1215.345962, 1731.231093, 4684.33594, 18781.27034, 8959.356, 14655.5098, 1977.303
1/1/16 2:00, 3002.107911, 1192.115238, 1709.06971, 4536.162029, 18296.94916, 8744.25244, 14236.594, 1849.04
"""
    )
    example_csv.seek(0)

    assert extract_date_limits(example_csv) == (
        pd.Timestamp("2016-01-01 00:00:00"),
        pd.Timestamp("2016-01-01 02:00:00"),
        "H",
    )
