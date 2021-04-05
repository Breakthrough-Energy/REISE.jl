import time
from subprocess import PIPE, Popen

import pytest

from pyreisejl.utility.state import ApplicationState, SimulationState


@pytest.fixture
def test_proc():
    cmd = ["echo", "foo"]
    proc = Popen(cmd, stdout=PIPE, stderr=PIPE, start_new_session=True)
    return proc


def test_scenario_state_refresh(test_proc):
    entry = SimulationState(123, test_proc)
    time.sleep(0.4)  # mitigate race condition
    entry.as_dict()
    assert entry.output == ["foo"]
    assert entry.errors == []


def test_scenario_state_serializable(test_proc):
    entry = SimulationState(123, test_proc)
    keys = entry.as_dict().keys()
    assert "proc" not in keys
    assert all(["listener" not in k for k in keys])


def test_app_state_get(test_proc):
    state = ApplicationState()
    assert len(state.ongoing) == 0

    entry = SimulationState(123, test_proc)
    state.add(entry)
    assert len(state.ongoing) == 1
    assert state.get(123) is not None
