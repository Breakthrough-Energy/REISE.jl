## Installation

This package is not registered. Therefore, it must be added to a Julia
environment either directly from github:
```
pkg> add https://github.com/intvenlab/REISE.jl#develop
```
or by cloning the repository locally and then specifying the path to the repo:
```
pkg> add /YOUR_PATH_HERE/REISE.jl#develop
```

The dependencies of the python scripts contained in `pyreisejl/` are not
automatically installed. See `requirements.txt` for details.

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
