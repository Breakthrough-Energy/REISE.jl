[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

# REISE.jl
Renewable Energy Integration Simulation Engine.

This repository contains, in the `src` folder, the Julia scripts to run the power-flow study in the U.S. electric grid. The simulation engine relies on the use of an external optimization solver; any solver [compatible with JuMP] can be used, though code that makes efficient use of the capabilities of [Gurobi] is included in this repository.

## Table of Contents
1. [Dependencies](#dependencies)
2. [Installation (Local)](#installation-local)
3. [Usage (Julia)](#usage-julia)
4. [Usage (Python)](#usage-python)
5. [Docker](#docker)
6. [Package Structure](#package-structure)
7. [Formulation](#formulation)


## Dependencies
This package requires installations of the following, with recommended versions listed.
- [Julia], version 1.5
- [Python], version 3.8

An external solver is required to run optimizations. We recommend [Gurobi] (version 9.1), though any other solver that is [compatible with JuMP] can be used.
Note: as Gurobi is a commercial solver, a [Gurobi license file] is required. This may be either a local license or a [Gurobi Cloud license]. [Free licenses for academic use] are available.

This package can also be run using [Docker], which will automatically handle the installation of Julia, Python, and all dependencies. Gurobi is also installed, although as before a [Gurobi license file] is still required to use Gurobi as a solver; other solvers can also be used.

For sample data to use with the simulation, please visit [Zenodo].

### System Requirements

Large simulations can require significant amounts of RAM. The amount of RAM necessary is proportional to both the size of the grid and the size of the interval with which to run the simulation.

As a general estimate, 1-2 GB of RAM is needed per hour in the interval in a simulation across the entire USA grid. For example, a 24-hour interval would require 24-48 GB of RAM; if only 16 GB of RAM is available, consider using a time interval of 8 hours or less as that would take 8-16 GB of RAM.

The memory necessary would also be proportional to the size of grid used, so as the Western interconnect is roughly 8 times smaller than the entire USA grid, a simulation of just the Western interconnect with a 24-hour interval would require ~3-6 GB of RAM.

## Installation (Local)   

When installing this package locally, the below dependencies will need to be installed following the provider recommendations:
- [Download Julia]
- [Download Python]

If Gurobi is to be used as the solver, this will need to be installed as well:
- [Gurobi Installation Guide]

The package itself has two components that require installation:
- [Julia package](#julia-package-installation) to run the simulation
- optional [Python scripts](#python-requirements-installation) for some additional pre- and post-processing

Instead of installing locally, this package can also be used with the included [Docker](#Docker) image. 

Detailed installation instructions for both the necessary applications and packages can be found below:
1. [Gurobi Installation](#gurobi-installation)
   1. [Gurobi Installation Example (Linux + Cloud License)](#gurobi-installation-example-linux-cloud-license)
   2. [Gurobi Installation Verification](#gurobi-verification)
2. [Julia Installation](#julia-installation)
   1. [Julia Installation Example (Linux)](#julia-installation-example-linux)
   2. [Julia Package Installation](#julia-package-installation)
   3. [Julia Installation Verification](#julia-verification)
3. [Python Installation](#python-installation)
   1. [Python Requirements Installation](#python-requirements-installation)
   2. [Python Installation Verification](#python-installation-verification)

### Gurobi Installation
Installation of `Gurobi` depends on both your operating system and license type. Detailed instructions can be found at the [Gurobi Installation Guide].

#### Gurobi Installation Example (Linux + Cloud License)

1. Choose a destination directory for `Gurobi`. For a shared installation, `/opt` is recommended.
```bash
cd /opt
```

2. Download and unzip the `Gurobi` package in the chosen directory.
```bash
wget https://packages.gurobi.com/9.1/gurobi9.1.0_linux64.tar.gz
tar -xvfz gurobi9.1.0_linux64.tar.gz
```
This will create a subdirectory, `/opt/gurobi910/linux64` in which the complete distribution is located. This will be considered the `<installdir>` in the rest of this section.

2. Set environmental variables for `Gurobi`:
- `GUROBI_HOME` should be set to your `<installdir>`.
- `PATH` should be extended to include `<installdir>/bin`.`
- `LD_LIBRARY_PATH` should be extended to include <installdir>/lib. 

For bash shell users, add the following to the `.bashrc` file:
```bash
export GUROBI_HOME="/opt/gurobi910/linux64"
export PATH="${PATH}:${GUROBI_HOME}/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${GUROBI_HOME}/lib"
```

3. The `Gurobi` license needs to be download and installed. Download a copy of your Gurobi license from the account portal, and copy it to the parent directory of the `<installdir>`.

```bash
cp gurobi.lic /opt/gurobi910/gurobi.lic
```

#### Gurobi Verification

To verify that Gurobi has installed properly, run `gurobi.sh` located in the `bin` folder of the Gurobi installation.
```bash
/usr/share/gurobi910/linux64/bin/gurobi.sh
```

An example of the expected output for this program (using a cloud license):
```
This program should give the following output
Python 3.7.4 (default, Oct 29 2019, 10:15:53) 
[GCC 4.4.7 20120313 (Red Hat 4.4.7-18)] on linux
Type "help", "copyright", "credits" or "license" for more information.
Using license file /usr/share/gurobi_license/gurobi.lic
Set parameter CloudAccessID
Set parameter CloudSecretKey
Set parameter LogFile to value gurobi.log
Waiting for cloud server to start (pool default)...
Starting...
Starting...
Starting...
Starting...
Compute Server job ID: 1eacfb69-3083-44e2-872e-58515b143b5d
Capacity available on 'https://ip-10-0-55-163:61000' - connecting...
Established HTTPS encrypted connection

Gurobi Interactive Shell (linux64), Version 9.1.0
Copyright (c) 2020, Gurobi Optimization, LLC
Type "help()" for help

gurobi> 
```

### Julia Installation

[Download Julia] and install the version specific to your operating system.

#### Julia Installation Example (Linux)

1. Choose a destination directory for `Julia`. Again, `/opt` is recommended.
```bash
cd /opt
```

2. Download and unzip the `Julia` package in the chosen directory.
```bash
wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz
tar -xf julia-1.5.3-linux-x86_64.tar.gz
```

3. Add `Julia` to the `PATH` environmental variable.

For bash shell users, add the following to the `.bashrc` file:
```bash
export PATH="$PATH:/opt/julia-1.5.3/bin"
```


#### Julia Package Installation
**Note**: To install the `Gurobi.jl` part of this package, `Julia` will need
to find the Gurobi installation folder. This is done by specifying an environment
variable for `GUROBI_HOME` pointing to the Gurobi `<installdir>`.

For more information, see the [Gurobi.jl] documentation.

As this package is unregistered with Julia, the easiest way to use this package
is to first clone the repo locally (be sure to avoid whitespace in the path):
```bash
git clone https://github.com/Breakthrough-Energy/REISE.jl
```

The package will need to be added to each user's default `Julia` environment.
This can be done by opening up `Julia` and activiating the Pkg REPL (the
built-in package manager) with `]`. To exit the Pkg REPL, use `backspace`.

```julia
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.5.2 (2020-09-23)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> ]

pkg>
```

From here, there are many ways to add this package to `Julia`. Listed below are
three different options:

1. `add`ing a package allows a specific branch to be specified from the git
repository. It will use the most recent allowed version of the dependencies
specified in the `Project.toml` file. Currently, this package is known to be
compatible with JuMP v0.21.3; this is specified in the `Project.toml` file,
but there may be other packages for which the latest version does not maintain
backward-compatibility.
```julia
pkg> add /PATH/TO/REISE.jl#develop
```

2. `dev`ing a package will always reflect the latest version of the code specified
at the repository. If a branch other than `develop` is checked out, the code in
that branch will be run. Like the above option, this method will also use the
most recent allowed version of the dependencies for which backward-compatibility
is not guaranteed.
```julia
pkg> dev /PATH/TO/REISE.jl
```

3. Using the specific environment specified in the project will use the exact
dependency versions specified in the package. This will first have to be
activated and instantiated to download and install all dependencies in `Julia`:

```julia
pkg> activate /PATH/TO/REISE.jl
 Activating environment at `~/REISE.jl/Project.toml`

(REISE) pkg> instantiate
```
In order for the below Python scripts to use this environment, set a
`JULIA_PROJECT` environment variable to the path to `/PATH/TO/REISE.jl`.

For more information about the different installation options, please see the
documentation for the [Julia Package Manager].

#### Verification and Troubleshooting

To verify that the package has been successfully installed, open a new instance of `Julia` and verify that the `REISE` package can load without any errors with the following command:

```julia
using REISE
```

### Python Packages

#### Python Requirements Installation
The dependencies of the Python scripts contained in `pyreisejl` are not
automatically installed. See `requirements.txt` for details. These requirements
can be installed using pip:
```bash
pip install -r requirements.txt
```

#### Python Installation Verification
To verify that the included Python scripts can successfully run `REISE`, open a Python interpreter and run the following commands. They should return with no errors.
```python
from julia.api import Julia
Julia(compiled_modules=False)
from julia import REISE
```

Note that the final import of `REISE` may take a couple of minutes to complete.

## Usage (Julia)
Installation registers a package named `REISE`. Following Julia naming conventions, the `.jl` is dropped. The package can be imported using: `import REISE` to call `REISE.run_scenario()`, or `using REISE` to call `run_scenario()`.

Running a scenario requires the following inputs:
- `interval`: the length of each simulation interval (hours).
- `n_interval`: the number of simulation intervals.
- `start_index`: the hour to start the simulation, representing the row of the time-series profiles in `demand.csv`, `hydro.csv`, `solar.csv`, and `wind.csv`.
Note that unlike some other programming languages, Julia is 1-indexed, so the first index is `1`.
- `inputfolder`: the directory from which to load input files.
- `optimizer_factory`: an argument which can be passed to `JuMP.Model` to create a new model instance with an attached solver.
Be sure to pass the factory itself (e.g. `GLPK.Optimizer`) rather than an instance (e.g. `GLPK.Optimizer()`). See the [JuMP.Model documentation] for more information.

As an example, to run a scenario which starts at the `1`st hour of the year, runs in `3` intervals of `24` hours each, loading input data from your present working directory (`pwd()`), using the `GLPK` solver, call:
```julia
import REISE
import GLPK
REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, inputfolder=pwd(), optimizer_factory=GLPK.Optimizer
)
```

Optional arguments include:
- `num_segments`: the number of piecewise linear segments to use when linearizing polynomial cost curves (default is 1).
- `outputfolder`: a directory in which to store results files. The default is a subdirectory `"output"` within the input directory (created if it does not already exist).
- `threads`: the number of threads to be used by the solver. The default is to let the solver decide.
- `solver_kwargs`: a dictionary of `String => value` pairs to be passed to the solver.

Default settings for running using Gurobi can be accessed if `Gurobi.jl` has already been imported using the `REISE.run_scenario_gurobi` function:
```julia
import REISE
import Gurobi
REISE.run_scenario_gurobi(;
    interval=24, n_interval=3, start_index=1, inputfolder=pwd(),
)
```

Optional arguments for `REISE.run_scenario` can still be passed as desired.

## Usage (Python)

The Python scripts included in `pyreisejl` perform some additional input validation for the Julia engine before running the simulation and extract data from  the resulting `.mat` files to `.pkl` files.

There are two main Python scripts included in `pyreisejl`:
- `pyreisejl/utility/call.py`
- `pyreisejl/utility/extract_data.py`

The first of these scripts transforms more descriptive input parameters into the
ones necessary for the Julia engine while also performing some additional input
validation. The latter, which can be set to automatically occur after the
simulation has completed, extracts key metrics from the resulting `.mat` files
to `.pkl` files.

For example, a simulation can be run as follows:
```bash
pyreisejl/utility/call.py -s '2016-01-01' -e '2016-01-07' -int 24 -i '/PATH/TO/INPUT/FILES'
```

After the simulation has completed, the extraction can be run using the same start and end date as were used to run the simulation:
```bash
pyreisejl/utility/extract_data.py -s '2016-01-01' -e '2016-01-07' -x '/PATH/TO/OUTPUT/FILES'
```


### Running a Simulation

**Note** To see the available options for the `call.py` or `extract_data.py` script, use the `-h, --help` flag when calling the script.

To run the `REISE.jl` simulation from Python, using Gurobi as the solver, run `call.py` with the following required options:
```
  -s, --start-date START_DATE
                        The start date for the simulation in format
			'YYYY-MM-DD'. 'YYYY-MM-DD HH'. 'YYYY-MM-DD HH:MM',
			or 'YYYY-MM-DD HH:MM:SS'.
  -e, --end-date END_DATE
                        The end date for the simulation in format
			'YYYY-MM-DD'. 'YYYY-MM-DD HH'. 'YYYY-MM-DD HH:MM',
			or 'YYYY-MM-DD HH:MM:SS'. If only the date is specified
			(without any hours), the entire end-date will be
			included in the simulation.
  -int, --interval INTERVAL
                        The length of each interval in hours.
  -i, --input-dir INPUT_DIR
                        The directory containing the input data files. Required
			files are 'case.mat', 'demand.csv', 'hydro.csv',
			'solar.csv', and 'wind.csv'.
```

Note that the start and end dates need to match dates contained in the input
profiles (demand, hydro, solar, wind).


This Python script will validate some of the inputs and translate them into the
required Julia inputs listed below. By default, the Julia engine creates
`result_*.mat` files in an `output` folder created in the given input directory.
To save the matlab files to a different directory, there is an optional flag to
specify the execute directory. If this directory already exists, any existing
computations will be overwritten.
```
  -x EXECUTE_DIR, --execute-dir EXECUTE_DIR
                        The directory to store the results. This is optional
			and defaults to an execute folder that will be created
			in the input directory if it does not exist.
```

There is another optional flag to specify the number of threads to use for the
simulation run in `Gurobi`. If the number of threads specified is higher than
the number of logical processor count available, the simulation will still run
with a warning. Specifying zero threads defaults to Auto.
```
  -t THREADS, --threads THREADS
                        The number of threads with which to run the simulation.
			This is optional and defaults to Auto.
```

The documentation for these options can also been accessed by using the
help flag:
```
  -h, --help            show this help message and exit
```

### Extracting Simulation Results

The script `extract_data.py` extracts the following Pandas DataFrames from the
matlab files generated by the Julia engine:

* PF.pkl (power flow)
* PG.pkl (power generated)
* LMP.pkl (locational marginal price)
* CONGU.pkl (congestion, upper flow limit)
* CONGL.pkl (congestion, lower flow limit)
* AVERAGED_CONG.pkl (time averaged congestion)

If the grid used in the simulation contains DC lines, energy storage devices, or flexible demand resources, the following files will also be extracted as necessary:

* PF_DCLINE.pkl (power flow on DC lines)
* STORAGE_PG.pkl (power generated by storage units)
* STORAGE_E.pkl (energy state of charge)
* LOAD_SHIFT_DN.pkl (demand that is curtailed)
* LOAD_SHIFT_UP.pkl (demand that is added)

If one or more intervals of the simulation were found to be infeasible without shedding load, the following file will also be extracted:
* LOAD_SHED.pkl (load shed profile for each load bus)

The extraction process can be memory intensive, so it does not automatically
happen after a simulation run by default. If resource constraints are not a
concern, however, the below flag can be used with `call.py` to automatically
extract the data after a simulation run without having to manually initiate it:

```
  -d, --extract-data    If this flag is used, the data generated by the
      			simulation after the engine has finished running will be
			automatically extracted into .pkl files, and the
			result.mat files will be deleted. The extraction process
			can be memory intensive. This is optional and defaults
			to False if the flag is omitted.
```

To manually extract the data, run `extract_data.py` with the following options:

```
  -s START_DATE, --start-date START_DATE
                        The start date as provided to run the simulation.
			Supported formats are 'YYYY-MM-DD'. 'YYYY-MM-DD HH'.
			'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'.
  -e END_DATE, --end-date END_DATE
                        The end date as provided to run the simulation.
			Supported formats are 'YYYY-MM-DD'. 'YYYY-MM-DD HH'.
			'YYYY-MM-DD HH:MM', or 'YYYY-MM-DD HH:MM:SS'.
  -x EXECUTE_DIR, --execute-dir EXECUTE_DIR
                        The directory where the REISE.jl results are stored.
```

When manually running the `extract_data` process, the script assumes the
frequency of the input profile csv's are hourly and will construct the
timestamps for the resulting data accordingly. If a different frequency was
used for the input data, it can be specified with the following option:
```
  -f [FREQUENCY], --frequency [FREQUENCY]
                        The frequency of data points in the original profile
			csvs as a Pandas frequency string. This is optional
			and defaults to an hour.
```

The following optional options are available to both `call.py` when using the
automatic extraction flag and to `extract_data.py`:

```
  -o OUTPUT_DIR, --output-dir OUTPUT_DIR
                        The directory to store the extracted data. This is
			optional and defaults to the execute directory.
			This flag is only used if the extract-data flag is set.
  -m MATLAB_DIR, --matlab-dir MATLAB_DIR
                        The directory to store the modified case.mat used by
			the engine. This is optional and defaults to the execute
			directory. This flag is only used if the extract-data
			flag is set.
  -k, --keep-matlab     The result.mat files found in the execute directory will
      			be kept instead of deleted after extraction. This flag
			is only used if the extract-data flag is set.
```

### Compatibility with PowerSimData

Within the Python code in this repo, there is some code to maintain
compatibility with the `PowerSimData` framework.

Both `call.py` and `extract_data.py` can be called using a positional
argument that corresponds to a scenario id as generated by the
`PowerSimData` framework. Using this invocation assumes the presence
of the `PowerSimData` infrastructure including both a Scenario List
Manager and Execute List Manager. This option is not intended for manual
simulation runs.

Note also the different naming convention for various directories by
`PowerSimData` as compared to the options for the Python scripts within
this repository.

## Docker

The easiest way to setup this engine is within a Docker image.

There is an included `Dockerfile` that can be used to build the Docker image. With the Docker daemon installed and running, navigate to the `REISE.jl` folder containing the `Dockerfile` and build the image:

```bash
docker build . -t reisejl
```

To run the Docker image, you will need to mount two volumes; one containing the
`Gurobi` license file and another containing the necessary input files for the
engine. 

```bash
docker run -it -v /LOCAL/PATH/TO/GUROBI.LIC:/usr/share/gurobi_license -v /LOCAL/PATH/TO/DATA:/usr/share/data reisejl bash
```

The following command will start a bash shell session within the container,
using the Python commands described above.

```bash
python pyreisejl/utility/call.py -s '2016-01-01' -e '2016-01-07' -int 24 -i '/usr/share/data'
```

Note that loading the `REISE.jl` package can take up to a couple of minutes,
so there may not be any output in this time.


## Package Structure
`REISE.jl` contains only imports and includes. Individual type and function definitions are all in the other files in the `src` folder.


## Contribution
Contributions are welcome!
For anything but small fixes, please open an Issue describing the bug you're encountering,
or additional capabilities you wish were included.
This allows other people to offer guidance on design and implementation and gives context for an eventual pull request.
This package is formatted to [Blue](https://github.com/invenia/BlueStyle) style,
and pull requests will be automatically checked against consistency to this style guide.
Formatting is as easy as:
```julia
julia> using JuliaFormatter

julia> format(FILE_OR_DIRECTORY)
```
If an individual file is passed, that file will be formatted;
if a directory is passed, all julia files in that directory and subdirectories will be formatted.
`format(".")` can be used from the package root for convenience.


## Formulation
[comment]: # (getting Github to display LaTeX via the approach in https://gist.github.com/a-rodin/fef3f543412d6e1ec5b6cf55bf197d7b)
[comment]: # (Encoding LaTeX via https://www.urlencoder.org/)


### Sets
- ![B](https://render.githubusercontent.com/render/math?math=B):
Set of buses, indexed by
![b](https://render.githubusercontent.com/render/math?math=b).
- ![I](https://render.githubusercontent.com/render/math?math=I):
Set of generators, indexed by
![i](https://render.githubusercontent.com/render/math?math=i).
- ![L](https://render.githubusercontent.com/render/math?math=L):
Set of transmission network branches, indexed by
![l](https://render.githubusercontent.com/render/math?math=l).
- ![S](https://render.githubusercontent.com/render/math?math=S):
Set of generation cost curve segments, indexed by
![s](https://render.githubusercontent.com/render/math?math=s).
- ![T](https://render.githubusercontent.com/render/math?math=T):
Set of time periods, indexed by
![t](https://render.githubusercontent.com/render/math?math=t).


#### Subsets
- ![I^{\text{H}}](https://render.githubusercontent.com/render/math?math=I%5E%7B%5Ctext%7BH%7D%7D):
Set of hydro generators.
- ![I^{\text{S}}](https://render.githubusercontent.com/render/math?math=I%5E%7B%5Ctext%7BS%7D%7D):
Set of solar generators.
- ![I^{\text{W}}](https://render.githubusercontent.com/render/math?math=I%5E%7B%5Ctext%7BW%7D%7D):
Set of wind generators.


### Variables
- ![E_{b,t}](https://render.githubusercontent.com/render/math?math=E_%7Bb%2Ct%7D):
Energy available in energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![f_{l,t}](https://render.githubusercontent.com/render/math?math=f_%7Bl%2Ct%7D):
Power flowing on branch ![l](https://render.githubusercontent.com/render/math?math=l)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,t}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Ct%7D):
Power injected by each generator ![i](https://render.githubusercontent.com/render/math?math=i)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,s,t}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Cs%2Ct%7D):
Power injected by each generator ![i](https://render.githubusercontent.com/render/math?math=i)
from cost curve segment ![s](https://render.githubusercontent.com/render/math?math=s)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![J_{b,t}^{\text{chg}}](https://render.githubusercontent.com/render/math?math=J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bchg%7D%7D):
Charging power of energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![J_{b,t}^{\text{dis}}](https://render.githubusercontent.com/render/math?math=J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdis%7D%7D):
Discharging power of energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![s_{b,t}](https://render.githubusercontent.com/render/math?math=s_%7Bb%2Ct%7D):
Load shed at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![v_{l,t}](https://render.githubusercontent.com/render/math?math=v_%7Bl%2Ct%7D):
Branch limit violation for branch ![l](https://render.githubusercontent.com/render/math?math=l)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![\delta_{b,t}^{\text{down}}](https://render.githubusercontent.com/render/math?math=%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdown%7D%7D):
Amount of flexible demand curtailed at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![\delta_{b,t}^{\text{up}}](https://render.githubusercontent.com/render/math?math=%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bup%7D%7D):
Amount of flexible demand added at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![{\theta}_{b,t}](https://render.githubusercontent.com/render/math?math=%7B%5Ctheta%7D_%7Bb%2Ct%7D):
Voltage angle of bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).


### Parameters
- ![a^{\text{shed}}](https://render.githubusercontent.com/render/math?math=a%5E%7B%5Ctext%7Bshed%7D%7D):
Binary parameter, whether load shedding is enabled.
- ![a^{\text{viol}}](https://render.githubusercontent.com/render/math?math=a%5E%7B%5Ctext%7Bviol%7D%7D):
Binary parameter, whether transmission limit violation is enabled.
- ![c_{i,s}](https://render.githubusercontent.com/render/math?math=c_%7Bi%2Cs%7D):
Cost coefficient for segment ![s](https://render.githubusercontent.com/render/math?math=s)
of generator ![i](https://render.githubusercontent.com/render/math?math=i).
- ![C_{i}^{\text{min}}](https://render.githubusercontent.com/render/math?math=C_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D):
Cost of running generator ![i](https://render.githubusercontent.com/render/math?math=i)
at its minimum power level.
- ![d_{b,t}](https://render.githubusercontent.com/render/math?math=d_%7Bb%2Ct%7D):
Power demand at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![E_{b,0}](https://render.githubusercontent.com/render/math?math=E_%7Bb%2C0%7D):
Initial energy available in energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b).
- ![E_{b}^{\text{max}}](https://render.githubusercontent.com/render/math?math=E_%7Bb%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Maximum energy stored in energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b).
- ![f_{l}^{\text{max}}](https://render.githubusercontent.com/render/math?math=f_%7Bl%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Maximum flow over line ![l](https://render.githubusercontent.com/render/math?math=l).
- ![g_{i}^{\text{min}}](https://render.githubusercontent.com/render/math?math=g_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D):
Minimum generation for generator ![i](https://render.githubusercontent.com/render/math?math=i).
- ![g_{i,s}^{\text{max}}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Cs%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Generator cost curve segment width.
- ![J_{b}^{\text{max}}](https://render.githubusercontent.com/render/math?math=J_%7Bb%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Maximum charging/discharging power of energy storage devices at bus ![b](https://render.githubusercontent.com/render/math?math=b).
- ![m_{l,b}^{\text{line}}](https://render.githubusercontent.com/render/math?math=m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D):
Mapping of branches to buses.
![m_{l,b}^{\text{line}} = 1](https://render.githubusercontent.com/render/math?math=m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20%3D%201)
if branch ![l](https://render.githubusercontent.com/render/math?math=l) 'starts'
at bus ![b](https://render.githubusercontent.com/render/math?math=b),
![m_{l,b}^{\text{line}} = -1](https://render.githubusercontent.com/render/math?math=m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20%3D%20-1)
if branch ![l](https://render.githubusercontent.com/render/math?math=l) 'ends'
at bus ![b](https://render.githubusercontent.com/render/math?math=b),
otherwise ![m_{l,b}^{\text{line}} = 0](https://render.githubusercontent.com/render/math?math=m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20%3D%200).
- ![m_{i,b}^{\text{unit}}](https://render.githubusercontent.com/render/math?math=m_%7Bi%2Cb%7D%5E%7B%5Ctext%7Bunit%7D%7D):
Mapping of generators to buses.
![m_{i,b}^{\text{unit}} = 1](https://render.githubusercontent.com/render/math?math=m_%7Bi%2Cb%7D%5E%7B%5Ctext%7Bunit%7D%7D%20%3D%201)
if generator ![i](https://render.githubusercontent.com/render/math?math=i)
is located at bus ![b](https://render.githubusercontent.com/render/math?math=b),
otherwise ![m_{i,b}^{\text{unit}} = 0](https://render.githubusercontent.com/render/math?math=m_%7Bi%2Cb%7D%5E%7B%5Ctext%7Bunit%7D%7D%20%3D%200).
- ![M](https://render.githubusercontent.com/render/math?math=M):
An arbitrarily-large constant, used in 'big-M' constraints to either constrain to 0, or relax constraint.
- ![p^{\text{e}}](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Be%7D%7D):
Value of stored energy at beginning/end of interval (so that optimization does not automatically drain the storage by end-of-interval).
- ![p^{\text{s}}](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Bs%7D%7D):
Load shed penalty factor.
- ![p^{\text{v}}](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Bv%7D%7D):
Transmission violation penalty factor.
- ![r_{i}^{\text{up}}](https://render.githubusercontent.com/render/math?math=r_%7Bi%7D%5E%7B%5Ctext%7Bup%7D%7D):
Ramp-up limit for generator ![i](https://render.githubusercontent.com/render/math?math=i).
- ![r_{i}^{\text{down}}](https://render.githubusercontent.com/render/math?math=r_%7Bi%7D%5E%7B%5Ctext%7Bdown%7D%7D):
Ramp-down limit for generator ![i](https://render.githubusercontent.com/render/math?math=i).
- ![w_{i,t}](https://render.githubusercontent.com/render/math?math=w_%7Bi%2Ct%7D):
Power available from time-varying generator (hydro, wind, solar) ![i](https://render.githubusercontent.com/render/math?math=i)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![x_{l}](https://render.githubusercontent.com/render/math?math=x_%7Bl%7D):
Impedance of branch ![l](https://render.githubusercontent.com/render/math?math=l).
- ![\underline{\delta}_{b, t}](https://render.githubusercontent.com/render/math?math=%5Cunderline%7B%5Cdelta%7D_%7Bb%2Ct%7D):
Demand flexibility curtailments available (in MW) at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![\overline{\delta}_{b, t}](https://render.githubusercontent.com/render/math?math=%5Coverline%7B%5Cdelta%7D_%7Bb%2Ct%7D):
Demand flexibility additions available (in MW) at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![\Delta^{\text{balance}}](https://render.githubusercontent.com/render/math?math=\Delta^{\text{balance}}):
The length of the rolling load balance window (in hours), used to account for the duration that flexible demand is deviating from the base demand.
- ![\eta_{b}^{\text{chg}}](https://render.githubusercontent.com/render/math?math=%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bchg%7D%7D):
Charging efficiency of storage device at bus ![b](https://render.githubusercontent.com/render/math?math=b).
- ![\eta_{b}^{\text{dis}}](https://render.githubusercontent.com/render/math?math=%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bdis%7D%7D):
Discharging efficiency of storage device at bus ![b](https://render.githubusercontent.com/render/math?math=b).


### Constraints

All equations apply over all entries in the indexed sets unless otherwise listed.

- ![0 \le g_{i,s,t} \le g_{i,s,t}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%5Cle%20g_%7Bi%2Cs%2Ct%7D%5Cle%20g%5E%7B%5Ctext%7Bmax%7D%7D_%7Bi%2Cs%2Ct%7D):
Generator segment power is non-negative and less than the segment width.
- ![0 \le s_{b,t} \le a^{\text{shed}} \cdot ( d_{b,t} + \delta_{b,t}^{\text{up}} - \delta_{b,t}^{\text{down}} )](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20s_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20%28%20d_%7Bb%2Ct%7D%20%2B%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bup%7D%7D%20-%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdown%7D%7D%20%29):
Load shed is non-negative and less than the demand at that bus (including the impact of demand flexibility), if load shedding is enabled.
If not, load shed is fixed to 0.
- ![0 \le v_{b,t} \le a^{\text{viol}} \cdot M](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20v_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20M):
Transmission violations are non-negative, if they are enabled
(![M](https://render.githubusercontent.com/render/math?math=M) is a sufficiently large constant that there is no effective upper limit when ![a^{\text{shed}} = 1](https://render.githubusercontent.com/render/math?math=a%5E%7B%5Ctext%7Bshed%7D%7D%20%3D%201)).
If not, they are fixed to zero.
- ![0 \le J_{b,t}^{\text{chg}} \le J_{b}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bchg%7D%7D%20%5Cle%20J_%7Bb%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Storage charging power is non-negative and limited by the maximum charging power at that bus.
- ![0 \le J_{b,t}^{\text{dis}} \le J_{b}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdis%7D%7D%20%5Cle%20J_%7Bb%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Storage discharging power is non-negative and limited by the maximum discharging power at that bus.
- ![0 \le E_{b,t} \le E_{b}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20E_%7Bb%2Ct%7D%20%5Cle%20E_%7Bb%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Storage state-of-charge is non-negative and limited by the maximum state of charge at that bus.
- ![g_{i,t} = w_{i,t} \forall i \in I^{\text{H}}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Cs%7D%20%3D%20w_%7Bi%2Ct%7D%20%5Cforall%20i%20%5Cin%20I%5E%7B%5Ctext%7BH%7D%7D):
Hydro generator power is fixed to the profiles.
- ![0 \le g_{i,t} \le w_{i,t} \forall i \in I^{\text{S}} \cup I^{\text{W}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20g_%7Bi%2Cs%7D%20%5Cle%20w_%7Bi%2Ct%7D%20%5Cforall%20i%20%5Cin%20I%5E%7B%5Ctext%7BS%7D%7D%20%5Ccup%20I%5E%7B%5Ctext%7BW%7D%7D):
Solar and wind generator power is non-negative and not greater than the availability profiles.
- ![\sum_{i \in I} m_{i,b}^{\text{unit}} g_{i,t} + \sum_{l \in L} m_{l,b}^{\text{line}} f_{l,t} + J_{b,t}^{\text{dis}} + s_{b,t} + \delta_{b,t}^{\text{down}} = d_{b,t} + J_{b,t}^{\text{chg}} + \delta_{b,t}^{\text{up}}](https://render.githubusercontent.com/render/math?math=%5Csum_%7Bi%20%5Cin%20I%7D%20m_%7Bi%2Cb%7D%5E%7B%5Ctext%7Bunit%7D%7D%20g_%7Bi%2Ct%7D%20%2B%20%5Csum_%7Bl%20%5Cin%20L%7D%20m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20f_%7Bl%2Ct%7D%20%2B%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdis%7D%7D%20%2B%20s_%7Bb%2Ct%7D%20%2B%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdown%7D%7D%20%3D%20d_%7Bb%2Ct%7D%20%2B%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bchg%7D%7D%20%2B%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bup%7D%7D%20):
Power balance at each bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,t} = g_{i}^{\text{min}} + \sum_{s \in S} g_{i,s,t}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Ct%7D%20%3D%20g_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D%20%2B%20%5Csum_%7Bs%20%5Cin%20S%7D%20g_%7Bi%2Cs%2Ct%7D):
Total generator power is equal to the minimum power plus the power from each segment.
- ![E_{b,t} = E_{b,t-1} + \eta_{b}^{\text{chg}} J_{b,t}^{\text{chg}} - \frac{1}{\eta_{b}^{\text{dis}}} J_{b,t}^{\text{dis}}](https://render.githubusercontent.com/render/math?math=E_%7Bb%2Ct%7D%20%3D%20E_%7Bb%2Ct-1%7D%20%2B%20%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bchg%7D%7D%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bchg%7D%7D%20-%20%5Cfrac%7B1%7D%7B%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bdis%7D%7D%7D%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdis%7D%7D):
Conservation of energy for energy storage state-of-charge.
- ![g_{i,t} - g_{i,t-1} \le r_{i}^{\text{up}}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Ct%7D%20-%20g_%7Bi%2Ct-1%7D%20%5Cle%20r_%7Bi%7D%5E%7B%5Ctext%7Bup%7D%7D):
Ramp-up constraint.
- ![g_{i,t} - g_{i,t-1} \ge r_{i}^{\text{down}}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Ct%7D%20-%20g_%7Bi%2Ct-1%7D%20%5Cge%20r_%7Bi%7D%5E%7B%5Ctext%7Bdown%7D%7D):
Ramp-down constraint.
- ![- ( f_{l}^{\text{max}} + v_{l,t} ) \le f_{l,t} \le ( f_{l}^{\text{max}} + v_{l,t} )](https://render.githubusercontent.com/render/math?math=-%20%28%20f_%7Bl%7D%5E%7B%5Ctext%7Bmax%7D%7D%20%2B%20v_%7Bl%2Ct%7D%20%29%20%5Cle%20f_%7Bl%2Ct%7D%20%5Cle%20%28%20f_%7Bl%7D%5E%7B%5Ctext%7Bmax%7D%7D%20%2B%20v_%7Bl%2Ct%7D%20%29):
Power flow over each branch is limited by the branch power limit, and can only exceed this value by using the 'violation' variable (if enabled), which is penalized in the objective function.
- ![f_{l,t} = \frac{1}{x_{l}} \sum_{b \in B} m_{l,b}^{\text{line}} \theta_{b,t}](https://render.githubusercontent.com/render/math?math=f_%7Bl%2Ct%7D%20%3D%20%5Cfrac%7B1%7D%7Bx_%7Bl%7D%7D%20%5Csum_%7Bb%20%5Cin%20B%7D%20m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20%5Ctheta_%7Bb%2Ct%7D):
Power flow over each branch is proportional to the admittance and the angle difference.
- ![0 \le \delta_{b,t}^{\text{down}} \le \underline{\delta_{b,t}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdown%7D%7D%20%5Cle%20%5Cunderline%7B%5Cdelta%7D_%7Bb%2Ct%7D):
Bound on the amount of demand that flexible demand resources can curtail.
- ![0 \le \delta_{b,t}^{\text{up}} \le \overline{\delta_{b,t}}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20%5Cdelta_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bup%7D%7D%20%5Cle%20%5Coverline%7B%5Cdelta%7D_%7Bb%2Ct%7D):
Bound on the amount of demand that flexible demand resources can add.
- ![\sum_{t = k}^{k + \Delta^{\text{balance}}} \delta_{b,t}^{\text{up}} - \delta_{b,t}^{\text{down}} \ge 0, \quad \forall b \in B, \quad k = 1, ..., |T| - \Delta^{\text{balance}}](https://render.githubusercontent.com/render/math?math=\sum_{t%20=%20k}^{k%20%2B%20\Delta^{\text{balance}}}%20\delta_{b,t}^{\text{up}}%20-%20\delta_{b,t}^{\text{down}}%20\ge%200,%20\quad%20\forall%20b%20\in%20B,%20\quad%20k%20=%201,%20...,%20|T|%20-%20\Delta^{\text{balance}}):
Rolling load balance for flexible demand resources; used to restrict the time that flexible demand resources can deviate from the base demand.
- ![\sum_{t \in T} \delta_{b,t}^{\text{up}} - \delta_{b,t}^{\text{down}} \ge 0, \quad \forall b \in B](https://render.githubusercontent.com/render/math?math=\sum_{t%20\in%20T}%20\delta_{b,t}^{\text{up}}%20-%20\delta_{b,t}^{\text{down}}%20\ge%200,%20\quad%20\forall%20b%20\in%20B):
Interval load balance for flexible demand resources.

### Objective function

![\min \left [ \sum_{t \in T} \sum_{i \in I} [ C_{i}^{\text{min}} + \sum_{s \in S} c_{i,s} g_{i,s,t} ] + p^{\text{s}} \sum_{t \in T} \sum_{b \in B} s_{b,t} + p^{\text{v}} \sum_{t \in T} \sum_{l \in L} v_{l,t} + p^{\text{e}} \sum_{\b \in B} [E_{b,0} - E_{b,|T|}] \right ]](https://render.githubusercontent.com/render/math?math=%5Cmin%20%5Cleft%20%5B%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bi%20%5Cin%20I%7D%20%5B%20C_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D%20%2B%20%5Csum_%7Bs%20%5Cin%20S%7D%20c_%7Bi%2Cs%7D%20g_%7Bi%2Cs%2Ct%7D%20%5D%20%2B%20p%5E%7B%5Ctext%7Bs%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bb%20%5Cin%20B%7D%20s_%7Bb%2Ct%7D%20%2B%20p%5E%7B%5Ctext%7Bv%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bl%20%5Cin%20L%7D%20v_%7Bl%2Ct%7D%20%2B%20p%5E%7B%5Ctext%7Be%7D%7D%20%5Csum_%7B%5Cb%20%5Cin%20B%7D%20%5BE_%7Bb%2C0%7D%20-%20E_%7Bb%2C%7CT%7C%7D%5D%20%5Cright%20%5D)
There are four main components of the objective function:
- ![\sum_{t \in T} \sum_{i \in I} [ C_{i}^{\text{min}} + \sum_{s \in S} c_{i,s} g_{i,s,t} ]](https://render.githubusercontent.com/render/math?math=%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bi%20%5Cin%20I%7D%20%5B%20C_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D%20%2B%20%5Csum_%7Bs%20%5Cin%20S%7D%20c_%7Bi%2Cs%7D%20g_%7Bi%2Cs%2Ct%7D%20%5D):
The cost of operating generators, fixed costs plus variable costs, which can consist of several cost curve segments for each generator.
- ![p^{\text{s}} \sum_{t \in T} \sum_{b \in B} s_{b,t}](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Bs%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bb%20%5Cin%20B%7D%20s_%7Bb%2Ct%7D):
Penalty for load shedding (if load shedding is enabled).
- ![p^{\text{v}} \sum_{t \in T} \sum_{l \in L} v_{l,t}](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Bv%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bl%20%5Cin%20L%7D%20v_%7Bl%2Ct%7D):
Penalty for transmission line limit violations (if transmission violations are enabled).
- ![p^{\text{e}} \sum_{\b \in B} [E_{b,0} - E_{b,|T|}]](https://render.githubusercontent.com/render/math?math=p%5E%7B%5Ctext%7Be%7D%7D%20%5Csum_%7B%5Cb%20%5Cin%20B%7D%20%5BE_%7Bb%2C0%7D%20-%20E_%7Bb%2C%7CT%7C%7D%5D):
Penalty for ending the interval with less stored energy than the start, or reward for ending with more.

[Gurobi]: https://www.gurobi.com
[Gurobi Installation Guide]: https://www.gurobi.com/documentation/quickstart.html
[Gurobi license file]: https://www.gurobi.com/downloads/
[Gurobi Cloud license]: https://cloud.gurobi.com/manager/licenses
[Free licenses for academic use]: https://www.gurobi.com/academia/academic-program-and-licenses/
[Julia]: https://julialang.org/
[Download Julia]: https://julialang.org/downloads/#current_stable_release
[Python]: https://www.python.org/
[Download Python]: https://www.python.org/downloads/release/python-386/
[Docker]: https://docs.docker.com/get-docker/
[Zenodo]: https://zenodo.org/record/3530898

[Gurobi.jl]: https://github.com/JuliaOpt/Gurobi.jl#installation
[Julia Package Manager]: https://julialang.github.io/Pkg.jl/v1/managing-packages/
[JuMP.Model documentation]: https://jump.dev/JuMP.jl/v0.21.1/solvers/#JuMP.Model-Tuple{Any}
[compatible with JuMP]: https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers
