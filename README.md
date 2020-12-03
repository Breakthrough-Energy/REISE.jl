 # REISE.jl
Renewable Energy Integration Simulation Engine.

This repository contains, in the **src** folder, the Julia scripts to run the power-flow study in the U.S. electric grid. The simulation engine relies on [Gurobi] as the optimization solver.

## Dependencies
This package requires installations of the following
- [Julia]
- [Gurobi]
- [Python]

For sample data to use with the simulation, please visit [Zenodo].


## Installation
### Julia package
The most reliable way to install this package is by cloning the repo locally, navigating to the project folder, activating the project, and instantiating it. This approach will copy install all dependencies in the **exact** version as they were installed during package development. **Note**: if `Gurobi.jl` is not already installed in your Julia environment, then its build step will fail if it cannot find the Gurobi installation folder. To avoid this, you can specify an environment variable for `GUROBI_HOME`, pointing to the Gurobi `<installdir>`.

For more information, see https://github.com/JuliaOpt/Gurobi.jl#installation.

To instantiate:
```julia
pkg> activate .

(REISE) pkg> instantiate
```
Another way is to install the package using the list of dependencies specified in the `Project.toml` file, which will pull the most recent allowed version of the dependencies. Currently, this package is known to be compatible with JuMP v0.21.3; this is specified in the `Project.toml` file, but there may be other packages for which the latest version does not maintain backward-compatibility.

This package is not registered. Therefore, it must be added to a Julia environment either directly from GitHub:
```julia
pkg> add https://github.com/Breakthrough-Energy/REISE.jl#develop
```
or by cloning the repository locally and then specifying the path to the repo:
```julia
pkg> add /YOUR_PATH_HERE/REISE.jl#develop
```
Instead of calling `add PACKAGE`, it is also possible to call `dev PACKAGE`, which will always import the latest version of the code on your local machine. See the documentation for the Julia package manager for more information: https://julialang.github.io/Pkg.jl/v1/.


### Associated python scripts
The dependencies of the python scripts contained in `pyreisejl` are not
automatically installed. See `requirements.txt` for details. These requirements
can be installed using pip:
```bash
pip install -r requirements.txt
```




## Usage (Julia)
Installation registers a package named `REISE`. Following Julia naming conventions, the `.jl` is dropped. The package can be imported using: `import REISE` to call `REISE.run_scenario()`, or `using REISE` to call `run_scenario()`.

To run a scenario which starts at the `1`st hour of the year, runs in `3` intervals of `24` hours each, loading input data from your present working directory (`pwd()`) and depositing results in the folder `output`, call:
```julia
REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, outputfolder="output",
    inputfolder=pwd())
```
An optional keyword argument `num_segments` controls the linearization of cost curves into piecewise-linear segments (default is 1). For example:
```julia
REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, outputfolder="output",
    inputfolder=pwd(), num_segments=3)
```

## Usage (Python)

The python scripts included in `pyreisejl` perform some additional input validation for the Julia engine before running the simulation and extract data from  the resulting `.mat` files to `.pkl` files.

There are two main python scripts included in `pyreisejl`:
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

To run the `REISE.jl` simulation from python, run `call.py` with the following required options:
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


This python script will validate some of the inputs and translate them into the
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

If the simulation was run with the necessary input data, the following will
also be extracted:

* PF_DCLINE.pkl (power flow on DC lines)
* STORAGE_PG.pkl (power generated by storage units)
* STORAGE_E.pkl (energy state of charge)
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

Within the python code in this repo, there is some code to maintain
compatibility with the `PowerSimData` framework.

Both `call.py` and `extract_data.py` can be called using a positional
argument that corresponds to a scenario id as generated by the
`PowerSimData` framework. Using this invocation assumes the presence
of the `PowerSimData` infrastructure including both a Scenario List
Manager and Execute List Manager. This option is not intended for manual
simulation runs.

Note also the different naming convention for various directories by
`PowerSimData` as compared to the options for the python scripts within
this repository.

## Docker

The easiest way to setup this engine is within a Docker image. There is an
included `Dockerfile` that can be used to build the Docker image. With the
Docker daemon installed and running, navigate to the `REISE.jl` folder
containing the `Dockerfile` and build the image:

```
docker build . -t reisejl
```

To run the Docker image, you will need to mount two volumes; one containing the
`Gurobi` license file and another containing the necessary input files for the
engine. 

```
docker run -i -v /LOCAL/PATH/TO/GUROBI.LIC:/usr/share/gurobi_license -v /LOCAL/PATH/TO/DATA:/usr/share/data reisejl
```

Once the container is running, you can run a simulation using the `python`
commands described above. For example:

```
python pyreisejl/utility/call.py -s '2016-01-01' -e '2016-01-07' -int 24 -i '/usr/share/data'
```

Note that loading the `REISE.jl` package can take up to a couple of minutes,
so there may not be any output in this time.


## Package Structure
`REISE.jl` contains only imports and includes. Individual type and function definitions are all in the other files in the `src` folder.


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
- ![\eta_{b}^{\text{chg}}](https://render.githubusercontent.com/render/math?math=%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bchg%7D%7D):
Charging efficiency of storage device at bus ![b](https://render.githubusercontent.com/render/math?math=b).
- ![\eta_{b}^{\text{dis}}](https://render.githubusercontent.com/render/math?math=%5Ceta_%7Bb%7D%5E%7B%5Ctext%7Bdis%7D%7D):
Discharging efficiency of storage device at bus ![b](https://render.githubusercontent.com/render/math?math=b).


### Constraints

All equations apply over all entries in the indexed sets unless otherwise listed.

- ![0 \le g_{i,s,t} \le g_{i,s,t}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%5Cle%20g_%7Bi%2Cs%2Ct%7D%5Cle%20g%5E%7B%5Ctext%7Bmax%7D%7D_%7Bi%2Cs%2Ct%7D):
generator segment power is non-negative and less than the segment width.
- ![0 \le s_{b,t} \le a^{\text{shed}} \cdot d_{b,t}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20s_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20d_%7Bb%2Ct%7D):
load shed is non-negative and less than the demand at that bus, if load shedding is enabled.
If not, load shed is fixed to 0.
- ![0 \le v_{b,t} \le a^{\text{viol}} \cdot M](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20v_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20M):
transmission violations are non-negative, if they are enabled
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

- ![\sum_{i \in I} m_{i,b}^{\text{unit}} g_{i,t} + \sum_{l \in L} m_{l,b}^{\text{line}} f_{l,t} + J_{b,t}^{\text{dis}} + s_{b,t} = d_{b,t} + J_{b,t}^{\text{chg}}](https://render.githubusercontent.com/render/math?math=%5Csum_%7Bi%20%5Cin%20I%7D%20m_%7Bi%2Cb%7D%5E%7B%5Ctext%7Bunit%7D%7D%20g_%7Bi%2Ct%7D%20%2B%20%5Csum_%7Bl%20%5Cin%20L%7D%20m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20f_%7Bl%2Ct%7D%20%2B%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bdis%7D%7D%20%2B%20s_%7Bb%2Ct%7D%20%3D%20d_%7Bb%2Ct%7D%20%2B%20J_%7Bb%2Ct%7D%5E%7B%5Ctext%7Bchg%7D%7D):
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
[Download Gurobi]: https://www.gurobi.com/downloads/gurobi-optimizer-eula/
[Gurobi Installation Guide]: https://www.gurobi.com/documentation/quickstart.html
[Julia]: https://julialang.org/
[Download Julia]: https://julialang.org/downloads/
[Zenodo]: https://zenodo.org/record/3530898
[Python]: https://www.python.org/