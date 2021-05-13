import os
from pathlib import Path

if os.getenv("DEPLOYMENT_MODE") is not None:
    DATA_ROOT_DIR = os.path.join(Path.home(), "ScenarioData", "")
else:
    DATA_ROOT_DIR = "/mnt/bes/pcm"

SCENARIO_LIST = os.path.join(DATA_ROOT_DIR, "ScenarioList.csv")
EXECUTE_LIST = os.path.join(DATA_ROOT_DIR, "ExecuteList.csv")
EXECUTE_DIR = os.path.join(DATA_ROOT_DIR, "tmp")
INPUT_DIR = os.path.join(DATA_ROOT_DIR, "data", "input")
OUTPUT_DIR = os.path.join(DATA_ROOT_DIR, "data", "output")
