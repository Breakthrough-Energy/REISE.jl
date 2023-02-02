import json
import os
import pickle

cols = {
    "branch": "branch_id from_bus_id to_bus_id x rateA".split(),
    "dcline": "dcline_id from_bus_id to_bus_id Pmin Pmax".split(),
    "bus": "bus_id Pd zone_id".split(),
    "plant": "plant_id bus_id status Pmin Pmax type ramp_30 GenFuelCost GenIOB GenIOC GenIOD".split(),
    "storage_gen": "bus_id Pmin Pmax".split(),
}

drop_cols = {"gencost_before": "plant_id interconnect".split()}
drop_cols["gencost_after"] = drop_cols["gencost_before"]


def _save(path, name, df):
    df = df.reset_index()
    df = df.loc[:, cols.get(name, df.columns)]
    df = df.drop(drop_cols.get(name, []), axis=1)
    df.to_csv(os.path.join(path, f"{name}.csv"), index=False)


def _pkl_to_csv(path, grid):
    _save(path, "branch", grid.branch)
    _save(path, "dcline", grid.dcline)
    _save(path, "bus", grid.bus)
    _save(path, "plant", grid.plant)
    _save(path, "gencost_before", grid.gencost["before"])
    _save(path, "gencost_after", grid.gencost["after"])

    storage = grid.storage
    if not storage["gen"].empty:
        _save(path, "StorageData", storage["StorageData"])
        _save(path, "storage_gen", storage["gen"])


def _pkl_to_json(path, grid):
    # Convert sets to lists so a .json file can be created
    class SetEncoder(json.JSONEncoder):
        def default(self, obj):
            if isinstance(obj, set):
                return list(obj)
            return json.JSONEncoder.default(self, obj)

    # Save grid.model_immutables.plants as a .json file
    with open(os.path.join(path, "plant_immutables.json"), "w", encoding="utf-8") as f:
        json.dump(
            grid.model_immutables.plants,
            f,
            ensure_ascii=False,
            indent=4,
            cls=SetEncoder,
        )


def pkl_to_input_files(path):
    # Access the grid object from the .pkl file
    with open(os.path.join(path, "grid.pkl"), "rb") as f:
        grid = pickle.load(f)

    # Create the necessary .csv and .json files
    _pkl_to_csv(path, grid)
    _pkl_to_json(path, grid)
