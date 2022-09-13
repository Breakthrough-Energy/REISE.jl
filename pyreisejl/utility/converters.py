import copy

import numpy as np
from scipy.io import savemat


def create_case_mat(grid, filepath=None, storage_filepath=None):
    """Export a grid to a format suitable for loading into simulation engine.
    If optional filepath arguments are used, the results will also be saved to
    the filepaths provided

    :param powersimdata.input.grid.Grid grid: Grid instance.
    :param str filepath: path where main grid file will be saved, if present
    :param str storage_filepath: path where storage data file will be saved, if present.
    :return: (*tuple*) -- the mpc data as a dictionary and the mpc storage data
        as a dictionary, if present. The storage data will be None if not present.
    """
    grid = copy.deepcopy(grid)

    mpc = {"mpc": {"version": "2", "baseMVA": 100.0}}

    # zone
    mpc["mpc"]["zone"] = np.array(list(grid.id2zone.items()), dtype=object)

    # sub
    sub = grid.sub.copy()
    subid = sub.index.values[np.newaxis].T
    mpc["mpc"]["sub"] = sub.values
    mpc["mpc"]["subid"] = subid

    # bus
    bus = grid.bus.copy()
    busid = bus.index.values[np.newaxis].T
    bus.reset_index(level=0, inplace=True)
    mpc["mpc"]["bus"] = bus.values
    mpc["mpc"]["busid"] = busid

    # bus2sub
    bus2sub = grid.bus2sub.copy()
    mpc["mpc"]["bus2sub"] = bus2sub.values

    # plant
    gen = grid.plant.copy()
    genid = gen.index.values[np.newaxis].T
    genfuel = gen.type.values[np.newaxis].T
    genfuelcost = gen.GenFuelCost.values[np.newaxis].T
    heatratecurve = gen[["GenIOB", "GenIOC", "GenIOD"]].values
    gen.reset_index(inplace=True, drop=True)
    mpc["mpc"]["gen"] = gen.values
    mpc["mpc"]["genid"] = genid
    mpc["mpc"]["genfuel"] = genfuel
    mpc["mpc"]["genfuelcost"] = genfuelcost
    mpc["mpc"]["heatratecurve"] = heatratecurve

    # branch
    branch = grid.branch.copy()
    branchid = branch.index.values[np.newaxis].T
    branchdevicetype = branch.branch_device_type.values[np.newaxis].T
    branch.reset_index(inplace=True, drop=True)
    mpc["mpc"]["branch"] = branch.values
    mpc["mpc"]["branchid"] = branchid
    mpc["mpc"]["branchdevicetype"] = branchdevicetype

    # generation cost
    gencost = grid.gencost.copy()
    gencost["before"].reset_index(inplace=True, drop=True)
    mpc["mpc"]["gencost"] = gencost["before"].values

    # DC line
    if len(grid.dcline) > 0:
        dcline = grid.dcline.copy()
        dclineid = dcline.index.values[np.newaxis].T
        dcline.reset_index(inplace=True, drop=True)
        mpc["mpc"]["dcline"] = dcline.values
        mpc["mpc"]["dclineid"] = dclineid

    # energy storage
    mpc_storage = None

    if len(grid.storage["gen"]) > 0:
        storage = grid.storage.copy()

        mpc_storage = {
            "storage": {
                "xgd_table": np.array([]),
                "gen": np.array(storage["gen"].values, dtype=np.float64),
                "sd_table": {
                    "colnames": storage["StorageData"].columns.values[np.newaxis],
                    "data": storage["StorageData"].values,
                },
            }
        }

    if filepath is not None:
        savemat(filepath, mpc, appendmat=False)
        if mpc_storage is not None:
            savemat(storage_filepath, mpc_storage, appendmat=False)

    return mpc, mpc_storage