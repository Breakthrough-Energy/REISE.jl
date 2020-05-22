module REISE

import CSV
import DataFrames
import Dates
import JuMP
import Gurobi
import MAT
import SparseArrays: sparse, SparseMatrixCSC


include("types.jl")         # Defines Case, Results, Storage,
                            #     VariablesOfInterest
include("read.jl")          # Defines read_case, read_storage
include("prepare.jl")       # Defines reise_data_mods
include("model.jl")         # Defines _build_model (used in interval_loop)
include("loop.jl")          # Defines interval_loop
include("query.jl")         # Defines get_results (used in interval_loop)
include("save.jl")          # Defines save_input_mat, save_results


"""
    REISE.run_scenario(;
        interval=24, n_interval=3, start_index=1, outputfolder="output",
        inputfolder=pwd())

Run a scenario consisting of several intervals.
'interval' specifies the length of each interval in hours.
'n_interval' specifies the number of intervals in a scenario.
'start_index' specifies the starting hour of the first interval, to determine
    which time-series data should be loaded into each intervals.
'outputfolder' specifies where to store the results. This folder will be
    created if it does not exist at runtime.
'inputfolder' specifies where to load the relevant data from. Required files
    are 'case.mat', 'demand.csv', 'hydro.csv', 'solar.csv', and 'wind.csv'.
"""
function run_scenario(;
        num_segments::Int=1, interval::Int, n_interval::Int, start_index::Int,
        inputfolder::String, outputfolder::String)
    # Setup things that build once
    # If outputfolder doesn't exist (isdir evaluates false) create it (mkdir)
    isdir(outputfolder) || mkdir(outputfolder)
    env = Gurobi.Env()
    case = read_case(inputfolder)
    storage = read_storage(inputfolder)
    println("All scenario files loaded!")
    case = reise_data_mods(case, num_segments=num_segments)
    save_input_mat(case, storage, inputfolder, outputfolder)
    model_kwargs = Dict(
        "case" => case,
        "storage" => storage,
        "interval_length" => interval,
        )
    solver_kwargs = Dict("Method" => 2, "Crossover" => 0)
    # Then loop through intervals
    interval_loop(env, model_kwargs, solver_kwargs, interval, n_interval,
                  start_index, inputfolder, outputfolder)
    GC.gc()
    Gurobi.free_env(env)
    println("Connection closed successfully!")
end

# Module end
end
