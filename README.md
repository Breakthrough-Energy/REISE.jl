## Usage

This code defines the package `REISE`, which can be added to a Julia
environment via
```
pkg> add https://github.com/intvenlab/REISE.jl#develop
```

Then, import the package: `import REISE`.

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
