"""
    _make_gen_map(case)

Given a Case object, build a sparse matrix representing generator topology.
"""
function _make_gen_map(case::Case)::SparseMatrixCSC
    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    gen_bus_idx = [bus_id2idx[b] for b in case.gen_bus]
    gen_map = sparse(gen_bus_idx, gen_idx, 1, num_bus, num_gen)
    return gen_map
end


"""
    _make_branch_map(case)

Given a Case object, build a sparse matrix representing branch topology.
"""
function _make_branch_map(case::Case)::SparseMatrixCSC
    num_branch_ac = length(case.branchid)
    num_branch = num_branch_ac + length(case.dclineid)
    num_bus = length(case.busid)
    branch_idx = 1:num_branch
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    all_branch_to = vcat(case.branch_to, case.dcline_to)
    all_branch_from = vcat(case.branch_from, case.dcline_from)
    branch_to_idx = [bus_id2idx[b] for b in all_branch_to]
    branch_from_idx = [bus_id2idx[b] for b in all_branch_from]
    branches_to = sparse(branch_to_idx, branch_idx, 1, num_bus, num_branch)
    branches_from = sparse(branch_from_idx, branch_idx, -1, num_bus, num_branch)
    branch_map = branches_to + branches_from
end


"""
    _build_model(case=case, start_index=x, interval_length=y[, kwargs...])

Given a Case object and a set of options, build an optimization model.
Returns a JuMP.Model instance.
"""
function _build_model(; case::Case, storage::Storage,
                     start_index::Int, interval_length::Int,
                     demand_scaling::Number=1.0,
                     load_shed_enabled::Bool=false,
                     load_shed_penalty::Number=9000,
                     trans_viol_enabled::Bool=false,
                     trans_viol_penalty::Number=100,
                     initial_ramp_enabled::Bool=false,
                     initial_ramp_g0::Array{Float64,1}=Float64[],
                     storage_e0::Array{Float64,1}=Float64[])::JuMP.Model
    # Positional indices from mpc.gencost
    MODEL = 1
    STARTUP = 2
    SHUTDOWN = 3
    NCOST = 4
    COST = 5

    println("building sets: ", Dates.now())
    # Sets
    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    branch_rating = vcat(case.branch_rating, case.dcline_rating)
    branch_rating[branch_rating .== 0] .= Inf
    num_branch_ac = length(case.branchid)
    num_branch = num_branch_ac + length(case.dclineid)
    branch_idx = 1:num_branch
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    end_index = start_index + interval_length - 1
    num_hour = interval_length
    hour_idx = 1:interval_length
    if size(storage.gen, 1) > 0
        storage_enabled = true
        num_storage = size(storage.gen, 1)
        storage_idx = 1:num_storage
        storage_max_dis = storage.gen[:, 9]
        storage_max_chg = -1 * storage.gen[:, 10]
        storage_min_energy = storage.sd_table.MinStorageLevel
        storage_max_energy = storage.sd_table.MaxStorageLevel
        storage_bus_idx = [bus_id2idx[b] for b in storage.gen[:, 1]]
        storage_map = sparse(storage_bus_idx, storage_idx, 1, num_bus,
                             num_storage)::SparseMatrixCSC
    else
        storage_enabled = false
    end
    # Subsets
    gen_wind_idx = gen_idx[findall(case.genfuel .== "wind")]
    gen_solar_idx = gen_idx[findall(case.genfuel .== "solar")]
    gen_hydro_idx = gen_idx[findall(case.genfuel .== "hydro")]
    renewable_idx = sort(vcat(gen_wind_idx, gen_solar_idx, gen_hydro_idx))
    case.gen_pmax[renewable_idx] .= Inf
    noninf_pmax = findall(case.gen_pmax .!= Inf)
    num_wind = length(gen_wind_idx)
    num_solar = length(gen_solar_idx)
    num_hydro = length(gen_hydro_idx)
    # Ensure that the model has been piecewise linearized; sum should be > 0
    piecewise_enabled = (sum(case.gencost[:,MODEL] .== 1) > 0)
    err_msg = ("No piecewise segments detected. "
               * "Did you forget to linearize_gencost?")
    @assert(piecewise_enabled, err_msg)
    # For now, assume all gens are represented with same number of segments
    num_segments = convert(Int, maximum(case.gencost[:,NCOST])) - 1
    segment_width = (case.gen_pmax - case.gen_pmin) ./ num_segments
    segment_idx = 1:num_segments
    fixed_cost = case.gencost[:, COST+1]
    # Note: this formulation still assumes quadratic cost curves only!
    segment_slope = zeros(num_gen, num_segments)
    for i in segment_idx
        segment_slope[:, i] = (
            (2 * case.gencost_orig[:, COST] .* case.gen_pmin)
            + case.gencost_orig[:, COST+1]
            + (2*i - 1) * case.gencost_orig[:, COST] .* segment_width
            )
    end

    println("parameters: ", Dates.now())
    # Parameters
    # Generator topology matrix
    gen_map = _make_gen_map(case)
    # Branch connectivity matrix
    all_branch_to = vcat(case.branch_to, case.dcline_to)
    all_branch_from = vcat(case.branch_from, case.dcline_from)
    branch_to_idx = Int64[bus_id2idx[b] for b in all_branch_to]
    branch_from_idx = Int64[bus_id2idx[b] for b in all_branch_from]
    branch_map = _make_branch_map(case)
    # Demand by bus
    bus_df = DataFrames.DataFrame(
        name=case.busid, load=case.bus_demand, zone=case.bus_zone)
    zone_demand = DataFrames.by(bus_df, :zone, :load => sum)
    zone_list = sort(collect(Set(case.bus_zone)))
    num_zones = length(zone_list)
    zone_idx = 1:num_zones
    zone_id2idx = Dict(zone_list .=> zone_idx)
    bus_df_with_zone_load = join(bus_df, zone_demand, on = :zone)
    bus_share = bus_df[:, :load] ./ bus_df_with_zone_load[:, :load_sum]
    bus_zone_idx = Int64[zone_id2idx[z] for z in case.bus_zone]
    zone_to_bus_shares = sparse(bus_zone_idx, bus_idx, bus_share)::SparseMatrixCSC
    # Profiles
    simulation_demand = Matrix(case.demand[start_index:end_index, 2:end])
    bus_demand = convert(
        Matrix, transpose(simulation_demand * zone_to_bus_shares))::Matrix
    bus_demand *= demand_scaling
    simulation_hydro = Matrix(case.hydro[start_index:end_index, 2:end])
    simulation_solar = Matrix(case.solar[start_index:end_index, 2:end])
    simulation_wind = Matrix(case.wind[start_index:end_index, 2:end])

    # Model
    m = JuMP.Model()

    println("variables: ", Dates.now())
    # Variables
    # Explicitly defined as 1:x so that JuMP Array, not DenseArrayAxis
    JuMP.@variable(m, pg[1:num_gen,1:num_hour] >= 0)
    JuMP.@variable(m, pg_seg[1:num_gen, 1:num_segments, 1:num_hour] >= 0)
    JuMP.@variable(m, pf[1:num_branch,1:num_hour])
    JuMP.@variable(m, theta[1:num_bus,1:num_hour])
    if load_shed_enabled
        JuMP.@variable(m,
            0 <= load_shed[i = 1:num_bus, j = 1:num_hour] <= bus_demand[i,j])
    end
    if trans_viol_enabled
        JuMP.@variable(m,
            0 <= trans_viol[i = 1:num_branch, j = 1:num_hour])
    end
    if storage_enabled
        JuMP.@variable(m,
            0 <= storage_chg[i = 1:num_storage, j = 1:num_hour]
            <= storage_max_chg[i])
        JuMP.@variable(m,
            0 <= storage_dis[i = 1:num_storage, j = 1:num_hour]
            <= storage_max_dis[i])
        JuMP.@variable(m,
            storage_min_energy[i]
            <= storage_soc[i = 1:num_storage, j = 1:num_hour]
            <= storage_max_energy[i])
    end

    println("constraints: ", Dates.now())
    # Constraints

    println("powerbalance: ", Dates.now())
    gen_injections = JuMP.@expression(m, gen_map * pg)
    line_injections = JuMP.@expression(m, branch_map * pf)
    injections = JuMP.@expression(m, gen_injections + line_injections)
    if load_shed_enabled
        injections = JuMP.@expression(m, injections + load_shed)
    end
    withdrawls = JuMP.@expression(m, bus_demand)
    if storage_enabled
        injections = JuMP.@expression(m, injections + storage_map * storage_dis)
        withdrawls = JuMP.@expression(m, withdrawls + storage_map * storage_chg)
    end
    JuMP.@constraint(m, powerbalance, (injections .== withdrawls))
    println("powerbalance, setting names: ", Dates.now())
    for i in 1:num_bus, j in 1:num_hour
        JuMP.set_name(powerbalance[i,j],
                      "powerbalance[" * string(i) * "," * string(j) * "]")
    end

    if storage_enabled
        println("storage soc_tracking: ", Dates.now())
        JuMP.@constraint(m, soc_tracking[i=1:num_storage, h=1:(num_hour-1)],
            storage_soc[i, h+1] == (
                storage_soc[i, h]
                + storage.sd_table.InEff[i] * storage_chg[i, h+1]
                - (1 / storage.sd_table.OutEff[i]) * storage_dis[i, h+1])
            )
        println("storage initial_soc: ", Dates.now())
        JuMP.@constraint(m, initial_soc[i=1:num_storage],
            storage_soc[i, 1] == (
                storage_e0[i]
                + storage.sd_table.InEff[i] * storage_chg[i, 1]
                - (1 / storage.sd_table.OutEff[i]) * storage_dis[i, 1])
            )
    end

    if initial_ramp_enabled
        println("initial rampup: ", Dates.now())
        noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
        JuMP.@constraint(m, initial_rampup[i = noninf_ramp_idx],
            pg[i,1] - initial_ramp_g0[i] <= case.gen_ramp30[i] * 2)
        println("initial rampdown: ", Dates.now())
        JuMP.@constraint(m, initial_rampdown[i = noninf_ramp_idx],
            case.gen_ramp30[i] * -2 <= pg[i,1] - initial_ramp_g0[i])
    end

    if length(hour_idx) > 1
        println("rampup: ", Dates.now())
        noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
        JuMP.@constraint(m, rampup[i = noninf_ramp_idx, h = 1:(num_hour-1)],
            pg[i,h+1] - pg[i,h] <= case.gen_ramp30[i] * 2)
        println("rampdown: ", Dates.now())
        JuMP.@constraint(m, rampdown[i = noninf_ramp_idx, h = 1:(num_hour-1)],
            case.gen_ramp30[i] * -2 <= pg[i, h+1] - pg[i, h])
    end

    println("segment_max: ", Dates.now())
    JuMP.@constraint(
        m,
        segment_max[i = noninf_pmax, s = segment_idx, h = hour_idx],
        pg_seg[i,s,h] <= segment_width[i])
    println("segment_add: ", Dates.now())
    JuMP.@constraint(
        m, segment_add[i = noninf_pmax, h = hour_idx],
        pg[i,h] == case.gen_pmin[i] + sum(pg_seg[i,:,h]))

    if trans_viol_enabled
        println("branch_min: ", Dates.now())
        noninf_branch_idx = findall(branch_rating .!= Inf)
        JuMP.@constraint(m, branch_min[br = noninf_branch_idx, h = hour_idx], (
            -1 * (branch_rating[br] + trans_viol[br, h]) <= pf[br, h]))

        println("branch_max: ", Dates.now())
        JuMP.@constraint(m, branch_max[br = noninf_branch_idx, h = hour_idx], (
            pf[br, h] <= branch_rating[br] + trans_viol[br, h]))
    else
        println("branch_min: ", Dates.now())
        noninf_branch_idx = findall(branch_rating .!= Inf)
        JuMP.@constraint(m, branch_min[br = noninf_branch_idx, h = hour_idx], (
            -branch_rating[br] <= pf[br, h]))

        println("branch_max: ", Dates.now())
        JuMP.@constraint(m, branch_max[br = noninf_branch_idx, h = hour_idx], (
            pf[br, h] <= branch_rating[br]))
    end

    println("branch_angle: ", Dates.now())
    # Explicit numbering here so that we constrain AC branches but not DC
    JuMP.@constraint(m, branch_angle[br = 1:num_branch_ac, h = 1:num_hour], (
        case.branch_reactance[br] * pf[br,h]
        == (theta[branch_to_idx[br],h] - theta[branch_from_idx[br],h])))

    println("hydro_fixed: ", Dates.now())
    JuMP.@constraint(m, hydro_fixed[i = 1:num_hydro, h = hour_idx], (
        pg[gen_hydro_idx[i], h] == simulation_hydro[h, i]))

    println("solar_max: ", Dates.now())
    JuMP.@constraint(m, solar_max[i = 1:num_solar, h = hour_idx], (
        pg[gen_solar_idx[i], h] <= simulation_solar[h, i]))

    println("wind_max: ", Dates.now())
    JuMP.@constraint(m, wind_max[i = 1:num_wind, h = hour_idx], (
        pg[gen_wind_idx[i], h] <= simulation_wind[h, i]))

    println("objective: ", Dates.now())
    # Start with generator variable O & M, piecewise
    obj = JuMP.@expression(m,
        sum(segment_slope[noninf_pmax,:] .* pg_seg[noninf_pmax,:,:]))
    # Add fixed costs
    JuMP.add_to_expression!(
        obj, JuMP.@expression(m, num_hour * sum(fixed_cost)))
    # Add load shed penalty (if necessary)
    if load_shed_enabled
        JuMP.add_to_expression!(
            obj, JuMP.@expression(m, load_shed_penalty * sum(load_shed)))
    end
    # Add transmission violation penalty (if necessary)
    if trans_viol_enabled
        JuMP.add_to_expression!(
            obj, JuMP.@expression(m, trans_viol_penalty * sum(trans_viol)))
    end
    # Pay for ending with less storage energy than initial
    if storage_enabled
        JuMP.add_to_expression!(obj, JuMP.@expression(m, sum(
            (storage_e0 - storage_soc[:,end])
            .* storage.sd_table.TerminalStoragePrice)))
    end
    # Finally, set as objective of model
    JuMP.@objective(m, Min, obj)

    println(Dates.now())
    return m
end


"""Build and solve a model using a given Gurobi env."""
function build_and_solve(
        model_kwargs::Dict, solver_kwargs::Dict, env::Gurobi.Env)::Results
    # Bad (but known) statuses to match against
    bad_statuses = (
        JuMP.MOI.INFEASIBLE, JuMP.MOI.INFEASIBLE_OR_UNBOUNDED,
        JuMP.MOI.NUMERICAL_ERROR, JuMP.MOI.OTHER_LIMIT,
        )
    # Start with no demand downscaling
    model_kwargs["demand_scaling"] = 1.0
    while true
        global results
        # Convert Dicts to NamedTuples
        m_kwargs = (; (Symbol(k) => v for (k,v) in model_kwargs)...)
        s_kwargs = (; (Symbol(k) => v for (k,v) in solver_kwargs)...)
        m = _build_model(; m_kwargs...)
        JuMP.optimize!(
            m, JuMP.with_optimizer(Gurobi.Optimizer, env; s_kwargs...))
        status = JuMP.termination_status(m)
        if status == JuMP.MOI.OPTIMAL
            results = get_results(m)
            break
        elseif status in bad_statuses
            model_kwargs["demand_scaling"] -= 0.05
            if model_kwargs["demand_scaling"] < 0
                error("Too many demand reductions, scaling cannot go negative")
            end
            println("Optimization failed, Reducing demand: "
                    * string(model_kwargs["demand_scaling"]))
        else
            @show status
            error("Unknown status code!")
        end
    end
    return results
end
