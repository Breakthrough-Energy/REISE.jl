import os
import pickle

cols = {
    "branch": ["branch_id", "from_bus_id", "to_bus_id", "x", "rateA"],
    "dcline": ["dcline_id", "from_bus_id", "to_bus_id", "Pmin", "Pmax"],
    "bus": ["bus_id", "Pd", "zone_id"],
    "plant": [
        "plant_id",
        "bus_id",
        "status",
        "Pmin",
        "Pmax",
        "type",
        "ramp_30",
        "GenFuelCost",
        "GenIOB",
        "GenIOC",
        "GenIOD",
    ],
}

drop_cols = {"gencost": ["plant_id", "interconnect"]}
drop_cols["gencost_orig"] = drop_cols["gencost"]


def _save(path, name, df):
    df = df.reset_index()
    df = df.loc[:, cols.get(name, df.columns)]
    df = df.drop(drop_cols.get(name, []), axis=1)
    df.to_csv(os.path.join(path, f"{name}.csv"), index=False)


def _save_storage(path, name, df):
    df.to_csv(os.path.join(path, f"{name}.csv"), index=False)


def pkl_to_csv(path):
    with open(os.path.join(path, "grid.pkl"), "rb") as f:
        grid = pickle.load(f)
    _save(path, "branch", grid.branch)
    _save(path, "dcline", grid.dcline)
    _save(path, "bus", grid.bus)
    _save(path, "plant", grid.plant)
    _save(path, "gencost_orig", grid.gencost["before"])
    _save(path, "gencost", grid.gencost["after"])

    storage = grid.storage
    if not storage["gen"].empty:
        _save_storage(path, "StorageData", storage["StorageData"])
        _save_storage(path, "storage_gen", storage["gen"])
