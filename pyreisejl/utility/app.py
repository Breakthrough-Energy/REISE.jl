from pathlib import Path
from subprocess import PIPE, Popen

from flask import Flask, jsonify, request

from pyreisejl.utility.state import ApplicationState, SimulationState

app = Flask(__name__)


"""
Example request:

curl -XPOST http://localhost:5000/launch/1234
curl -XPOST http://localhost:5000/launch/1234?threads=4&solver=glpk
curl http://localhost:5000/status/1234
"""


state = ApplicationState()


def get_script_path():
    script_dir = Path(__file__).parent.absolute()
    path_to_script = Path(script_dir, "call.py")
    return str(path_to_script)


def launch_simulation(scenario_id, threads=None, solver=None):
    cmd_call = ["python3", "-u", get_script_path(), str(scenario_id), "--extract-data"]

    if threads is not None:
        cmd_call.extend(["--threads", str(threads)])

    if solver is not None:
        cmd_call.extend(["--solver", solver])

    proc = Popen(cmd_call, stdout=PIPE, stderr=PIPE, start_new_session=True)
    entry = SimulationState(scenario_id, proc)
    state.add(entry)
    return entry.as_dict()


def check_progress():
    return state.as_dict()


@app.route("/launch/<int:scenario_id>", methods=["POST"])
def handle_launch(scenario_id):
    threads = request.args.get("threads", None)
    solver = request.args.get("solver", None)
    entry = launch_simulation(scenario_id, threads, solver)
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
