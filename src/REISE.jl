module REISE

import CSV
import DataFrames
import Dates
import JuMP
import MAT
import Requires
import SparseArrays: sparse, SparseMatrixCSC


include("types.jl")         # Defines Case, Results, Storage, Flexibility,
                            #     VariablesOfInterest
include("read.jl")          # Defines read_case, read_storage, read_demand_flexibility
include("prepare.jl")       # Defines reise_data_mods
include("model.jl")         # Defines _build_model (used in interval_loop)
include("loop.jl")          # Defines interval_loop
include("query.jl")         # Defines get_results (used in interval_loop)
include("save.jl")          # Defines save_input_mat, save_results


function __init__()
    Requires.@require Gurobi="2e9cd046-0924-5485-92f1-d5272153d98b" begin
        include(joinpath("solver_specific", "gurobi.jl"))
    end
end


"""
    REISE.run_scenario(;
        interval=24, n_interval=3, start_index=1, outputfolder="output",
        inputfolder=pwd())

Run a scenario consisting of several intervals.
'interval' specifies the length of each interval in hours.
'n_interval' specifies the number of intervals in a scenario.
'start_index' specifies the starting hour of the first interval, to determine
    which time-series data should be loaded into each intervals.
'inputfolder' specifies where to load the relevant data from. Required files
    are 'case.mat', 'demand.csv', 'hydro.csv', 'solar.csv', and 'wind.csv'.
'outputfolder' specifies where to store the results. Defaults to an `output`
    subdirectory of inputfolder. This folder will be created if it does not exist at
    runtime.
'optimizer_factory' is the solver used for optimization. If not specified, Gurobi is
    used by default.
"""
function run_scenario(;
        num_segments::Int=1, interval::Int, n_interval::Int, start_index::Int,
        inputfolder::String, outputfolder::Union{String, Nothing}=nothing,
        threads::Union{Int, Nothing}=nothing, optimizer_factory=nothing,
        solver_kwargs::Union{Dict, Nothing}=nothing)
    isnothing(optimizer_factory) && error("optimizer_factory must be specified")
    # Setup things that build once
    # If no solver kwargs passed, instantiate an empty dict
    solver_kwargs = something(solver_kwargs, Dict())
    # If outputfolder not given, by default assign it inside inputfolder
    isnothing(outputfolder) && (outputfolder = joinpath(inputfolder, "output"))
    # If outputfolder doesn't exist (isdir evaluates false) create it (mkdir)
    isdir(outputfolder) || mkdir(outputfolder)
    stdout_filepath = joinpath(outputfolder, "stdout.log")
    stderr_filepath = joinpath(outputfolder, "stderr.err")
    case = read_case(inputfolder)
    storage = read_storage(inputfolder)
    flexibility = read_demand_flexibility(inputfolder)
    println("All scenario files loaded!")
    
    save_input_mat(case, storage, flexibility, inputfolder, outputfolder)
    model_kwargs = Dict(
        "case" => case,
        "storage" => storage,
        "flexibility" => flexibility,
        "interval_length" => interval,
        )
    # If a number of threads is specified, add to solver settings dict
    isnothing(threads) || (solver_kwargs["Threads"] = threads)
    println("All preparation complete!")
    # While redirecting stdout and stderr...
    println("Redirecting outputs, see stdout.log & stderr.err in outputfolder")
    redirect_stdout_stderr(stdout_filepath, stderr_filepath) do
        # Loop through intervals
        m = interval_loop(optimizer_factory, model_kwargs, solver_kwargs, interval,
                          n_interval, start_index, inputfolder, outputfolder)
    end
    return m
end

# Module end
end
