from dataclasses import dataclass, field
from queue import Empty, Queue
from threading import Thread
from typing import Any, Dict, List

from pyreisejl.utility.helpers import get_scenario_status


class Listener:
    """Runs in the background to read from stdout/stderr of a long lived
    process"""

    def __init__(self, stream):
        self.stream = stream
        self.queue = Queue()
        self._start()

    def _start(self):
        t = Thread(target=self._enqueue_output)
        t.daemon = True
        t.start()

    def _enqueue_output(self):
        for line in self.stream:
            s = line.decode().strip()
            if len(s) > 0:
                self.queue.put(s)
        self.stream.close()

    def poll(self):
        """Get the latest output from the stream

        :return: (*list*) -- list of lines since previous poll
        """
        result = []
        try:
            while True:
                line = self.queue.get_nowait()
                result.append(line)
        except Empty:  # noqa
            pass
        return result


@dataclass
class SimulationState:
    """Track the state of an ongoing simulation"""

    _EXCLUDE = ["proc", "out_listener", "err_listener"]

    scenario_id: int
    proc: Any = field(default=None, repr=False, compare=False, hash=False)
    output: List = field(default_factory=list, repr=False, compare=False, hash=False)
    errors: List = field(default_factory=list, repr=False, compare=False, hash=False)
    status: str = None

    def __post_init__(self):
        self.out_listener = Listener(self.proc.stdout)
        self.err_listener = Listener(self.proc.stderr)

    def _refresh(self):
        """Set the latest status and append the latest output from standard
        streams.
        """
        self.status = get_scenario_status(self.scenario_id)
        self.output += self.out_listener.poll()
        self.errors += self.err_listener.poll()

    def as_dict(self):
        """Return custom dict which omits the process attribute which is not
        serializable.

        :return: (*dict*) -- dict of the instance attributes
        """
        self._refresh()
        return {k: v for k, v in self.__dict__.items() if k not in self._EXCLUDE}


@dataclass
class ApplicationState:
    """Tracks all simulations during the lifetime of the application"""

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
