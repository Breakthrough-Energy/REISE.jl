from dataclasses import dataclass, field
from typing import Any, Dict

from pyreisejl.utility.helpers import get_scenario_status


@dataclass
class ScenarioState:
    scenario_id: int
    proc: Any = field(default=None, repr=False, compare=False, hash=False)
    output: str = field(default="", repr=False, compare=False, hash=False)
    errors: str = field(default="", repr=False, compare=False, hash=False)
    status: str = None

    def _refresh(self):
        """Set the latest status and append the latest output from standard
        streams.
        """
        self.status = get_scenario_status(self.scenario_id)
        self.output += self.proc.stdout.read().decode()
        self.errors += self.proc.stderr.read().decode()

    def as_dict(self):
        """Return custom dict which omits the process attribute which is not
        serializable.

        :return: (*dict*) -- dict of the instance attributes
        """
        self._refresh()
        return {k: v for k, v in self.__dict__.items() if k != "proc"}


@dataclass
class ApplicationState:
    ongoing: Dict[int, ScenarioState] = field(default_factory=dict)

    def add(self, entry):
        """Add entry for scenario to current state

        :param ScenarioState entry: object to track a given scenario
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
        ScenarioState

        :return: (*dict*) -- dict of the instance attributes
        """
        return {k: v.as_dict() for k, v in self.ongoing.items()}
