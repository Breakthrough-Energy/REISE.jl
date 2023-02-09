"""Convert a dict with string keys to a NamedTuple, for python-eqsue kwargs splatting"""
function symbolize(d::Dict{String,Any})::NamedTuple
    return (; (Symbol(k) => v for (k, v) in d)...)
end

function new_model(optimizer_factory)::JuMP.Model
    return JuMP.Model(optimizer_factory)
end

"""
    interval_loop(factory_like, model_kwargs, solver_kwargs, interval, n_interval,
                  start_index, outputfolder)

Given:
- optimizer instantiation object `factory_like`:
    something that can be passed to new_model (goes to JuMP.Model by default)
- a dictionary of model keyword arguments `model_kwargs`
- a dictionary of solver keyword arguments `solver_kwargs`
- an interval length `interval` (hours)
- a number of intervals `n_interval`
- a starting index position `start_index`
- a folder path to write output files to `outputfolder`

Build a model, and run through the intervals, re-building the model and/or
re-setting constraint right-hand-side values as necessary.
"""
function interval_loop(
    factory_like,
    model_kwargs::Dict,
    solver_kwargs::Dict,
    interval::Int,
    n_interval::Int,
    start_index::Int,
    outputfolder::String,
)
    # Bad (but known) statuses to match against
    numeric_statuses = (
        JuMP.MOI.INFEASIBLE_OR_UNBOUNDED, JuMP.MOI.NUMERICAL_ERROR, JuMP.MOI.OTHER_LIMIT
    )
    infeasible_statuses = (JuMP.MOI.INFEASIBLE, JuMP.MOI.INFEASIBLE_OR_UNBOUNDED)
    # Constant parameters
    case = model_kwargs["case"]
    storage = model_kwargs["storage"]
    demand_flexibility = model_kwargs["demand_flexibility"]
    sets = _make_sets(case; storage=storage, demand_flexibility=demand_flexibility)
    unused_load_shed_intervals_turnoff = 14
    # Start looping
    for i in 1:n_interval
        # These must be declared global so that they persist through the loop.
        global m, pg0, storage_e0, init_shifted_demand, intervals_without_loadshed
        @show ("load_shed_enabled" in keys(model_kwargs))
        @show ("BarHomogeneous" in keys(solver_kwargs))
        interval_start = start_index + (i - 1) * interval
        interval_end = interval_start + interval - 1
        model_kwargs["start_index"] = interval_start
        bus_demand = _make_bus_demand(case, interval_start, interval_end)
        if demand_flexibility.enabled
            (bus_demand_flex_amt_up, bus_demand_flex_amt_dn) = _make_bus_demand_flexibility_amount(
                case, demand_flexibility, interval_start, interval_end, bus_demand, sets
            )
        end
        if i == 1
            # Build a model with no initial ramp constraint
            if storage.enabled
                model_kwargs["storage_e0"] = storage.sd_table.InitialStorage
            end
            if demand_flexibility.enabled
                model_kwargs["init_shifted_demand"] = zeros(size(bus_demand_flex_amt_dn, 1))
            end
            m = new_model(factory_like)
            JuMP.set_optimizer_attributes(m, pairs(solver_kwargs)...)
            m = _build_model(m; symbolize(model_kwargs)...)
        elseif i == 2
            # Build a model with an initial ramp constraint
            model_kwargs["initial_ramp_enabled"] = true
            model_kwargs["initial_ramp_g0"] = pg0
            if storage.enabled
                model_kwargs["storage_e0"] = storage_e0
            end
            if demand_flexibility.enabled
                model_kwargs["init_shifted_demand"] = init_shifted_demand
            end
            m = new_model(factory_like)
            JuMP.set_optimizer_attributes(m, pairs(solver_kwargs)...)
            m = _build_model(m; symbolize(model_kwargs)...)
        else
            # Reassign right-hand side of constraints that pertain to demand
            for t in 1:interval, b in sets.load_bus_idx
                JuMP.set_normalized_rhs(m[:powerbalance][b, t], bus_demand[b, t])
            end
            if (
                ("load_shed_enabled" in keys(model_kwargs)) &&
                (model_kwargs["load_shed_enabled"] == true)
            )
                for t in 1:interval, i in 1:length(sets.load_bus_idx)
                    JuMP.set_normalized_rhs(
                        m[:load_shed_ub][i, t], bus_demand[sets.load_bus_idx[i], t]
                    )
                end
            end

            # Reassign right-hand side of constraints that limit profile-based generators
            simulation_profile = Dict()
            for p in keys(case.group_profile_resources)
                simulation_profile[p] = Matrix(
                    getfield(case, Symbol(p))[interval_start:interval_end, 2:end]
                )
            end
            for g in values(sets.profile_resources_num_rep)
                for h in 1:interval
                    for i in 1:length(sets.profile_resources_idx[g])
                        JuMP.set_normalized_rhs(
                            m[:profile_upper_bound][g, i, h],
                            simulation_profile[sets.profile_to_group[g]][h, i],
                        )
                        JuMP.set_normalized_rhs(
                            m[:profile_lower_bound][g, i, h],
                            case.pmin_as_share_of_pmax[g] *
                            simulation_profile[sets.profile_to_group[g]][h, i],
                        )
                    end
                end
            end

            # Reassign right-hand-side for initial conditions
            noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
            for g in noninf_ramp_idx
                JuMP.set_normalized_rhs(
                    m[:initial_rampup][g], case.gen_ramp30[g] * 2 + pg0[g]
                )
                JuMP.set_normalized_rhs(
                    m[:initial_rampdown][g], case.gen_ramp30[g] * 2 - pg0[g]
                )
            end
            if storage.enabled
                for s in 1:(sets.num_storage)
                    JuMP.set_normalized_rhs(m[:initial_soc][s], storage_e0[s])
                end
            end

            # Reassign right-hand side of constraints that pertain to demand flexibility
            if demand_flexibility.enabled
                if !isnothing(demand_flexibility.cost_up)
                    bus_demand_flex_cost_up = permutedims(
                        Matrix(
                            demand_flexibility.cost_up[interval_start:interval_end, 2:end]
                        ),
                    )
                end
                if !isnothing(demand_flexibility.cost_dn)
                    bus_demand_flex_cost_dn = permutedims(
                        Matrix(
                            demand_flexibility.cost_dn[interval_start:interval_end, 2:end]
                        ),
                    )
                end
                for l in 1:(sets.num_flexible_bus)
                    for t in 1:interval
                        JuMP.set_upper_bound(
                            m[:load_shift_up][l, t], bus_demand_flex_amt_up[l, t]
                        )
                        JuMP.set_upper_bound(
                            m[:load_shift_dn][l, t], bus_demand_flex_amt_dn[l, t]
                        )
                        if !isnothing(demand_flexibility.cost_up)
                            JuMP.set_objective_coefficient(
                                m, m[:load_shift_up][l, t], bus_demand_flex_cost_up[l, t]
                            )
                        end
                        if !isnothing(demand_flexibility.cost_dn)
                            JuMP.set_objective_coefficient(
                                m, m[:load_shift_dn][l, t], bus_demand_flex_cost_dn[l, t]
                            )
                        end
                    end
                    if demand_flexibility.rolling_balance
                        JuMP.set_normalized_rhs(
                            m[:rolling_load_balance_first][l], -1 * init_shifted_demand[l]
                        )
                    end
                    if demand_flexibility.interval_balance
                        JuMP.set_normalized_rhs(
                            m[:interval_load_balance][l], -1 * init_shifted_demand[l]
                        )
                    end
                end
            end
        end

        while true
            global results
            # Solve the model, flushing before/after for proper stdout order
            flush(stdout)
            JuMP.optimize!(m)
            flush(stdout)
            status = JuMP.termination_status(m)
            if status == JuMP.MOI.OPTIMAL
                f = JuMP.objective_value(m)
                results = get_results(f, model_kwargs["case"], demand_flexibility)
                break
            elseif (
                (status == JuMP.MOI.LOCALLY_SOLVED) &
                ("load_shed_enabled" in keys(model_kwargs))
            )
                # if load shedding is enabled, we'll accept 'suboptimal'
                f = JuMP.objective_value(m)
                results = get_results(f, model_kwargs["case"], demand_flexibility)
                break
            elseif (
                (status in numeric_statuses) &
                (JuMP.solver_name(m) == "Gurobi") &
                !("BarHomogeneous" in keys(solver_kwargs))
            )
                # if Gurobi, and BarHomogeneous is not enabled, enable it and re-solve
                solver_kwargs["BarHomogeneous"] = 1
                println("enable BarHomogeneous")
                JuMP.set_optimizer_attribute(m, "BarHomogeneous", 1)
            elseif (
                (status in infeasible_statuses) &
                !("load_shed_enabled" in keys(model_kwargs))
            )
                # if load shed not enabled, enable it and re-build the model
                model_kwargs["load_shed_enabled"] = true
                println("rebuild with load shed")
                m = new_model(factory_like)
                JuMP.set_optimizer_attributes(m, pairs(solver_kwargs)...)
                m = _build_model(m; symbolize(model_kwargs)...)
                intervals_without_loadshed = 0
            elseif (
                (JuMP.solver_name(m) == "Gurobi") &
                !("BarHomogeneous" in keys(solver_kwargs))
            )
                # if Gurobi, and BarHomogeneous is not enabled, enable it and re-solve
                solver_kwargs["BarHomogeneous"] = 1
                println("enable BarHomogeneous")
                JuMP.set_optimizer_attribute(m, "BarHomogeneous", 1)
            elseif !("load_shed_enabled" in keys(model_kwargs))
                model_kwargs["load_shed_enabled"] = true
                println("rebuild with load shed")
                m = new_model(factory_like)
                JuMP.set_optimizer_attributes(m, pairs(solver_kwargs)...)
                m = _build_model(m; symbolize(model_kwargs)...)
                intervals_without_loadshed = 0
            else
                # Something has gone very wrong
                @show status
                @show keys(model_kwargs)
                @show keys(solver_kwargs)
                @show JuMP.objective_value(m)
                if (
                    ("load_shed_enabled" in keys(model_kwargs)) &&
                    (model_kwargs["load_shed_enabled"] == true)
                )
                    # Display where load shedding is occurring
                    load_shed_values = JuMP.value.(m[:load_shed])
                    load_shed_indices = findall(load_shed_values .> 1e-6)
                    if length(load_shed_indices) > 0
                        @show load_shed_indices
                        @show load_shed_values[load_shed_indices]
                        @show sum(load_shed_values[load_shed_indices])
                    end
                end
                error("Unknown status code!")
            end
        end

        # Save initial conditions for next interval
        pg0 = results.pg[:, end]
        if storage.enabled
            storage_e0 = results.storage_e[:, end]
        end
        if demand_flexibility.enabled
            if demand_flexibility.interval_balance || demand_flexibility.rolling_balance
                init_shifted_demand = dropdims(
                    sum(results.load_shift_up - results.load_shift_dn; dims=2); dims=2
                )
            else
                init_shifted_demand = zeros(size(bus_demand_flex_amt_dn, 1))
            end
        end

        # Save results
        results_filename = "result_" * string(i - 1) * ".mat"
        results_filepath = joinpath(outputfolder, results_filename)
        save_results(results, results_filepath)

        # If load shedding is enabled but hasn't been used for a while, disable
        if (
            ("load_shed_enabled" in keys(model_kwargs)) &&
            (model_kwargs["load_shed_enabled"] == true)
        )
            total_load_shed = sum(results.load_shed)
            if total_load_shed < 1e-3
                intervals_without_loadshed += 1
            else
                intervals_without_loadshed = 0
            end
            if intervals_without_loadshed == unused_load_shed_intervals_turnoff
                println("rebuilding without load_shed")
                # delete! will work here even if the key is not present
                delete!(solver_kwargs, "BarHomogeneous")
                delete!(model_kwargs, "load_shed_enabled")
                m = new_model(factory_like)
                JuMP.set_optimizer_attributes(m, pairs(solver_kwargs)...)
                m = _build_model(m; symbolize(model_kwargs)...)
            end
        end
    end

    return m
end
