import posixpath

DATA_ROOT_DIR = "/mnt/bes/pcm"

SCENARIO_LIST = posixpath.join(DATA_ROOT_DIR, "ScenarioList.csv")
EXECUTE_LIST = posixpath.join(DATA_ROOT_DIR, "ExecuteList.csv")
# SCENARIO_LIST = os.path.join("~/ScenarioData", "ScenarioList.csv")
# EXECUTE_LIST = os.path.join("~/ScenarioData", "ExecuteList.csv")
EXECUTE_DIR = posixpath.join(DATA_ROOT_DIR, "tmp")
INPUT_DIR = posixpath.join(DATA_ROOT_DIR, "data", "input")
OUTPUT_DIR = posixpath.join(DATA_ROOT_DIR, "data", "output")
