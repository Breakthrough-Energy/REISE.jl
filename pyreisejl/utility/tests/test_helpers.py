import pytest

from pyreisejl.utility.helpers import sec2hms


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
