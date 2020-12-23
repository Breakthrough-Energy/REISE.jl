from pyreisejl.utility.state import ApplicationState, SimulationState


class FakeIOStream:
    def __init__(self):
        self.counter = 0

    def read(self):
        self.counter += 1
        return bytes(str(self.counter).encode())


class FakeProcess:
    def __init__(self):
        self.stdout = FakeIOStream()
        self.stderr = FakeIOStream()


def test_scenario_state_refresh():
    entry = SimulationState(1234, FakeProcess())
    entry.as_dict()
    assert entry.output == "1"
    assert entry.errors == "1"
    entry.as_dict()
    assert entry.output == "12"
    assert entry.errors == "12"


def test_scenario_state_serializable():
    entry = SimulationState(1234, FakeProcess())
    assert "proc" not in entry.as_dict().keys()


def test_app_state_get():
    state = ApplicationState()
    assert len(state.ongoing) == 0

    entry = SimulationState(1234, FakeProcess())
    state.add(entry)
    assert len(state.ongoing) == 1
    assert state.get(1234) is not None
