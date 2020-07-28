from pyreisejl.utility import const
from pyreisejl.utility.helpers import sec2hms

import numpy as np
import os
import pandas as pd

from collections import OrderedDict
from multiprocessing import Process
from time import time


def get_scenario(scenario_id):
    """Returns scenario information.

    :param str scenario_id: scenario index.
    :return: (*dict*) -- scenario information.
    """
    scenario_list = pd.read_csv(const.SCENARIO_LIST, dtype=str)
    scenario_list.fillna('', inplace=True)
    scenario = scenario_list[scenario_list.id == scenario_id]

    return scenario.to_dict('records', into=OrderedDict)[0]


def insert_in_file(filename, scenario_id, column_number, column_value):
    """Updates status in execute list on server.

    :param str filename: path to execute or scenario list.
    :param str scenario_id: scenario index.
    :param str column_number: id of column (indexing starts at 1).
    :param str column_value: value to insert.
    """
    options = "-F, -v OFS=',' -v INPLACE_SUFFIX=.bak -i inplace"
    program = ("'{for(i=1; i<=NF; i++){if($1==%s) $%s=\"%s\"}};1'" %
               (scenario_id, column_number, column_value))
    command = "awk %s %s %s" % (options, program, filename)
    os.system(command)


def launch_scenario_performance(scenario_id, n_parallel_call=1):
    """Launches the scenario.

    :param str scenario_id: scenario index.
    :param int n_parallel_call: number of parallel runs. This function calls
        :func:scenario_julia_call.
    """

    scenario_info = get_scenario(scenario_id)

    min_ts = pd.Timestamp('2016-01-01 00:00:00')
    max_ts = pd.Timestamp('2016-12-31 23:00:00')
    dates = pd.date_range(start=min_ts, end=max_ts, freq='1H')

    start_ts = pd.Timestamp(scenario_info['start_date'])
    end_ts = pd.Timestamp(scenario_info['end_date'])

    # Julia starts at 1
    start_index = dates.get_loc(start_ts) + 1
    end_index = dates.get_loc(end_ts) + 1

    # Create save data folder if does not exist
    output_dir = os.path.join(const.EXECUTE_DIR,
                              'scenario_%s/output' % scenario_info['id'])
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)

    # Update status in ExecuteList.csv on server
    insert_in_file(const.EXECUTE_LIST, scenario_info['id'], '2', 'running')

    # Split the index into n_parallel_call parts
    parallel_call_list = np.array_split(range(start_index, end_index + 1),
                                        n_parallel_call)
    proc = []
    start = time()
    for i in parallel_call_list:
        p = Process(target=scenario_julia_call,
                    args=(scenario_info, int(i[0]), int(i[-1]),))
        p.start()
        proc.append(p)
    for p in proc:
        p.join()
    end = time()

    # Update status in ExecuteList.csv on server
    insert_in_file(const.EXECUTE_LIST, scenario_info['id'], '2', 'finished')

    runtime = round(end - start)
    print('Run time: %s' % str(runtime))
    hours, minutes, seconds = sec2hms(runtime)
    insert_in_file(const.SCENARIO_LIST, scenario_info['id'], '15',
                   '%d:%02d' % (hours, minutes))


def scenario_julia_call(scenario_info, start_index, end_index):
    """
    Starts a Julia engine, runs the add_path file to load Julia code.
    Then, loads the data path and runs the scenario.

    :param dict scenario_info: scenario information.
    :param int start_index: start index.
    :param int end_index: end index.
    """

    from julia.api import Julia
    jl = Julia(compiled_modules=False)
    from julia import Main
    from julia import REISE

    interval = int(scenario_info['interval'].split('H', 1)[0])
    n_interval = int((end_index - start_index + 1) / interval)

    input_dir = os.path.join(const.EXECUTE_DIR,
                             'scenario_%s' % scenario_info['id'])
    output_dir = os.path.join(const.EXECUTE_DIR,
                              'scenario_%s/output/' % scenario_info['id'])

    REISE.run_scenario(
        interval=interval,
        n_interval=n_interval,
        start_index=start_index,
        inputfolder=input_dir,
        outputfolder=output_dir)
    Main.eval('exit()')


if __name__ == "__main__":
    import sys

    launch_scenario_performance(sys.argv[1])
