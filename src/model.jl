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
function _make_bus_demand_weighting(case::Case)::SparseMatrixCSC
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
    zone_to_bus_shares = _make_bus_demand_weighting(case)

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
)::Tuple{Matrix,Matrix}
    # Bus weighting
    zone_to_bus_shares = _make_bus_demand_weighting(case)
    # Demand flexibility up profile
    simulation_demand_flex_amt_up = Matrix(
        demand_flexibility.flex_amt_up[start_index:end_index, 2:end]
    )
    # Demand flexibility down profile
    simulation_demand_flex_amt_dn = Matrix(
        demand_flexibility.flex_amt_dn[start_index:end_index, 2:end]
    )
    # convert per-area input to per-bus values
    if demand_flexibility.input_granularity == "AREA"
        bus_demand_flex_amt_up = permutedims(
            simulation_demand_flex_amt_up * zone_to_bus_shares
        )
        bus_demand_flex_amt_dn = permutedims(
            simulation_demand_flex_amt_dn * zone_to_bus_shares
        )
    # input is already per-bus, copy to new container
    elseif demand_flexibility.input_granularity == "BUS"
        bus_demand_flex_amt_up = permutedims(simulation_demand_flex_amt_up)
        bus_demand_flex_amt_dn = permutedims(simulation_demand_flex_amt_dn)
    else
        println("Warning! Invalid demand flexibility parameter input_granularity!")
    end
    return (bus_demand_flex_amt_up, bus_demand_flex_amt_dn)
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


function _make_sets(case::Case, 
                    storage::Union{Storage,Nothing}=nothing, 
                    demand_flexibility::Union{DemandFlexibility, Nothing}=nothing
        )::Sets
    # Positional indices from mpc.gencost
    MODEL = 1
    NCOST = 4
    # Sets - Buses
    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    load_bus_idx = findall(case.bus_demand .> 0)
    num_load_bus = length(load_bus_idx)
    load_bus_map = sparse(load_bus_idx, 1:num_load_bus, 1, num_bus, num_load_bus)
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
    # Demand flexibility, additional info for input->bus conversion
    if demand_flexibility.enabled
        if demand_flexibility.input_granularity == "BUS"
            # assume each flexible bus can go up/dn, so only use the Dataframe for up
            flexible_bus_str = names(demand_flexibility.flex_amt_up)[2:end]
            flexible_bus_id = [parse(Int64, bus) for bus in flexible_bus_str]
            flexible_bus_idx = [bus_id2idx[bus] for bus in flexible_bus_id]
            num_flexible_bus = length(flexible_bus_idx)
            flexible_load_bus_map = sparse(
                    flexible_bus_idx, 1:num_flexible_bus, 1, num_bus, num_flexible_bus
                )::SparseMatrixCSC
        elseif demand_flexibility.input_granularity == "AREA"
            flexible_bus_idx = load_bus_idx
            num_flexible_bus = num_load_bus
            flexible_load_bus_map = load_bus_map
        end
    else
        flexible_bus_idx = nothing
        num_flexible_bus = 0
        flexible_load_bus_map = nothing
    end
    # Storage
    storage_enabled = isa(storage, Storage) && storage.enabled
    num_storage = storage_enabled ? size(storage.gen, 1) : 0
    storage_idx = storage_enabled ? (1:num_storage) : nothing
    sets = Sets(;
        num_bus=num_bus, bus_idx=bus_idx, bus_id2idx=bus_id2idx,
        load_bus_idx=load_bus_idx, num_load_bus=num_load_bus, load_bus_map=load_bus_map,
        num_branch=num_branch, num_branch_ac=num_branch_ac,
        branch_idx=branch_idx, noninf_branch_idx=noninf_branch_idx,
        branch_to_idx=branch_to_idx, branch_from_idx=branch_from_idx,
        num_gen=num_gen, gen_idx=gen_idx, noninf_pmax=noninf_pmax,
        gen_hydro_idx=gen_hydro_idx, gen_solar_idx=gen_solar_idx,
        gen_wind_idx=gen_wind_idx, renewable_idx=renewable_idx,
        num_wind=num_wind, num_solar=num_solar, num_hydro=num_hydro,
        num_segments=num_segments, segment_idx=segment_idx,
        num_storage=num_storage, storage_idx=storage_idx, 
        flexible_bus_idx=flexible_bus_idx, num_flexible_bus=num_flexible_bus,
        flexible_load_bus_map=flexible_load_bus_map)     
    return sets
end


function _add_constraint_power_balance!(
    m::JuMP.Model,
    case::Case,
    sets::Sets,
    storage::Storage,
    demand_flexibility::DemandFlexibility,
    bus_demand::Matrix,
    load_shed_enabled::Bool,
)
    # Generator topology matrix
    gen_map = _make_gen_map(case)
    # Branch connectivity matrix
    branch_map = _make_branch_map(case)

    gen_injections = JuMP.@expression(m, gen_map * m[:pg])
    line_injections = JuMP.@expression(m, branch_map * m[:pf])
    injections = JuMP.@expression(m, gen_injections + line_injections)
    if load_shed_enabled
        injections = JuMP.@expression(m, injections + sets.load_bus_map * m[:load_shed])
    end
    withdrawals = JuMP.@expression(m, bus_demand)
    if storage.enabled
        storage_bus_idx = [sets.bus_id2idx[b] for b in storage.gen[:, 1]]
        storage_map = sparse(
            storage_bus_idx, sets.storage_idx, 1, sets.num_bus, sets.num_storage
        )::SparseMatrixCSC
        injections = JuMP.@expression(m, injections + storage_map * m[:storage_dis])
        withdrawals = JuMP.@expression(m, withdrawals + storage_map * m[:storage_chg])
    end
    if demand_flexibility.enabled
        injections = JuMP.@expression(
            m, injections + sets.flexible_load_bus_map * m[:load_shift_dn]
        )
        withdrawals = JuMP.@expression(
            m, withdrawals + sets.flexible_load_bus_map * m[:load_shift_up]
        )
    end
    JuMP.@constraint(m, powerbalance, (injections .== withdrawals))
    println("powerbalance, setting names: ", Dates.now())
    interval_length = size(bus_demand)[2]
    for i in sets.bus_idx, j in 1:interval_length
        JuMP.set_name(
            powerbalance[i, j], "powerbalance[" * string(i) * "," * string(j) * "]"
        )
    end
end


function _add_constraint_load_shed!(
    m::JuMP.Model,
    case::Case,
    sets::Sets,
    demand_flexibility::DemandFlexibility,
    bus_demand::Matrix,
)
    interval_length = size(bus_demand)[2]
    demand_for_load_shed = JuMP.@expression(
        m,
        [i=1:sets.num_load_bus, j=1:interval_length],
        bus_demand[sets.load_bus_idx[i], j],
    )
    if demand_flexibility.enabled
        flexible_load_bus_idx = indexin(sets.flexible_bus_idx, sets.load_bus_idx)
        flexible_load_map = sparse(
                flexible_load_bus_idx, 1:sets.num_flexible_bus, 1, sets.num_load_bus, sets.num_flexible_bus
            )::SparseMatrixCSC
        demand_for_load_shed = JuMP.@expression(
            m, 
            demand_for_load_shed
            + flexible_load_map * m[:load_shift_up]
            - flexible_load_map * m[:load_shift_dn],
        )
    end
    JuMP.@constraint(
        m,
        load_shed_ub[i in 1:sets.num_load_bus, j in 1:interval_length],
        m[:load_shed][i, j] <= demand_for_load_shed[i, j],
    )
end


function _add_constraints_storage_operation!(
    m::JuMP.Model,
    case::Case,
    sets::Sets,
    storage::Storage,
    interval_length::Int,
    storage_e0::Array{Float64,1},
)
    num_hour = interval_length

    println("storage soc_tracking: ", Dates.now())
    JuMP.@constraint(
        m,
        soc_tracking[i in 1:sets.num_storage, h in 1:(num_hour-1)],
        m[:storage_soc][i, h+1] == (
            m[:storage_soc][i, h] * (1 - storage.sd_table.LossFactor[i])
            + storage.sd_table.InEff[i] * m[:storage_chg][i, h+1]
            - (1 / storage.sd_table.OutEff[i]) * m[:storage_dis][i, h+1]
        ),
        container=Array,
    )
    println("storage initial_soc: ", Dates.now())
    JuMP.@constraint(
        m,
        initial_soc[i in 1:sets.num_storage],
        m[:storage_soc][i, 1] == (
            storage_e0[i]
            + storage.sd_table.InEff[i] * m[:storage_chg][i, 1]
            - (1 / storage.sd_table.OutEff[i]) * m[:storage_dis][i, 1]
        ),
        container=Array,
    )
    println("storage final_soc_min: ", Dates.now())
    JuMP.@constraint(
        m,
        soc_terminal_min[i in 1:sets.num_storage],
        m[:storage_soc][i, num_hour] >= storage.sd_table.ExpectedTerminalStorageMin[i],
        container=Array,
    )
    println("storage final_soc_max: ", Dates.now())
    JuMP.@constraint(
        m,
        soc_terminal_max[i in 1:sets.num_storage],
        m[:storage_soc][i, num_hour] <= storage.sd_table.ExpectedTerminalStorageMax[i],
        container=Array,
    )
end


function _add_constraints_demand_flexibility!(
    m::JuMP.Model,
    case::Case,
    sets::Sets,
    demand_flexibility::DemandFlexibility,
    interval_length::Int,
    init_shifted_demand::Array{Float64,1}=Float64[],
)
    if demand_flexibility.rolling_balance
        println("rolling load balance, first window: ", Dates.now())
        JuMP.@constraint(
            m,
            rolling_load_balance_first[i in 1:sets.num_load_bus],
            sum(
                m[:load_shift_up][i, j] - m[:load_shift_dn][i, j] 
                for j in 1:(demand_flexibility.duration - 1)
            ) >= -1 * init_shifted_demand[i],
        )
        println("rolling load balance: ", Dates.now())
        JuMP.@constraint(
            m,
            rolling_load_balance[
                i in 1:sets.num_flexible_bus,
                k in 1:(interval_length - demand_flexibility.duration)
            ],
            sum(
                m[:load_shift_up][i, j] - m[:load_shift_dn][i, j]
                for j in k:(k + demand_flexibility.duration)
            ) >= 0,
        )
    end
    if demand_flexibility.interval_balance
        println("interval load balance: ", Dates.now())
        JuMP.@constraint(
            m,
            interval_load_balance[i in 1:sets.num_flexible_bus],
            sum(
                m[:load_shift_up][i, j] - m[:load_shift_dn][i, j] for j in 1:interval_length
            ) >= -1 * init_shifted_demand[i],
        )
    end
end


function _add_constraints_initial_ramping!(
    m::JuMP.Model, case::Case, sets::Sets, initial_ramp_g0
)
    noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
    println("initial rampup: ", Dates.now())
    JuMP.@constraint(
        m,
        initial_rampup[i in noninf_ramp_idx],
        m[:pg][i, 1] - initial_ramp_g0[i] <= case.gen_ramp30[i] * 2,
    )
    println("initial rampdown: ", Dates.now())
    JuMP.@constraint(
        m,
        initial_rampdown[i in noninf_ramp_idx],
        case.gen_ramp30[i] * -2 <= m[:pg][i, 1] - initial_ramp_g0[i],
    )
end


function _add_constraints_ramping!(
    m::JuMP.Model, case::Case, sets::Sets, interval_length::Int
)
    noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
    println("rampup: ", Dates.now())
    JuMP.@constraint(
        m,
        rampup[i in noninf_ramp_idx, h in 1:(interval_length-1)],
        m[:pg][i, h+1] - m[:pg][i, h] <= case.gen_ramp30[i] * 2,
    )
    println("rampdown: ", Dates.now())
    JuMP.@constraint(
        m,
        rampdown[i in noninf_ramp_idx, h in 1:(interval_length-1)],
        case.gen_ramp30[i] * -2 <= m[:pg][i, h+1] - m[:pg][i, h],
    )
end


function _add_constraints_generator_segments!(
    m::JuMP.Model, case::Case, sets::Sets, hour_idx,
)
    segment_width = (case.gen_pmax - case.gen_pmin) ./ sets.num_segments
    println("segment_max: ", Dates.now())
    JuMP.@constraint(
        m,
        segment_max[i in sets.noninf_pmax, s in sets.segment_idx, h in hour_idx],
        m[:pg_seg][i, s, h] <= segment_width[i],
    )
    println("segment_add: ", Dates.now())
    JuMP.@constraint(
        m,
        segment_add[i in sets.noninf_pmax, h in hour_idx],
        m[:pg][i, h] == case.gen_pmin[i] + sum(m[:pg_seg][i, :, h]),
    )
end


function _add_constraints_branch_flow_limits!(
    m::JuMP.Model, case::Case, sets::Sets, trans_viol_enabled, hour_idx
)
    branch_pmin = vcat(-1 * case.branch_rating, case.dcline_pmin)
    branch_pmax = vcat(case.branch_rating, case.dcline_pmax)
    if trans_viol_enabled
        JuMP.@expression(m, branch_limit_pmin, branch_pmin - m[:trans_viol])
        JuMP.@expression(m, branch_limit_pmax, branch_pmax + m[:trans_viol])
    else
        JuMP.@expression(
            m,
            branch_limit_pmin[br in sets.branch_idx, h in hour_idx],
            branch_pmin[br],
        )
        JuMP.@expression(
            m,
            branch_limit_pmax[br in sets.branch_idx, h in hour_idx],
            branch_pmax[br],
        )
    end
    println("branch_min, branch_max: ", Dates.now())
    JuMP.@constraint(
        m,
        branch_min[br in sets.noninf_branch_idx, h in hour_idx],
        branch_limit_pmin[br, h] <= m[:pf][br, h],
    )
    println("branch_max: ", Dates.now())
    JuMP.@constraint(
        m,
        branch_max[br in sets.noninf_branch_idx, h in hour_idx],
        m[:pf][br, h] <= branch_limit_pmax[br, h],
    )
end


function _add_branch_angle_constraints!(m::JuMP.Model, case::Case, sets::Sets, hour_idx)
    # Explicit numbering here so that we constrain AC branches but not DC
    JuMP.@constraint(
        m,
        branch_angle[br in 1:sets.num_branch_ac, h in hour_idx],
        (
            case.branch_reactance[br] * m[:pf][br, h]
            == (
                m[:theta][sets.branch_to_idx[br], h]
                - m[:theta][sets.branch_from_idx[br], h]
            )
        )
    )
end


function _add_profile_generator_limits!(
    m::JuMP.Model, case::Case, sets::Sets, hour_idx, start_index, interval_length
)
    end_index = start_index + interval_length - 1
    # Generation segments
    simulation_hydro = Matrix(case.hydro[start_index:end_index, 2:end])
    simulation_solar = Matrix(case.solar[start_index:end_index, 2:end])
    simulation_wind = Matrix(case.wind[start_index:end_index, 2:end])
    println("hydro_fixed: ", Dates.now())
    JuMP.@constraint(
        m,
        hydro_fixed[i in 1:sets.num_hydro, h in hour_idx],
        m[:pg][sets.gen_hydro_idx[i], h] == simulation_hydro[h, i],
    )
    println("solar_max: ", Dates.now())
    JuMP.@constraint(
        m,
        solar_max[i in 1:sets.num_solar, h in hour_idx],
        m[:pg][sets.gen_solar_idx[i], h] <= simulation_solar[h, i],
    )
    println("wind_max: ", Dates.now())
    JuMP.@constraint(
        m,
        wind_max[i in 1:sets.num_wind, h in hour_idx],
        m[:pg][sets.gen_wind_idx[i], h] <= simulation_wind[h, i],
    )
end


function _add_objective_function!(
    m::JuMP.Model,
    case::Case,
    sets::Sets,
    storage::Storage,
    start_index::Int, 
    end_index::Int, 
    interval_length::Int,
    load_shed_enabled::Bool,
    load_shed_penalty::Number,
    trans_viol_enabled::Bool,
    storage_e0::Array{Float64,1},
    demand_flexibility::DemandFlexibility,
)
    # Positional indices from mpc.gencost
    COST = 5
    fixed_cost = case.gencost[:, COST+1]
    segment_width = (case.gen_pmax - case.gen_pmin) ./ sets.num_segments
    segment_slope = _build_segment_slope(case, sets.segment_idx, segment_width)

    # Start with generator variable O & M, piecewise
    obj = JuMP.@expression(
        m,
        sum(segment_slope[sets.noninf_pmax, :] .* m[:pg_seg][sets.noninf_pmax, :, :]),
    )
    # Add fixed costs
    JuMP.add_to_expression!(
        obj, JuMP.@expression(m, interval_length * sum(fixed_cost))
    )
    # Add load shed penalty (if necessary)
    if load_shed_enabled
        JuMP.add_to_expression!(
            obj, JuMP.@expression(m, load_shed_penalty * sum(m[:load_shed]))
        )
    end
    # Add transmission violation penalty (if necessary)
    if trans_viol_enabled
        JuMP.add_to_expression!(
            obj, JuMP.@expression(m, trans_viol_penalty * sum(m[:trans_viol]))
        )
    end
    # Pay for ending with less storage energy than initial
    if storage.enabled
        storage_penalty = JuMP.@expression(
            m,
            sum(
                (storage_e0 - m[:storage_soc][:, end])
                .* storage.sd_table.TerminalStoragePrice
            ),
        )
        JuMP.add_to_expression!(obj, storage_penalty)
    end
    
    # Pay for the cost of DR programs based on committed flexible demand
    if demand_flexibility.enabled
        # cost for increasing flexible load
        if !isnothing(demand_flexibility.cost_up)
            bus_demand_flex_cost_up = permutedims(
                Matrix(
                    demand_flexibility.cost_up[start_index:end_index, 2:end]
                )
            )
            demand_response_penalty_up = JuMP.@expression(
                m, sum(sum(bus_demand_flex_cost_up .* m[:load_shift_up]))
            )
            JuMP.add_to_expression!(obj, demand_response_penalty_up)
        end
        # cost for decreasing flexible load
        if !isnothing(demand_flexibility.cost_dn)
            bus_demand_flex_cost_dn = permutedims(
                Matrix(
                    demand_flexibility.cost_dn[start_index:end_index, 2:end]
                )
            )
            demand_response_penalty_dn = JuMP.@expression(
                m, sum(sum(bus_demand_flex_cost_dn .* m[:load_shift_dn]))
            )
            JuMP.add_to_expression!(obj, demand_response_penalty_dn)
        end
    end
    # Finally, set as objective of model
    JuMP.@objective(m, Min, obj)
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
    storage_e0::Array{Float64,1}=Float64[],
    init_shifted_demand::Array{Float64,1}=Float64[]
)::JuMP.Model
    # Positional indices from mpc.gen
    PMAX = 9
    PMIN = 10
    println("building sets: ", Dates.now())
    # Sets - time periods
    hour_idx = 1:interval_length
    end_index = start_index + interval_length - 1
    # Sets - static
    sets = _make_sets(case, storage, demand_flexibility)
    println("parameters: ", Dates.now())
    # Parameters
    bus_demand = _make_bus_demand(case, start_index, end_index) * demand_scaling
    # Demand flexibility parameters (if present)
    if demand_flexibility.enabled
        (
            bus_demand_flex_amt_up, 
            bus_demand_flex_amt_dn,
        ) = _make_bus_demand_flexibility_amount(
            case, demand_flexibility, start_index, end_index
        )
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
    if storage.enabled
        storage_max_dis = storage.gen[:, PMAX]
        storage_max_chg = -1 * storage.gen[:, PMIN]
        storage_min_energy = storage.sd_table.MinStorageLevel
        storage_max_energy = storage.sd_table.MaxStorageLevel
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
            0 <= load_shift_dn[i in 1:sets.num_flexible_bus, j in 1:interval_length]
                <= bus_demand_flex_amt_dn[i, j],
        )
        # The amount of demand that is added from the base load
        JuMP.@variable(
            m,
            0 <= load_shift_up[i in 1:sets.num_flexible_bus, j in 1:interval_length]
                <= bus_demand_flex_amt_up[i, j],
        )
    end

    println("constraints: ", Dates.now())
    # Constraints

    println("powerbalance: ", Dates.now())
    _add_constraint_power_balance!(
        m, case, sets, storage, demand_flexibility, bus_demand, load_shed_enabled,
    )

    if load_shed_enabled
        _add_constraint_load_shed!(m, case, sets, demand_flexibility, bus_demand)
    end

    if storage.enabled
        _add_constraints_storage_operation!(
            m, case, sets, storage, interval_length, storage_e0
        )
    end

    if demand_flexibility.enabled
        _add_constraints_demand_flexibility!(
            m, case, sets, demand_flexibility, interval_length
        )
    end

    if initial_ramp_enabled
        _add_constraints_initial_ramping!(m, case, sets, initial_ramp_g0)
    end
    if length(hour_idx) > 1
        _add_constraints_ramping!(m, case, sets, interval_length)
    end

    _add_constraints_generator_segments!(m, case, sets, hour_idx)

    _add_constraints_branch_flow_limits!(m, case, sets, trans_viol_enabled, hour_idx)

    println("branch_angle: ", Dates.now())
    _add_branch_angle_constraints!(m, case, sets, hour_idx)

    # Constrain variable generators based on profiles
    _add_profile_generator_limits!(m, case, sets, hour_idx, start_index, interval_length)

    println("objective: ", Dates.now())
    _add_objective_function!(
        m,
        case,
        sets,
        storage,
        start_index, 
        end_index,
        interval_length,
        load_shed_enabled,
        load_shed_penalty,
        trans_viol_enabled,
        storage_e0,
        demand_flexibility,
    )

    println(Dates.now())
    return m
end
