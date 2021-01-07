from pathlib import Path
from subprocess import PIPE, Popen

from flask import Flask, jsonify, request

from pyreisejl.utility.state import ApplicationState, SimulationState

app = Flask(__name__)


"""
Example request:

curl -XPOST http://localhost:5000/launch/1234
curl -XPOST http://localhost:5000/launch/1234?threads=42
curl http://localhost:5000/status/1234
"""


state = ApplicationState()


def get_script_path():
    script_dir = Path(__file__).parent.absolute()
    path_to_script = Path(script_dir, "call.py")
    return str(path_to_script)


@app.route("/launch/<int:scenario_id>", methods=["POST"])
def launch_simulation(scenario_id):
    cmd_call = ["python3", "-u", get_script_path(), str(scenario_id)]
    threads = request.args.get("threads", None)

    if threads is not None:
        cmd_call.extend(["--threads", str(threads)])

    proc = Popen(cmd_call, stdout=PIPE, stderr=PIPE, start_new_session=True)
    entry = SimulationState(scenario_id, proc)
    state.add(entry)
    return jsonify(entry.as_dict())


@app.route("/list")
def list_ongoing():
    return jsonify(state.as_dict())


@app.route("/status/<int:scenario_id>")
def get_status(scenario_id):
    entry = state.get(scenario_id)
    return jsonify(entry), 200 if entry is not None else 404


if __name__ == "__main__":
    app.run(port=5000, debug=True)
