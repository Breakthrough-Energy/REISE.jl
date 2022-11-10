Usage
-----
REISE.jl can be used within the Julia interpreter or through the Python scripts.

Julia
+++++
After the installation, the REISE package is registered and can be imported using
:julia:`import REISE` to call :julia:`REISE.run_scenario()` or :julia:`using REISE` to
call :julia:`run_scenario()`.

Running a scenario requires the following inputs:

- ``interval``: the length of each simulation interval (hours).
- ``n_interval``: the number of simulation intervals.
- ``start_index``: the hour to start the simulation, representing the row of the time-
  series profiles in **demand.csv**, **hydro.csv**, **solar.csv**, and **wind.csv**.
  Note that unlike some other programming languages, Julia is 1-indexed, so the first
  index is 1.
- ``inputfolder``: the directory from which to load input files.
- ``optimizer_factory``: an argument that can be passed to ``JuMP.Model`` to create a
  new model instance with an attached solver. Be sure to pass the factory itself (e.g.
  ``GLPK.Optimizer``) rather than an instance (e.g. ``GLPK.Optimizer()``). See the
  ``JuMP.Model`` documentation for more information.

To illustrate, to run a scenario that starts at the 1st hour of the year, runs in 3
intervals of 24 hours each, using input data located in working directory (``pwd()``)
and using the GLPK solver, call:

.. code-block:: julia

   import REISE
   import GLPK

   REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, inputfolder=pwd(),
    optimizer_factory=GLPK.Optimizer
  )

Optional arguments include:

- ``outputfolder``: a directory in which to store results files. The default is a
  subdirectory "output" within the input directory (created if it does not already
  exist).
- ``threads``: the number of threads to be used by the solver. The default is to let
  the solver decide.
- ``solver_kwargs``: a dictionary of String => value pairs to be passed to the solver.

Default settings for running using Gurobi can be accessed if **Gurobi.jl** has already
been imported using the ``REISE.run_scenario_gurobi`` function:

.. code-block:: julia

   using REISE
   using Gurobi

   REISE.run_scenario_gurobi(;
    interval=24, n_interval=3, start_index=1, inputfolder=pwd(),
  )

Optional arguments for ``REISE.run_scenario`` can still be passed as desired.


Python
++++++
There are two main Python scripts included in ``pyreisejl``:

- **pyreisejl/utility/call.py**
- **pyreisejl/utility/extract_data.py**

The first of these scripts transforms more descriptive input parameters into the ones
necessary for the Julia engine while also performing some additional input validation.
The latter, which can be set to automatically occur after the simulation has completed,
extracts key metrics from the resulting **.mat** files to **.pkl** files.


Running a simulation
####################
A simulation can be run as follows:

.. code-block:: bash

   pyreisejl/utility/call.py -s '2016-01-01' -e '2016-01-07' -int 24 -i '/PATH/TO/INPUT/DATA'

It will solve the DCOPF problem in our grid model by interval of 24h using hourly data
located in :bash:`/PATH/TO/INPUT/DATA` from January 1st to January 7th 2016. Note that
the start and end dates need to match dates contained in the input profiles (demand,
hydro, solar, wind). By default Gurobi will be used as the solver and the output data
(**.mat** files) will be saved in an :bash:`output` folder created in the given input
directory.

The full list of arguments can be accessed via :bash:`pyreisejl/utility/call.py --help`:

.. code-block:: text

  usage: call.py [-h] [-s START_DATE] [-e END_DATE] [-int INTERVAL] [-i INPUT_DIR] [-t THREADS] [-d] [-o OUTPUT_DIR] [-k]
                 [--solver SOLVER] [-j JULIA_ENV]
                 scenario_id

  Run REISE.jl simulation.

  positional arguments:
    scenario_id           Scenario ID only if using PowerSimData.

  optional arguments:
    -h, --help            show this help message and exit
    -s START_DATE, --start-date START_DATE
                          The start date for the simulation in format 'YYYY-MM-DD', 'YYYY-MM-DD HH',
                          'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'.
    -e END_DATE, --end-date END_DATE
                          The end date for the simulation in format 'YYYY-MM-DD',
                          'YYYY-MM-DD HH', 'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'.
                          If only the date is specified (without any hours), the entire
                          end-date will be included in the simulation.
    -int INTERVAL, --interval INTERVAL
                          The length of each interval in hours.
    -i INPUT_DIR, --input-dir INPUT_DIR
                          The directory containing the input data files. Required files
                          are 'grid.pkl', 'demand.csv', 'hydro.csv', 'solar.csv', and
                          'wind.csv'.
    -t THREADS, --threads THREADS
                          The number of threads to run the simulation with. This is
                          optional and defaults to Auto.
    -d, --extract-data    If this flag is used, the data generated by the simulation
                          after the engine has finished running will be automatically
                          extracted into .pkl files, and the result.mat files will be
                          deleted. The extraction process can be memory intensive. This
                          is optional and defaults to False if the flag is omitted.
    -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                          The directory to store the extracted data. This is optional
                          and defaults to a folder in the input directory. This flag is
                          only used if the extract-data flag is set.
    -k, --keep-matlab     The result.mat files found in the execute directory will be
                          kept instead of deleted after extraction. This flag is only
                          used if the extract-data flag is set.
    --solver SOLVER       Specify the solver to run the optimization. Will default to
                          gurobi. Current solvers available are clp,glpk,gurobi.
    -j JULIA_ENV, --julia-env JULIA_ENV
                          The path to the julia environment within which to run
                          REISE.jl. This is optional and defaults to the default julia
                          environment.

Different solvers can be used (``--solver``).

There is another optional flag that specifies the number of threads to use for the
simulation run in Gurobi (``--threads``). If the number of threads specified is higher
than the number of logical processor count available, a warning will be generated but
the simulation will still run.

Finally, you can use ``--extract-data`` to automatically extract the data after a
simulation run without having to manually initiate it. Note that the extraction process
can be memory intensive


Extracting Simulation Results
#############################
After the simulation has completed and if the ``--extract-data`` is set in the
**call.py** script, the extraction can be run using the same start and end dates as
were used to run the simulation:

.. code-block:: bash

   pyreisejl/utility/extract_data.py -s '2016-01-01' -e '2016-01-07' -i '/PATH/TO/INPUT/DATA'

The full list of arguments can be accessed via
:bash:`pyreisejl/utility/extract-data.py --help`:

.. code-block:: text

  usage: extract_data.py [-h] [-s START_DATE] [-e END_DATE] [-i INPUT_DIR] [-o OUTPUT_DIR] [-f FREQUENCY] [-k] scenario_id

  Extract data from the results of the REISE.jl simulation.

  positional arguments:
    scenario_id           Scenario ID only if using PowerSimData.

  optional arguments:
    -h, --help            show this help message and exit
    -s START_DATE, --start-date START_DATE
                          The start date as provided to run the simulation. Supported
                          formats are 'YYYY-MM-DD', 'YYYY-MM-DD HH', 'YYYY-MM-DD HH:MM',
                          or 'YYYY-MM-DD HH:MM:SS'.
    -e END_DATE, --end-date END_DATE
                          The end date as provided to run the simulation. Supported
                          formats are 'YYYY-MM-DD', 'YYYY-MM-DD HH', 'YYYY-MM-DD HH:MM',
                          or 'YYYY-MM-DD HH:MM:SS'.
    -i INPUT_DIR, --input-dir INPUT_DIR
                          The directory containing the input data files. Required files
                          are 'grid.pkl', 'demand.csv', 'hydro.csv', 'solar.csv', and
                          'wind.csv'.
    -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                          The directory to store the results. This is optional and
                          defaults to a folder in the input directory.
    -f FREQUENCY, --frequency FREQUENCY
                          The frequency of data points in the original profile csvs as a
                          Pandas frequency string. This is optional and defaults to an
                          hour.
    -k, --keep-matlab     If this flag is used, the result.mat files found in the execute
                          directory will be kept instead of deleted.

When manually running the extract_data process, the script assumes the frequency of the
input profiles are hourly and will construct the timestamps for the resulting data
accordingly. If a different frequency was used for the input data, it must be specified
via ``--frequency``. Also, other parameters can be invoked to handle output data.

When the script has finished running, the following **.pkl** files will be available:

- **PF.pkl** (power flow)
- **PG.pkl** (power generated)
- **LMP.pkl** (locational marginal price)
- **CONGU.pkl** (congestion, upper flow limit)
- **CONGL.pkl** (congestion, lower flow limit)
- **AVERAGED_CONG.pkl** (time averaged congestion)

If the grid used in the simulation contains DC lines, energy storage devices, or
flexible demand resources, the following files will also be extracted as necessary:

- **PF_DCLINE.pkl** (power flow on DC lines)
- **STORAGE_PG.pkl** (power generated by storage units)
- **STORAGE_E.pkl** (energy state of charge)
- **LOAD_SHIFT_DN.pkl** (demand that is curtailed)
- **LOAD_SHIFT_UP.pkl** (demand that is added)

If one or more intervals of the simulation were found to be infeasible without shedding
load, the following file will also be extracted:

- **LOAD_SHED.pkl** (load shed profile for each load bus)


Compatibility with our Software Ecosystem
#########################################
Both **pyreisejl/utility/call.py** and **pyreisejl/utility/extract_data.py** can be
called using a positional argument that corresponds to a scenario id as generated by
`PowerSimData <https://github.com/Breakthrough-Energy/PowerSimData>`_. Using this
invocation assumes you have installed our software ecosystem. See `Installation Guide
<https://breakthrough-energy.github.io/docs/user/installation_guide.html>`_ ) if you
are interested.
