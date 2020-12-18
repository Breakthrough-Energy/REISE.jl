from pathlib import Path
from subprocess import PIPE, Popen

from flask import Flask, jsonify

from pyreisejl.utility.state import ApplicationState, ScenarioState

app = Flask(__name__)


"""
Example request:

curl -XPOST http://localhost:5000/launch/1234
curl http://localhost:5000/status/1234
"""


state = ApplicationState()


def get_script_path():
    script_dir = Path(__file__).parent.absolute()
    path_to_script = Path(script_dir, "call.py")
    return str(path_to_script)


@app.route("/launch/<int:scenario_id>", methods=["POST"])
def launch_simulation(scenario_id):
    if state.is_running(scenario_id):
        return jsonify("Scenario is already in progress")

    cmd_call = ["python3", "-u", get_script_path(), str(scenario_id)]
    proc = Popen(cmd_call, stdout=PIPE, stderr=PIPE)

    info = ScenarioState(scenario_id, proc)
    state.add(scenario_id, info)
    return jsonify(info.as_dict())


@app.route("/list")
def list_ongoing():
    return jsonify(state.as_dict())


@app.route("/status/<int:scenario_id>")
def get_status(scenario_id):
    return jsonify(state.get(scenario_id))


if __name__ == "__main__":
    app.run(port=5000, debug=True)
