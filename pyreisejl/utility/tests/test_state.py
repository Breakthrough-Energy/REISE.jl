import pytest

from pyreisejl.utility.state import ApplicationState, SimulationState


class FakeIOStream:
    def __init__(self):
        self.counter = 0
        self.limit = 5

    def __iter__(self):
        return self

    def __next__(self):
        if self.counter > self.limit:
            return b""
        self.counter += 1
        return bytes(str(self.counter).encode())

    def readline(self):
        pass


class FakeProcess:
    def __init__(self):
        self.stdout = FakeIOStream()
        self.stderr = FakeIOStream()


@pytest.mark.skip
def test_scenario_state_refresh():
    entry = SimulationState(1234, FakeProcess())
    entry.as_dict()
    assert entry.output == "1"
    assert entry.errors == "1"
    entry.as_dict()
    assert entry.output == "12"
    assert entry.errors == "12"


@pytest.mark.skip
def test_scenario_state_serializable():
    entry = SimulationState(1234, FakeProcess())
    assert "proc" not in entry.as_dict().keys()


@pytest.mark.skip
def test_app_state_get():
    state = ApplicationState()
    assert len(state.ongoing) == 0

    entry = SimulationState(1234, FakeProcess())
    state.add(entry)
    assert len(state.ongoing) == 1
    assert state.get(1234) is not None
