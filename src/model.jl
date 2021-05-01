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
    return branch_map
end


"""
    _make_bus_demand_weighting(case)

Given a Case object, build a sparse matrix that indicates the weighting of each bus in 
    each zone.
"""
function _make_bus_demand_weighting(
    case::Case, start_index::Int, end_index::Int
)::SparseMatrixCSC
    bus_idx = 1:length(case.busid)
    bus_df = DataFrames.DataFrame(
        name=case.busid, load=case.bus_demand, zone=case.bus_zone
    )
    zone_demand = DataFrames.combine(
        DataFrames.groupby(bus_df, :zone), :load => sum
    )
    zone_list = sort(collect(Set(case.bus_zone)))
    zone_idx = 1:length(zone_list)
    zone_id2idx = Dict(zone_list .=> zone_idx)
    bus_df_with_zone_load = DataFrames.innerjoin(bus_df, zone_demand, on=:zone)
    bus_share = bus_df[:, :load] ./ bus_df_with_zone_load[:, :load_sum]
    bus_zone_idx = Int64[zone_id2idx[z] for z in case.bus_zone]
    zone_to_bus_shares = sparse(
        bus_zone_idx, bus_idx, bus_share
    )::SparseMatrixCSC
    return zone_to_bus_shares
end


"""
    _make_bus_demand(case)

Given a Case object, build a matrix of demand by (bus, hour) for this interval.
"""
function _make_bus_demand(case::Case, start_index::Int, end_index::Int)::Matrix
    # Bus weighting
    zone_to_bus_shares = _make_bus_demand_weighting(case, start_index, end_index)

    # Profiles
    simulation_demand = Matrix(case.demand[start_index:end_index, 2:end])
    bus_demand = permutedims(simulation_demand * zone_to_bus_shares)
    return bus_demand
end

"""
    _make_bus_demand_flexibility_amount(case, demand_flexibility)

Given a Case object and a DemandFlexibility object, build a matrix of demand flexibility
    by (bus, hour) for this interval.
"""
function _make_bus_demand_flexibility_amount(
    case::Case, demand_flexibility::DemandFlexibility, start_index::Int, end_index::Int
)::Matrix
    # Bus weighting
    zone_to_bus_shares = _make_bus_demand_weighting(case, start_index, end_index)

    # Demand flexibility profiles
    simulation_demand_flex_amt = Matrix(
        demand_flexibility.flex_amt[start_index:end_index, 2:end]
    )
    bus_demand_flex_amt = permutedims(simulation_demand_flex_amt * zone_to_bus_shares)
    return bus_demand_flex_amt
end


"""
    _build_segment_slope(case, segment_idx, segment_width)

Given a Case object, an index of segments (e.g. 1:3), and a vector of widths
    (matching dimension of gen), return segment slopes by (gen, segment_idx).
"""
function _build_segment_slope(case::Case, segment_idx, segment_width)::Matrix
    # Note: this formulation still assumes quadratic cost curves only!
    COST = 5        # Positional index from mpc.gencost
    segment_slope = zeros(length(case.genid), length(segment_idx))
    for i in segment_idx
        segment_slope[:, i] = (
            (2 * case.gencost_orig[:, COST] .* case.gen_pmin)
            + case.gencost_orig[:, COST+1]
            + (2 * i - 1) * case.gencost_orig[:, COST] .* segment_width
            )
    end
    return segment_slope
end


function _make_sets(case::Case)::Sets
    _make_sets(case, nothing)
end


function _make_sets(case::Case, storage::Union{Storage,Nothing})::Sets
    # Positional indices from mpc.gencost
    MODEL = 1
    NCOST = 4
    # Sets - Buses
    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    load_bus_idx = findall(case.bus_demand .> 0)
    num_load_bus = length(load_bus_idx)
    # Sets - branches
    ac_branch_rating = replace(case.branch_rating, 0=>Inf)
    branch_rating = vcat(ac_branch_rating, case.dcline_pmax)
    num_branch_ac = length(case.branchid)
    num_branch = num_branch_ac + length(case.dclineid)
    branch_idx = 1:num_branch
    noninf_branch_idx = findall(branch_rating .!= Inf)
    all_branch_to = vcat(case.branch_to, case.dcline_to)
    all_branch_from = vcat(case.branch_from, case.dcline_from)
    branch_to_idx = Int64[bus_id2idx[b] for b in all_branch_to]
    branch_from_idx = Int64[bus_id2idx[b] for b in all_branch_from]
    # Sets - generators
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    # Subsets - generators
    gen_wind_idx = gen_idx[findall(
        (case.genfuel .== "wind") .| (case.genfuel .== "wind_offshore"))]
    gen_solar_idx = gen_idx[findall(case.genfuel .== "solar")]
    gen_hydro_idx = gen_idx[findall(case.genfuel .== "hydro")]
    renewable_idx = sort(vcat(gen_wind_idx, gen_solar_idx, gen_hydro_idx))
    case.gen_pmax[renewable_idx] .= Inf
    noninf_pmax = findall(case.gen_pmax .!= Inf)
    num_wind = length(gen_wind_idx)
    num_solar = length(gen_solar_idx)
    num_hydro = length(gen_hydro_idx)
    # Generator cost curve segments
    piecewise_enabled = (sum(case.gencost[:, MODEL] .== 1) > 0)
    @assert(piecewise_enabled, "No piecewise segments detected. "
                               * "Did you forget to linearize_gencost?")
    num_segments = convert(Int, maximum(case.gencost[:, NCOST])) - 1
    segment_idx = 1:num_segments
    # Storage
    storage_enabled = isa(storage, Storage) && (size(storage.gen, 1) > 0)
    num_storage = storage_enabled ? size(storage.gen, 1) : 0
    storage_idx = storage_enabled ? (1:num_storage) : nothing

    sets = Sets(;
        num_bus=num_bus, bus_idx=bus_idx, bus_id2idx=bus_id2idx,
        load_bus_idx=load_bus_idx, num_load_bus=num_load_bus,
        num_branch=num_branch, num_branch_ac=num_branch_ac,
        branch_idx=branch_idx, noninf_branch_idx=noninf_branch_idx,
        branch_to_idx=branch_to_idx, branch_from_idx=branch_from_idx,
        num_gen=num_gen, gen_idx=gen_idx, noninf_pmax=noninf_pmax,
        gen_hydro_idx=gen_hydro_idx, gen_solar_idx=gen_solar_idx,
        gen_wind_idx=gen_wind_idx, renewable_idx=renewable_idx,
        num_wind=num_wind, num_solar=num_solar, num_hydro=num_hydro,
        num_segments=num_segments, segment_idx=segment_idx,
        num_storage=num_storage, storage_idx=storage_idx)
    return sets
end


"""
    _build_model(m; case=case, storage=storage, start_index=x,
                 interval_length=y[, kwargs...])

Given a Case object and a set of options, build an optimization model.
Returns a JuMP.Model instance.
"""
function _build_model(
    m::JuMP.Model;
    case::Case,
    storage::Storage,
    demand_flexibility::DemandFlexibility,
    start_index::Int, 
    interval_length::Int,
    demand_scaling::Number=1.0,
    load_shed_enabled::Bool=false,
    load_shed_penalty::Number=9000,
    trans_viol_enabled::Bool=false,
    trans_viol_penalty::Number=100,
    initial_ramp_enabled::Bool=false,
    initial_ramp_g0::Array{Float64,1}=Float64[],
    storage_e0::Array{Float64,1}=Float64[]
)::Tuple{JuMP.Model, VariablesOfInterest}
    # Positional indices from mpc.gencost
    COST = 5
    # Positional indices from mpc.gen
    PMAX = 9
    PMIN = 10

    println("building sets: ", Dates.now())
    # Sets - time periods
    num_hour = interval_length
    hour_idx = 1:interval_length
    end_index = start_index + interval_length - 1
    # Sets - static
    sets = _make_sets(case, storage)

    println("parameters: ", Dates.now())
    # Parameters
    # Load bus mapping
    load_bus_map = sparse(sets.load_bus_idx, 1:sets.num_load_bus, 1,
                          sets.num_bus, sets.num_load_bus)
    # Generator topology matrix
    gen_map = _make_gen_map(case)
    # Generation segments
    segment_width = (case.gen_pmax - case.gen_pmin) ./ sets.num_segments
    fixed_cost = case.gencost[:, COST+1]
    segment_slope = _build_segment_slope(case, sets.segment_idx, segment_width)
    # Branch connectivity matrix
    branch_map = _make_branch_map(case)
    branch_pmin = vcat(-1 * case.branch_rating, case.dcline_pmin)
    branch_pmax = vcat(case.branch_rating, case.dcline_pmax)
    # Demand by bus
    bus_demand = _make_bus_demand(case, start_index, end_index)
    bus_demand *= demand_scaling
    simulation_hydro = Matrix(case.hydro[start_index:end_index, 2:end])
    simulation_solar = Matrix(case.solar[start_index:end_index, 2:end])
    simulation_wind = Matrix(case.wind[start_index:end_index, 2:end])
    # Storage parameters (if present)
    storage_enabled = (sets.num_storage > 0)
    if storage_enabled
        storage_max_dis = storage.gen[:, PMAX]
        storage_max_chg = -1 * storage.gen[:, PMIN]
        storage_min_energy = storage.sd_table.MinStorageLevel
        storage_max_energy = storage.sd_table.MaxStorageLevel
        storage_bus_idx = [sets.bus_id2idx[b] for b in storage.gen[:, 1]]
        storage_map = sparse(storage_bus_idx, sets.storage_idx, 1,
                             sets.num_bus, sets.num_storage)::SparseMatrixCSC
    end
    # Demand flexibility parameters (if present)
    bus_demand_flex_amt = _make_bus_demand_flexibility_amount(
        case, demand_flexibility, start_index, end_index
    )
    if demand_flexibility.enabled && (
        demand_flexibility.duration == nothing 
            || demand_flexibility.duration > interval_length
    )
        if demand_flexibility.duration > interval_length
            @warn (
                "Demand flexibility durations greater than the interval length are set "
                * "equal to the interval length."
            )
        end
        demand_flexibility.duration = interval_length
    end

    println("variables: ", Dates.now())
    # Variables
    # Explicitly declare containers as Array of VariableRefs, not DenseArrayAxis
    JuMP.@variables(m, begin
        pg[sets.gen_idx, hour_idx] >= 0, (container=Array)
        pg_seg[sets.gen_idx, sets.segment_idx, hour_idx] >= 0, (container=Array)
        pf[sets.branch_idx, hour_idx], (container=Array)
        theta[sets.bus_idx, hour_idx], (container=Array)
    end)
    if load_shed_enabled
        JuMP.@variable(
            m,
            load_shed[i in 1:sets.num_load_bus, j in 1:interval_length] >= 0,
            container=Array
        )
    end
    if trans_viol_enabled
        JuMP.@variable(m,
            0 <= trans_viol[i in sets.branch_idx, j in hour_idx],
            container=Array)
    end
    if storage_enabled
        JuMP.@variables(m, begin
            (0 <= storage_chg[i in sets.storage_idx, j in hour_idx]
                <= storage_max_chg[i]), (container=Array)
            (0 <= storage_dis[i in sets.storage_idx, j in hour_idx]
                <= storage_max_dis[i]), (container=Array)
            (storage_min_energy[i]
                <= storage_soc[i in sets.storage_idx, j in hour_idx]
                <= storage_max_energy[i]), (container=Array)
        end)
    end
    if demand_flexibility.enabled
        # The amount of demand that is curtailed from the base load
        JuMP.@variable(
            m, 
            0 <= load_shift_dn[i in 1:sets.num_load_bus, j in 1:interval_length] 
                <= bus_demand_flex_amt[sets.load_bus_idx[i], j]
        )

        # The amount of demand that is added to the base load
        JuMP.@variable(
            m, 
            0 <= load_shift_up[i in 1:sets.num_load_bus, j in 1:interval_length]
                <= bus_demand_flex_amt[sets.load_bus_idx[i], j]
        )
    end

    println("constraints: ", Dates.now())
    # Constraints

    println("powerbalance: ", Dates.now())
    gen_injections = JuMP.@expression(m, gen_map * pg)
    line_injections = JuMP.@expression(m, branch_map * pf)
    injections = JuMP.@expression(m, gen_injections + line_injections)
    if load_shed_enabled
        injections = JuMP.@expression(m, injections + load_bus_map * load_shed)
    end
    withdrawals = JuMP.@expression(m, bus_demand)
    if storage_enabled
        injections = JuMP.@expression(m, injections + storage_map * storage_dis)
        withdrawals = JuMP.@expression(m, withdrawals + storage_map * storage_chg)
    end
    if demand_flexibility.enabled
        injections = JuMP.@expression(m, injections + load_bus_map * load_shift_dn)
        withdrawals = JuMP.@expression(m, withdrawals + load_bus_map * load_shift_up)
    end
    JuMP.@constraint(m, powerbalance, (injections .== withdrawals))
    println("powerbalance, setting names: ", Dates.now())
    for i in sets.bus_idx, j in hour_idx
        JuMP.set_name(powerbalance[i, j],
                      "powerbalance[" * string(i) * "," * string(j) * "]")
    end

    if load_shed_enabled
        if demand_flexibility.enabled
            JuMP.@constraint(
                m, 
                load_shed_ub[i in 1:sets.num_load_bus, j in 1:interval_length], 
                load_shed[i, j] <= bus_demand[sets.load_bus_idx[i], j] 
                    + load_shift_up[i, j]
                    - load_shift_dn[i, j]
            )
        else
            JuMP.@constraint(
                m, 
                load_shed_ub[i in 1:sets.num_load_bus, j in 1:interval_length], 
                load_shed[i, j] <= bus_demand[sets.load_bus_idx[i], j]
            )
        end
    end

    if storage_enabled
        println("storage soc_tracking: ", Dates.now())
        JuMP.@constraint(m,
            soc_tracking[i in 1:sets.num_storage, h in 1:(num_hour-1)],
            storage_soc[i, h+1] == (
                storage_soc[i, h] * (1 - storage.sd_table.LossFactor[i])
                + storage.sd_table.InEff[i] * storage_chg[i, h+1]
                - (1 / storage.sd_table.OutEff[i]) * storage_dis[i, h+1]),
            container=Array)
        println("storage initial_soc: ", Dates.now())
        JuMP.@constraint(m,
            initial_soc[i in 1:sets.num_storage],
            storage_soc[i, 1] == (
                storage_e0[i]
                + storage.sd_table.InEff[i] * storage_chg[i, 1]
                - (1 / storage.sd_table.OutEff[i]) * storage_dis[i, 1]),
            container=Array)
        println("storage final_soc_min: ", Dates.now())
        JuMP.@constraint(m,
            soc_terminal_min[i in 1:sets.num_storage],
            storage_soc[i, num_hour] >= storage.sd_table.ExpectedTerminalStorageMin[i],
            container=Array)
        println("storage final_soc_max: ", Dates.now())
        JuMP.@constraint(m,
            soc_terminal_max[i in 1:sets.num_storage],
            storage_soc[i, num_hour] <= storage.sd_table.ExpectedTerminalStorageMax[i],
            container=Array)
    end

    if demand_flexibility.enabled
        if demand_flexibility.rolling_balance && (
            demand_flexibility.duration < interval_length
        )
            println("rolling load balance: ", Dates.now())
            JuMP.@constraint(
                m, 
                rolling_load_balance[
                    i in 1:sets.num_load_bus, 
                    k in 1:(interval_length - demand_flexibility.duration)
                ], 
                sum(
                    load_shift_up[i, j] - load_shift_dn[i, j] 
                    for j in k:(k + demand_flexibility.duration)
                ) >= 0
            )
        end
        if demand_flexibility.interval_balance
            println("interval load balance: ", Dates.now())
            JuMP.@constraint(
                m, 
                interval_load_balance[i in 1:sets.num_load_bus], 
                sum(
                    load_shift_up[i, j] - load_shift_dn[i, j] for j in 1:interval_length
                ) >= 0
            )
        end
    end

    noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
    if initial_ramp_enabled
        println("initial rampup: ", Dates.now())
        JuMP.@constraint(m,
            initial_rampup[i in noninf_ramp_idx],
            pg[i, 1] - initial_ramp_g0[i] <= case.gen_ramp30[i] * 2)
        println("initial rampdown: ", Dates.now())
        JuMP.@constraint(m,
            initial_rampdown[i in noninf_ramp_idx],
            case.gen_ramp30[i] * -2 <= pg[i, 1] - initial_ramp_g0[i])
    end
    if length(hour_idx) > 1
        println("rampup: ", Dates.now())
        JuMP.@constraint(m,
            rampup[i in noninf_ramp_idx, h in 1:(num_hour-1)],
            pg[i, h+1] - pg[i, h] <= case.gen_ramp30[i] * 2)
        println("rampdown: ", Dates.now())
        JuMP.@constraint(m,
            rampdown[i in noninf_ramp_idx, h in 1:(num_hour-1)],
            case.gen_ramp30[i] * -2 <= pg[i, h+1] - pg[i, h])
    end

    println("segment_max: ", Dates.now())
    JuMP.@constraint(m,
        segment_max[
            i in sets.noninf_pmax, s in sets.segment_idx, h in hour_idx],
        pg_seg[i, s, h] <= segment_width[i])
    println("segment_add: ", Dates.now())
    JuMP.@constraint(m,
        segment_add[i in sets.noninf_pmax, h in hour_idx],
        pg[i, h] == case.gen_pmin[i] + sum(pg_seg[i, :, h]))

    if trans_viol_enabled
        JuMP.@expression(m, branch_limit_pmin, branch_pmin - trans_viol)
        JuMP.@expression(m, branch_limit_pmax, branch_pmax + trans_viol)
    else
        JuMP.@expression(m,
            branch_limit_pmin[br in sets.branch_idx, h in hour_idx],
            branch_pmin[br])
        JuMP.@expression(m,
            branch_limit_pmax[br in sets.branch_idx, h in hour_idx],
            branch_pmax[br])
    end
    println("branch_min, branch_max: ", Dates.now())
    JuMP.@constraint(m,
        branch_min[br in sets.noninf_branch_idx, h in hour_idx],
        branch_limit_pmin[br, h] <= pf[br, h])
    println("branch_max: ", Dates.now())
    JuMP.@constraint(m,
        branch_max[br in sets.noninf_branch_idx, h in hour_idx],
        pf[br, h] <= branch_limit_pmax[br, h])

    println("branch_angle: ", Dates.now())
    # Explicit numbering here so that we constrain AC branches but not DC
    JuMP.@constraint(m,
        branch_angle[br in 1:sets.num_branch_ac, h in hour_idx],
        (case.branch_reactance[br] * pf[br, h]
            == (theta[sets.branch_to_idx[br], h]
                - theta[sets.branch_from_idx[br], h])))

    # Constrain variable generators based on profiles
    println("hydro_fixed: ", Dates.now())
    JuMP.@constraint(m,
        hydro_fixed[i in 1:sets.num_hydro, h in hour_idx],
        pg[sets.gen_hydro_idx[i], h] == simulation_hydro[h, i])
    println("solar_max: ", Dates.now())
    JuMP.@constraint(m,
        solar_max[i in 1:sets.num_solar, h in hour_idx],
        pg[sets.gen_solar_idx[i], h] <= simulation_solar[h, i])
    println("wind_max: ", Dates.now())
    JuMP.@constraint(m,
        wind_max[i in 1:sets.num_wind, h in hour_idx],
        pg[sets.gen_wind_idx[i], h] <= simulation_wind[h, i])

    println("objective: ", Dates.now())
    # Start with generator variable O & M, piecewise
    obj = JuMP.@expression(m,
        sum(segment_slope[sets.noninf_pmax, :]
            .* pg_seg[sets.noninf_pmax, :, :]))
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
        storage_penalty = JuMP.@expression(m,
            sum((storage_e0 - storage_soc[:, end])
                .* storage.sd_table.TerminalStoragePrice))
        JuMP.add_to_expression!(obj, storage_penalty)
    end
    # Finally, set as objective of model
    JuMP.@objective(m, Min, obj)

    println(Dates.now())
    # For non-existent variables/constraints, define as `nothing`
    load_shed = load_shed_enabled ? load_shed : nothing
    load_shift_up = demand_flexibility.enabled ? load_shift_up : nothing
    load_shift_dn = demand_flexibility.enabled ? load_shift_dn : nothing
    storage_dis = storage_enabled ? storage_dis : nothing
    storage_chg = storage_enabled ? storage_chg : nothing
    storage_soc = storage_enabled ? storage_soc : nothing
    initial_soc = storage_enabled ? initial_soc : nothing
    initial_rampup = initial_ramp_enabled ? initial_rampup : nothing
    initial_rampdown = initial_ramp_enabled ? initial_rampdown : nothing
    load_shed_ub = load_shed_enabled ? load_shed_ub : nothing
    voi = VariablesOfInterest(;
        # Variables
        pg=pg, pf=pf, 
        load_shed=load_shed, load_shift_up=load_shift_up, load_shift_dn=load_shift_dn, 
        storage_soc=storage_soc, storage_dis=storage_dis, storage_chg=storage_chg,
        # Constraints
        branch_min=branch_min, branch_max=branch_max, powerbalance=powerbalance,
        initial_soc=initial_soc, load_shed_ub=load_shed_ub, 
        initial_rampup=initial_rampup, initial_rampdown=initial_rampdown,
        hydro_fixed=hydro_fixed, solar_max=solar_max, wind_max=wind_max)
    return (m, voi)
end
