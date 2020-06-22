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
Maximum flow over line ![l](https://render.githubusercontent.com/render/math?math=l)
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
transmission violations are non-negative, if they are enabled.
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
- ![-f_{l}^{\text{max}} \le f_{l,t} \le f_{l}^{\text{max}}](https://render.githubusercontent.com/render/math?math=-f_%7Bl%7D%5E%7B%5Ctext%7Bmax%7D%7D%20%5Cle%20f_%7Bl%2Ct%7D%20%5Cle%20f_%7Bl%7D%5E%7B%5Ctext%7Bmax%7D%7D):
Power flow over each branch is limited by the branch power limit.
- ![f_{l,t} = \frac{1}{x_{l}} \sum_{b \in B} m_{l,b}^{\text{line}} \theta_{b,t}](https://render.githubusercontent.com/render/math?math=f_%7Bl%2Ct%7D%20%3D%20%5Cfrac%7B1%7D%7Bx_%7Bl%7D%7D%20%5Csum_%7Bb%20%5Cin%20B%7D%20m_%7Bl%2Cb%7D%5E%7B%5Ctext%7Bline%7D%7D%20%5Ctheta_%7Bb%2Ct%7D):
Power flow over each branch is proportional to the admittance and the angle difference.

### Objective function

![\sum_{t \in T} \sum_{i \in I} [ C_{i}^{\text{min}} + \sum_{s \in S} c_{i,s} g_{i,s,t} ] + p^{\text{s}} \sum_{t \in T} \sum_{b \in B} s_{b,t} + p^{\text{v}} \sum_{t \in T} \sum_{l \in L} v_{l,t} + p^{\text{e}} \sum_{\b \in B} [E_{b,0} - E_{b,|T|}]](https://render.githubusercontent.com/render/math?math=%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bi%20%5Cin%20I%7D%20%5B%20C_%7Bi%7D%5E%7B%5Ctext%7Bmin%7D%7D%20%2B%20%5Csum_%7Bs%20%5Cin%20S%7D%20c_%7Bi%2Cs%7D%20g_%7Bi%2Cs%2Ct%7D%20%5D%20%2B%20p%5E%7B%5Ctext%7Bs%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bb%20%5Cin%20B%7D%20s_%7Bb%2Ct%7D%20%2B%20p%5E%7B%5Ctext%7Bv%7D%7D%20%5Csum_%7Bt%20%5Cin%20T%7D%20%5Csum_%7Bl%20%5Cin%20L%7D%20v_%7Bl%2Ct%7D%20%2B%20p%5E%7B%5Ctext%7Be%7D%7D%20%5Csum_%7B%5Cb%20%5Cin%20B%7D%20%5BE_%7Bb%2C0%7D%20-%20E_%7Bb%2C%7CT%7C%7D%5D)
