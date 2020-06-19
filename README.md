## Installation

### Julia package

The most reliable way to install this package is by cloning the repo locally,
navigating to the project folder, activating the project, and instantiating it.
This approach will copy install all dependencies in the **exact** version as
they were installed during package development. **Note**: If `Gurobi.jl` is not
already installed in your Julia environment, then its build step will fail if
it cannot find the Gurobi installation folder. To avoid this, you can specify
an environment variable for `GUROBI_HOME`, pointing to the Gurobi
`<installdir>`.
For more information, see https://github.com/JuliaOpt/Gurobi.jl#installation.
To instantiate:

```
pkg> activate .

(REISE) pkg> instantiate
```

Another way is to install the package using the list of dependencies specified
in the `Project.toml` file, which will pull the most recent allowed version of
the dependencies. Currently, this package is known to be compatible with JuMP
v0.20, but not v0.21; this is specified in the `Project.toml` file, but there
may be other packages for which the latest version does not maintain
backward-compatibility.

This package is not registered. Therefore, it must be added to a Julia
environment either directly from github:
```
pkg> add https://github.com/intvenlab/REISE.jl#develop
```
or by cloning the repository locally and then specifying the path to the repo:
```
pkg> add /YOUR_PATH_HERE/REISE.jl#develop
```

Instead of calling `add PACKAGE`, it is also possible to call `dev PACKAGE`,
which will always import the latest version of the code on your local machine.
See the documentation for the Julia package manager for more information:
https://julialang.github.io/Pkg.jl/v1/.

### Associated python scripts

The dependencies of the python scripts contained in `pyreisejl/` are not
automatically installed. See `requirements.txt` for details.

### Other tools

Text file manipulation requires GNU `awk`, also known as `gawk`.

## Usage

Installation registers a package named `REISE`. Following Julia naming
conventions, the `.jl` is dropped. The package can be imported using:
`import REISE` to call `REISE.run_scenario()`, or `using REISE` to call
`run_scenario()`.

To run a scenario which starts at the `1`st hour of the year, runs in `3`
intervals of `24` hours each, loading input data from your present working
directory (`pwd()`) and depositing results in the folder `output`, call:
```
REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, outputfolder="output",
    inputfolder=pwd())
```
An optional keyword argument `num_segments` controls the linearization of cost
curves into piecewise-linear segments (default is 1). For example:
```
REISE.run_scenario(;
    interval=24, n_interval=3, start_index=1, outputfolder="output",
    inputfolder=pwd(), num_segments=3)
```

## Package Structure

`REISE.jl` contains only imports and includes. Individual type and function
definitions are all in the other files in the `src` folder.

## Formulation

[comment]: # (LaTeX via https://alexanderrodin.com/github-latex-markdown/)

### Sets

- ![B](https://render.githubusercontent.com/render/math?math=B): 
Set of buses, indexed by
![b](https://render.githubusercontent.com/render/math?math=b)
- ![I](https://render.githubusercontent.com/render/math?math=I): 
Set of generators, indexed by
![i](https://render.githubusercontent.com/render/math?math=i)
- ![L](https://render.githubusercontent.com/render/math?math=L): 
Set of transmission network branches, indexed by
![l](https://render.githubusercontent.com/render/math?math=l)
- ![S](https://render.githubusercontent.com/render/math?math=S): 
Set of generation cost curve segments, indexed by
![s](https://render.githubusercontent.com/render/math?math=s)
- ![T](https://render.githubusercontent.com/render/math?math=T): 
Set of time periods, indexed by
![t](https://render.githubusercontent.com/render/math?math=t)

### Variables

storage charge, discharge, soc

- ![f_{l,t}](https://render.githubusercontent.com/render/math?math=f_%7Bl%2Ct%7D):
Power flowing on branch ![l](https://render.githubusercontent.com/render/math?math=l)
at time at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,t}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Ct%7D): 
Power injected by each generator ![i](https://render.githubusercontent.com/render/math?math=i)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,s,t}](https://render.githubusercontent.com/render/math?math=g_%7Bi%2Cs%2Ct%7D):
Power injected by each generator ![i](https://render.githubusercontent.com/render/math?math=i)
from cost curve segment ![s](https://render.githubusercontent.com/render/math?math=s)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![s_{b,t}] (https://render.githubusercontent.com/render/math?math=s_%7Bb%2Ct%7D):
Load shed at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![v_{l,t}](https://render.githubusercontent.com/render/math?math=v_%7Bl%2Ct%7D):
Branch limit violation for branch ![l](https://render.githubusercontent.com/render/math?math=l)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![{\theta}_{b,t}](https://render.githubusercontent.com/render/math?math=%7B%5Ctheta%7D_%7Bb%2Ct%7D):
Voltage angle of bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time at time ![t](https://render.githubusercontent.com/render/math?math=t).

### Parameters

generator pmin, cost at pmin

- ![a^{\text{shed}}](https://render.githubusercontent.com/render/math?math=a%5E%7B%5Ctext%7Bshed%7D%7D):
Binary parameter, whether load shedding is enabled.
- ![a^{\text{viol}}](https://render.githubusercontent.com/render/math?math=a%5E%7B%5Ctext%7Bviol%7D%7D):
Binary parameter, whether transmission limit violation is enabled.
- ![d_{b,t}](https://render.githubusercontent.com/render/math?math=d_%7Bb%2Ct%7D):
Power demand at bus ![b](https://render.githubusercontent.com/render/math?math=b)
at time at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![g_{i,s,t}^{\text{max}}](https://render.githubusercontent.com/render/math?math=g%5E%7B%5Ctext%7Bmax%7D%7D_%7Bi%2Cs%2Ct%7D):
Generator cost curve segment width.
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
- ![w_{i,t}](https://render.githubusercontent.com/render/math?math=w_%7Bi%2Ct%7D):
Power available from time-varying generator (hydro, wind, solar) ![i](https://render.githubusercontent.com/render/math?math=i)
at time ![t](https://render.githubusercontent.com/render/math?math=t).
- ![x_{l}](https://render.githubusercontent.com/render/math?math=x_%7Bl%7D):
Impedance of branch ![l](https://render.githubusercontent.com/render/math?math=l).

### Constraints

- ![0 \le g_{i,s,t} \le g_{i,s,t}^{\text{max}}](https://render.githubusercontent.com/render/math?math=0%5Cle%20g_%7Bi%2Cs%2Ct%7D%5Cle%20g%5E%7B%5Ctext%7Bmax%7D%7D_%7Bi%2Cs%2Ct%7D):
generator segment power is non-negative and less than the segment width.
- ![0 \le s_{b,t} \le a^{\text{shed}} \cdot d_{b,t}](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20s_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20d_%7Bb%2Ct%7D):
load shed is non-negative and less than the demand at that bus, if load shedding is enabled.
If not, load shed is fixed to 0.
- ![0 \le v_{b,t} \le a^{\text{viol}} \cdot M](https://render.githubusercontent.com/render/math?math=0%20%5Cle%20v_%7Bb%2Ct%7D%20%5Cle%20a%5E%7B%5Ctext%7Bshed%7D%7D%20%5Ccdot%20M):
transmission violations are non-negative, if they are enabled.
If not, they are fixed to zero.
charge bounds
discharge bounds
state of charge bounds

powerbalance
storage soc tracking
ramp up
ramp down
segment addition
branch flow max
branch flow min
branch angle constraint
hydro fixed
solar max
wind max

### Objective function
