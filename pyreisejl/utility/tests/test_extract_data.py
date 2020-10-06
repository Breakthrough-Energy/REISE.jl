import numpy as np
import pandas as pd
import pytest

from ..extract_data import (
    calculate_averaged_congestion,
    _get_pkl_path,
    _cast_keys_as_lists,
    _update_outputs_labels,
    result_num,
)


def test_calculate_averaged_congestion_first_arg_type():
    congl = 1
    congu = None
    with pytest.raises(TypeError):
        calculate_averaged_congestion(congl, congu)


def test_calculate_averaged_congestion_second_arg_type():
    congl = pd.DataFrame()
    congu = 1
    with pytest.raises(TypeError):
        calculate_averaged_congestion(congl, congu)


def test_calculate_averaged_congestion_args_shape():
    congl = pd.DataFrame({"A": [1, 2, 3], "B": [10, 11, 12]})
    congu = pd.DataFrame({"A": [21, 22, 23, 24], "B": [30, 31, 32, 33]})
    with pytest.raises(ValueError):
        calculate_averaged_congestion(congl, congu)


def test_calculate_averaged_congestion_args_indices():
    congl = pd.DataFrame({"A": [1, 2, 3, 4], "B": [10, 11, 12, 13]})
    congu = pd.DataFrame({"C": [21, 22, 23, 24], "D": [30, 31, 32, 33]})
    with pytest.raises(ValueError):
        calculate_averaged_congestion(congl, congu)


def test_calculate_averaged_congestion_returned_df_shape():
    congl = pd.DataFrame({"A": [1, 2, 3, 4], "B": [10, 11, 12, 13]})
    congu = pd.DataFrame({"A": [21, 22, 23, 24], "B": [30, 31, 32, 33]})
    assert calculate_averaged_congestion(congl, congu).shape == (2, 2)


def test_calculate_averaged_congestion_returned_df_columns_name():
    congl = pd.DataFrame({"a": [1, 2, 3, 4], "b": [10, 11, 12, 13]})
    congu = pd.DataFrame({"a": [21, 22, 23, 24], "b": [30, 31, 32, 33]})
    mean_cong = calculate_averaged_congestion(congl, congu)
    assert np.array_equal(mean_cong.columns, ["CONGL", "CONGU"])


def test_calculate_averaged_congestion_returned_df_indices():
    congl = pd.DataFrame({"marge": [1, 2, 3, 4], "homer": [10, 11, 12, 13]})
    congu = pd.DataFrame({"marge": [21, 22, 23, 24], "homer": [30, 31, 32, 33]})
    mean_cong = calculate_averaged_congestion(congl, congu)
    assert np.array_equal(set(mean_cong.index), set(["marge", "homer"]))


def test_calculate_averaged_congestion_returned_df_values():
    congl = pd.DataFrame({"bart": [1, 2, 3, 4], "lisa": [10, 11, 12, 13]})
    congu = pd.DataFrame({"bart": [21, 22, 23, 24], "lisa": [30, 31, 32, 33]})
    mean_cong = calculate_averaged_congestion(congl, congu)
    assert np.array_equal(mean_cong.values, [[2.5, 22.5], [11.5, 31.5]])


def test_get_pkl_path():
    test_path = "/path/to/test/directory"
    without_scenario = _get_pkl_path(test_path)
    assert without_scenario("congu") == "/path/to/test/directory/CONGU.pkl"


def test_get_pkl_path_with_scenario():
    test_path = "/path/to/test/directory"
    with_scenario = _get_pkl_path(test_path, "87")
    assert with_scenario("congu") == "/path/to/test/directory/87_CONGU.pkl"


def test_cast_keys_as_lists():
    outputs = {"marge": 2, "homer": np.array([1, 2, 3, 4])}
    expected_output = {"marge": [2], "homer": [1, 2, 3, 4]}
    _cast_keys_as_lists(outputs)
    assert outputs == expected_output


def test_result_num():
    result365 = "/path/to/test/result_365.mat"
    assert result_num(result365) == 365
