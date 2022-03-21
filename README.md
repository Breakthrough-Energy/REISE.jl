![logo](https://raw.githubusercontent.com/Breakthrough-Energy/docs/master/source/_static/img/BE_Sciences_RGB_Horizontal_Color.svg)


[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![Documentation](https://github.com/Breakthrough-Energy/docs/actions/workflows/publish.yml/badge.svg)](https://breakthrough-energy.github.io/docs/)
![GitHub contributors](https://img.shields.io/github/contributors/Breakthrough-Energy/REISE.jl?logo=GitHub)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/Breakthrough-Energy/REISE.jl?logo=GitHub)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/Breakthrough-Energy/REISE.jl/develop?logo=GitHub)
![GitHub pull requests](https://img.shields.io/github/issues-pr/Breakthrough-Energy/REISE.jl?logo=GitHub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code of Conduct](https://img.shields.io/badge/code%20of-conduct-ff69b4.svg?style=flat)](https://breakthrough-energy.github.io/docs/communication/code_of_conduct.html)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.4538590.svg)](https://doi.org/10.5281/zenodo.4538590)


# REISE.jl
**REISE.jl** is the Renewable Energy Simulation Engine developed by [Breakthrough
Energy Sciences](https://science.breakthroughenergy.org/) (BES) to solve DC optimal
power flow problems. It is written in Julia and can be used with the BES software
ecosystem (see [PowerSimData]) or in a standalone mode (see [Zenodo] for sample data).


## Main Features
Here are a few things that **REISE.jl** can do:
* Formulate a Production Cost Model (PCM) into an optimization problem that can be
  solved by professional solvers compatible with [JuMP]
* Decompose a model that cannot be solved all at once in memory (due to high spatial
  or temporal resolution or both) into a series of shorter-timeframe intervals that are
  automatically run sequentially.
* Model operational decisions by energy storage and price-responsive flexible demand
  alongside those made by thermal and renewable generators
* Handle adaptive infeasible/suboptimal/numeric issues via the homogenous barrier
  algorithm (when using the [Gurobi] solver) and involuntary load shedding


## Where to get it
For now, only the source code is available. Clone or Fork the code here on GitHub.


## Dependencies
**REISE.jl** relies on several Julia packages. The list can be found in the
***Project.toml*** file located at the root of this package.

This program builds an optimization problem, but still relies on an external solver to
generate results. Any solver compatible with [JuMP] can be used, although performance
with open-source solvers (e.g. Clp, GLPK) may be significantly slower than with
commercial solvers.

## Installation
There are two options, either install all the dependencies yourself or setup the engine
within a Docker image. Detailed installation notes can be found [here][docs]. You will
also find in this document instructions to use **REISE.jl** in the standalone mode or
in combination with **PowerSimData**.


## License
[MIT](LICENSE)


## Communication Channels
[Sign up](https://science.breakthroughenergy.org/#get-updates) to our email list and
our Slack workspace to get in touch with us.


## Contributing
All contributions (bug report, documentation, feature development, etc.) are welcome. An
overview on how to contribute to this project can be found in our [Contribution
Guide](https://breakthrough-energy.github.io/docs/dev/contribution_guide.html).

This package is formatted following the Blue Style conventions. Pull requests will be
automatically checked against consistency to this style guide. Formatting is as easy as:
```julia
julia> using JuliaFormatter

julia> format(FILE_OR_DIRECTORY)
```
If an individual file is passed, that file will be formatted. If a directory is passed,
all Julia files in that directory and subdirectories will be formatted. Use
`format(".")` from the root of the package to format all files.



[PowerSimData]: https://github.com/Breakthrough-Energy/PowerSimData
[Gurobi]: https://www.gurobi.com/
[docs]: https://breakthrough-energy.github.io/docs/reisejl/index.html
[Jump]: https://jump.dev/
[Zenodod]: https://doi.org/10.5281/zenodo.4538590
