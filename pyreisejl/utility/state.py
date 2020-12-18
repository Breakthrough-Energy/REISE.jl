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

    def refresh(self):
        self.status = get_scenario_status(self.scenario_id)
        self.output += self.proc.stdout.read().decode()
        self.errors += self.proc.stderr.read().decode()

    def as_dict(self):
        self.refresh()
        return {k: v for k, v in self.__dict__.items() if k != "proc"}


@dataclass
class ApplicationState:
    ongoing: Dict[int, ScenarioState] = field(default_factory=dict)

    def add(self, scenario_id, state):
        self.ongoing[int(scenario_id)] = state

    def get(self, scenario_id):
        if scenario_id not in self.ongoing:
            return None
        return self.ongoing[scenario_id].as_dict()

    def is_running(self, scenario_id):
        entry = self.get(scenario_id)
        if entry is not None:
            return entry["status"] == "running"
        return False

    def as_dict(self):
        return {k: v.as_dict() for k, v in self.ongoing.items()}
