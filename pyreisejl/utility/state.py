from dataclasses import dataclass, field
from queue import Empty, Queue
from threading import Thread
from typing import Any, Dict, List

from pyreisejl.utility.helpers import get_scenario_status


def _enqueue_output(stream, queue):
    for line in iter(stream.readline, b""):
        queue.put(line)
    stream.close()


def _start_thread(stream, queue):
    t = Thread(target=_enqueue_output, args=(stream, queue))
    t.daemon = True
    t.start()


def _read_stream(q):
    result = []
    try:
        while True:
            line = q.get_nowait()
            result.append(line.decode().strip())
    except Empty:  # noqa
        pass
    return result


@dataclass
class SimulationState:
    _EXCLUDE = ["proc", "q_out", "q_err"]

    scenario_id: int
    proc: Any = field(default=None, repr=False, compare=False, hash=False)
    output: List = field(default_factory=list, repr=False, compare=False, hash=False)
    errors: List = field(default_factory=list, repr=False, compare=False, hash=False)
    status: str = None

    def __post_init__(self):
        self.q_out = Queue()
        self.q_err = Queue()
        _start_thread(self.proc.stdout, self.q_out)
        _start_thread(self.proc.stderr, self.q_err)

    def _refresh(self):
        """Set the latest status and append the latest output from standard
        streams.
        """
        self.status = get_scenario_status(self.scenario_id)
        self.output += _read_stream(self.q_out)
        self.errors += _read_stream(self.q_err)

    def as_dict(self):
        """Return custom dict which omits the process attribute which is not
        serializable.

        :return: (*dict*) -- dict of the instance attributes
        """
        self._refresh()
        return {k: v for k, v in self.__dict__.items() if k not in self._EXCLUDE}


@dataclass
class ApplicationState:
    ongoing: Dict[int, SimulationState] = field(default_factory=dict)

    def add(self, entry):
        """Add entry for scenario to current state

        :param SimulationState entry: object to track a given scenario
        """
        self.ongoing[int(entry.scenario_id)] = entry

    def get(self, scenario_id):
        """Get the latest information for a scenario if it is present

        :param int scenario_id: id of the scenario
        :return: (*dict*) -- a dict containing values from the ScenarioState
        """
        if scenario_id not in self.ongoing:
            return None
        return self.ongoing[scenario_id].as_dict()

    def as_dict(self):
        """Custom dict implementation which utilizes the similar method from
        SimulationState

        :return: (*dict*) -- dict of the instance attributes
        """
        return {k: v.as_dict() for k, v in self.ongoing.items()}
