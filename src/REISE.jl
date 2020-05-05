module REISE

import CSV
import DataFrames
import Dates
import JuMP
import Gurobi
import MAT
import SparseArrays: sparse, SparseMatrixCSC


include("types.jl")         # Defines Case, Results, Storage
include("read.jl")          # Defines read_case, read_storage
include("prepare.jl")       # Defines reise_data_mods
include("model.jl")         # Defines build_and_solve
include("query.jl")         # Defines get_results (used in build_and_solve)
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
    storage_enabled = (size(storage.gen, 1) > 0)
    case = reise_data_mods(case, num_segments=num_segments)
    save_input_mat(case, storage, inputfolder, outputfolder)
    model_kwargs = Dict(
        "case" => case,
        "storage" => storage,
        "interval_length" => interval,
        )
    pg0 = Array{Float64}(undef, length(case.genid))
    solver_kwargs = Dict("Method" => 2, "Crossover" => 0)
    s_kwargs = (; (Symbol(k) => v for (k,v) in solver_kwargs)...)
    # Then loop through intervals
    for i in 1:n_interval
        # Define appropriate settings for this interval
        model_kwargs["demand_scaling"] = 1.0
        model_kwargs["start_index"] = start_index + (i - 1) * interval
        if storage_enabled & i == 1
            model_kwargs["storage_e0"] = storage.sd_table.InitialStorage
        end
        if i > 1
            model_kwargs["initial_ramp_enabled"] = true
            model_kwargs["initial_ramp_g0"] = pg0
        end
        m_kwargs = (; (Symbol(k) => v for (k,v) in model_kwargs)...)
        # Actually build the model, solve it, get results
        results = build_and_solve(model_kwargs, solver_kwargs, env)
        # Then save them
        results_filename = "result_" * string(i-1) * ".mat"
        results_filepath = joinpath(outputfolder, results_filename)
        save_results(results, results_filepath;
                     demand_scaling=model_kwargs["demand_scaling"])
        pg0 = results.pg[:,end]
        if storage_enabled
            storage_e0 = results.storage_e[:,end]
        end
    end
    GC.gc()
    Gurobi.free_env(env)
    println("Connection closed successfully!")
end

# Module end
end
