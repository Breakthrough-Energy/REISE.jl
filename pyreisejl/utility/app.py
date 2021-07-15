import os
import sys
from pathlib import Path
from subprocess import PIPE, Popen

from flask import Flask, jsonify, request

from pyreisejl.utility.state import ApplicationState, SimulationState

app = Flask(__name__)


"""
Example requests:

Launch using gurobi, 4 threads, auto extract
curl -XPOST http://localhost:5000/launch/123?threads=4

Launch using GLPK, extract manually
curl -XPOST http://localhost:5000/launch/123?solver=glpk&extract-data=0
curl -XPOST http://localhost:5000/extract/123

Check status of scenario 123
curl http://localhost:5000/status/123
"""


state = ApplicationState()


def get_script_path(filename):
    script_dir = Path(__file__).parent.absolute()
    path_to_script = Path(script_dir, filename)
    return str(path_to_script)


def call_cmd(scenario_id, threads=None, solver=None, extract=True):
    cmd = [
        sys.executable,
        "-u",
        get_script_path("call.py"),
        str(scenario_id),
    ]
    if extract:
        cmd.extend(["--extract-data"])
    if threads is not None:
        cmd.extend(["--threads", str(threads)])
    if solver is not None:
        cmd.extend(["--solver", solver])
    return cmd


def extract_cmd(scenario_id):
    cmd = [
        sys.executable,
        "-u",
        get_script_path("extract_data.py"),
        str(scenario_id),
    ]
    return cmd


def run_script(cmd, scenario_id):
    new_env = os.environ.copy()
    new_env["PYTHONPATH"] = str(Path(__file__).parent.parent.parent.absolute())
    proc = Popen(cmd, stdout=PIPE, stderr=PIPE, start_new_session=True, env=new_env)
    entry = SimulationState(scenario_id, proc)
    state.add(entry)
    return entry.as_dict()


def launch_simulation(scenario_id, threads=None, solver=None, extract=True):
    cmd = call_cmd(scenario_id, threads, solver, extract)
    return run_script(cmd, scenario_id)


def extract_scenario(scenario_id):
    cmd = extract_cmd(scenario_id)
    return run_script(cmd, scenario_id)


def check_progress():
    return state.as_dict()


@app.route("/launch/<int:scenario_id>", methods=["POST"])
def handle_launch(scenario_id):
    threads = request.args.get("threads", None)
    solver = request.args.get("solver", None)
    extract_arg = request.args.get("extract-data", None)
    extract = extract_arg is not None and extract_arg not in ("0", "False")
    entry = launch_simulation(scenario_id, threads, solver, extract)
    return jsonify(entry)


@app.route("/extract/<int:scenario_id>", methods=["POST"])
def handle_extract(scenario_id):
    entry = extract_scenario(scenario_id)
    return jsonify(entry)


@app.route("/list")
def list_ongoing():
    return jsonify(check_progress())


@app.route("/status/<int:scenario_id>")
def get_status(scenario_id):
    entry = state.get(scenario_id)
    return jsonify(entry), 200 if entry is not None else 404


if __name__ == "__main__":
    app.run(port=5000, debug=True)
