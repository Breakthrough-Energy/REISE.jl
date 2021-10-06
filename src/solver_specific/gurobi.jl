# Importing Gurobi in this way avoids a warning with Requires
using .Gurobi: Gurobi

function run_scenario_gurobi(; solver_kwargs::Union{Dict,Nothing}=nothing, kwargs...)
    solver_kwargs = something(solver_kwargs, Dict("Method" => 2, "Crossover" => 0))
    try
        global env = Gurobi.Env()
    catch e
        println("Error encountered starting Gurobi.")
        throw(e)
    end
    try
        global m = run_scenario(;
            optimizer_factory=env, solver_kwargs=solver_kwargs, kwargs...
        )
    finally
        Gurobi.finalize(JuMP.backend(m))
        Gurobi.finalize(env)
        println("Connection to Gurobi closed successfully!")
    end
    # Return `nothing` to prevent `m` from the `try` block from being returned
    return nothing
end

function new_model(env::Gurobi.Env)
    return JuMP.direct_model(Gurobi.Optimizer(env))
end
