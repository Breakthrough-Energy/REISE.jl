function interval_loop(env::Gurobi.Env, model_kwargs::Dict,
                       solver_kwargs::Dict, interval::Int,
                       n_interval::Int, start_index::Int,
                       inputfolder::String, outputfolder::String)
    # Bad (but known) statuses to match against
    bad_statuses = (
        JuMP.MOI.INFEASIBLE, JuMP.MOI.INFEASIBLE_OR_UNBOUNDED,
        JuMP.MOI.NUMERICAL_ERROR, JuMP.MOI.OTHER_LIMIT,
        )
    # Constant parameters
    case = model_kwargs["case"]
    num_storage = size(model_kwargs["storage"].gen, 1)
    num_bus = length(case.busid)
    load_bus_idx = findall(case.bus_demand .> 0)
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    gen_wind_idx = gen_idx[findall(
        (case.genfuel .== "wind") .| (case.genfuel .== "wind_offshore"))]
    gen_solar_idx = gen_idx[findall(case.genfuel .== "solar")]
    gen_hydro_idx = gen_idx[findall(case.genfuel .== "hydro")]
    num_wind = length(gen_wind_idx)
    num_solar = length(gen_solar_idx)
    num_hydro = length(gen_hydro_idx)
    storage_enabled = (num_storage > 0)
    # Start looping
    for i in 1:n_interval
        # These must be declared global so that they persist through the loop.
        global m, voi, pg0, storage_e0
        model_kwargs["demand_scaling"] = 1.0
        interval_start = start_index + (i - 1) * interval
        interval_end = interval_start + interval - 1
        model_kwargs["start_index"] = interval_start
        if i == 1
            # Build a model with no initial ramp constraint
            m_kwargs = (; (Symbol(k) => v for (k,v) in model_kwargs)...)
            s_kwargs = (; (Symbol(k) => v for (k,v) in solver_kwargs)...)
            m = JuMP.direct_model(Gurobi.Optimizer(env; s_kwargs...))
            m, voi = _build_model(m; m_kwargs...)
            if storage_enabled
                model_kwargs["storage_e0"] = storage.sd_table.InitialStorage
            end
        elseif i == 2
            # Build a model with an initial ramp constraint
            model_kwargs["initial_ramp_enabled"] = true
            model_kwargs["initial_ramp_g0"] = pg0
            m_kwargs = (; (Symbol(k) => v for (k,v) in model_kwargs)...)
            s_kwargs = (; (Symbol(k) => v for (k,v) in solver_kwargs)...)
            m = JuMP.direct_model(Gurobi.Optimizer(env; s_kwargs...))
            m, voi = _build_model(m; m_kwargs...)
        else
            # Reassign right-hand-side of constraints to match profiles
            bus_demand = _make_bus_demand(case, interval_start, interval_end)
            simulation_hydro = permutedims(Matrix(
                case.hydro[interval_start:interval_end, 2:end]))
            simulation_solar = permutedims(Matrix(
                case.solar[interval_start:interval_end, 2:end]))
            simulation_wind = permutedims(Matrix(
                case.wind[interval_start:interval_end, 2:end]))
            for t in 1:interval, b in load_bus_idx
                JuMP.set_normalized_rhs(
                    voi.powerbalance[b, t], bus_demand[b, t])
            end
            for t in 1:interval, i in 1:length(load_bus_idx)
                JuMP.set_upper_bound(
                    voi.load_shed[i, t], bus_demand[load_bus_idx[i], t])
            end
            for t in 1:interval, g in 1:num_hydro
                JuMP.set_normalized_rhs(
                    voi.hydro_fixed[g, t], simulation_hydro[g, t])
            end
            for t in 1:interval, g in 1:num_solar
                JuMP.set_normalized_rhs(
                    voi.solar_max[g, t], simulation_solar[g, t])
            end
            for t in 1:interval, g in 1:num_wind
                JuMP.set_normalized_rhs(
                    voi.wind_max[g, t], simulation_wind[g, t])
            end
            # Re-assign right-hand-side for initial conditions
            noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
            for g in noninf_ramp_idx
                rhs = case.gen_ramp30[g] * 2 + pg0[g]
                JuMP.set_normalized_rhs(voi.initial_rampup[g], rhs)
                rhs = case.gen_ramp30[g] * 2 - pg0[g]
                JuMP.set_normalized_rhs(voi.initial_rampdown[g], rhs)
            end
            if storage_enabled
                for s in 1:num_storage
                    JuMP.set_normalized_rhs(voi.initial_soc[s], storage_e0[s])
                end
            end
        end

        # The demand_scaling decrement should only be triggered w/o load_shed
        while true
            global results
            JuMP.optimize!(m)
            status = JuMP.termination_status(m)
                if status == JuMP.MOI.OPTIMAL
                f = JuMP.objective_value(m)
                results = get_results(f, voi, model_kwargs["case"])
                break
            elseif status in bad_statuses
                model_kwargs["demand_scaling"] -= 0.05
                if model_kwargs["demand_scaling"] < 0
                    error("Too many demand reductions, demand is at zero!")
                end
                println("Optimization failed, Reducing demand: "
                        * string(model_kwargs["demand_scaling"]))
            else
                @show status
                error("Unknown status code!")
            end
        end
        
        # Save initial conditions for next interval
        pg0 = results.pg[:,end]
        if storage_enabled
            storage_e0 = results.storage_e[:,end]
        end
        
        # Save results
        results_filename = "result_" * string(i-1) * ".mat"
        results_filepath = joinpath(outputfolder, results_filename)
        save_results(results, results_filepath;
                     demand_scaling=model_kwargs["demand_scaling"])
    end
end
