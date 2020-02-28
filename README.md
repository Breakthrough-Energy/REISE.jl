## Usage

Currently, all core code functionality is located in `src/REISE.jl`. This code
defines the module `REISE`, which can be added via
```
pkg> add add https://github.com/intvenlab/REISE.jl#develop
```
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