from pathlib import Path
from subprocess import Popen

from flask import Flask, jsonify

from pyreisejl.utility.helpers import get_scenario_status

app = Flask(__name__)


"""
Example request:

curl -XPOST http://localhost:5000/launch/1234
curl http://localhost:5000/status/1234
"""


# scenario_id -> pid
ongoing = {}


def get_script_path():
    script_dir = Path(__file__).parent.absolute()
    path_to_script = Path(script_dir, "call.py")
    return str(path_to_script)


# TODO pipe stdout to in memory object
@app.route("/launch/<scenario_id>", methods=["POST"])
def launch_simulation(scenario_id):
    cmd_call = ["python3", "-u", get_script_path(), scenario_id]
    pid = Popen(cmd_call).pid
    ongoing[scenario_id] = pid
    return jsonify({"pid": pid})


# TODO remove pid when process complete
@app.route("/list")
def list_ongoing():
    return jsonify(ongoing)


# TODO append details from redirected io
@app.route("/status/<int:scenario_id>")
def get_status(scenario_id):
    status = get_scenario_status(scenario_id)
    return jsonify(status)


if __name__ == "__main__":
    app.run(port=5000, debug=True)
