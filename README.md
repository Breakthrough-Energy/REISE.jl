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
