module reise

import CSV
import DataFrames
import Dates
import JLD
import JuMP
import GLPK
import Gurobi
import LinearAlgebra: transpose
import MAT
import SparseArrays: sparse, SparseMatrixCSC


Base.@kwdef struct Case
    # We create a struct to hold case data in a type-declared format
    # `Base.@kwdef` allows us to instantiate this via keywords

    branchid::Array{Int64,1}
    branch_from::Array{Int64,1}
    branch_to::Array{Int64,1}
    branch_reactance::Array{Float64,1}
    branch_rating::Array{Float64,1}

    dclineid::Array{Int64,1}
    dcline_from::Array{Int64,1}
    dcline_to::Array{Int64,1}
    dcline_rating::Array{Float64,1}

    busid::Array{Int64,1}
    bus_demand::Array{Float64,1}
    bus_zone::Array{Int64,1}

    genid::Array{Int64,1}
    genfuel::Array{String,1}
    gen_bus::Array{Int64,1}
    gen_pmax::Array{Float64,1}
    gen_pmin::Array{Float64,1}
    gen_ramp30::Array{Float64,1}

    gen_c2::Array{Float64,1}
    gen_c1::Array{Float64,1}
    gen_c0::Array{Float64,1}

    gen_a_new::Array{Float64,1}
    gen_b_new::Array{Float64,1}

    demand::DataFrames.DataFrame
    hydro::DataFrames.DataFrame
    wind::DataFrames.DataFrame
    solar::DataFrames.DataFrame
end


Base.@kwdef struct Results
    # We create a struct to hold case results in a type-declared format
    pg::Array{Float64,2}
    pf::Array{Float64,2}
    lmp::Array{Float64,2}
    congu::Array{Float64,2}
    congl::Array{Float64,2}
    f::Float64
end


"""Given a Results object and a filename, save a matfile with results data."""
function save_results(results::Results, filename::String)
    mdo_save = Dict(
        "results" => Dict("f" => results.f),
        "demand_scaling" => 1.,
        "flow" => Dict("mpc" => Dict(
            "bus" => Dict("LAM_P" => results.lmp),
            "gen" => Dict("PG" => results.pg),
            "branch" => Dict(
                "PF" => results.pf,
                # Note: check that these aren't swapped
                "MU_SF" => results.congu,
                "MU_ST" => results.congl,
                ),
            )),
        )
    MAT.matwrite(filename, Dict("mdo_save" => mdo_save))
end


"""Read REISE input matfiles, return parsed relevant data in a Dict."""
function read_case()
    # Read files from current working directory, return a dict

    print("reading")
    # Read case.mat
    case_mat_file = MAT.matopen("case.mat")
    mpc = read(case_mat_file, "mpc")

    # New case.mat analog
    case = Dict()

    # AC branches
    # dropdims() will remove extraneous dimension
    case["branchid"] = dropdims(mpc["branchid"], dims=2)
    # convert() will convert float array to int array
    case["branch_from"] = convert(Array{Int,1}, mpc["branch"][:,1])
    case["branch_to"] = convert(Array{Int,1}, mpc["branch"][:,2])
    case["branch_reactance"] = mpc["branch"][:,4]
    case["branch_rating"] = mpc["branch"][:,6]

    # DC branches
    if MAT.exists(case_mat_file, "dcline")
        case["dclineid"] = dropdims(mpc["dclineid"], dims=2)
        case["dcline_from"] = convert(Array{Int,1}, mpc["dcline"][:,1])
        case["dcline_to"] = convert(Array{Int,1}, mpc["dcline"][:,2])
        case["dcline_rating"] = mpc["dcline"][:,11]
    else
        case["dclineid"] = Int64[]
        case["dcline_from"] = Int64[]
        case["dcline_to"] = Int64[]
        case["dcline_rating"] = Float64[]
    end

    # Buses
    case["busid"] = convert(Array{Int,1}, mpc["bus"][:,1])
    case["bus_demand"] = mpc["bus"][:,3]
    case["bus_zone"] = convert(Array{Int,1}, mpc["bus"][:,7])

    # Generators
    case["genid"] = dropdims(mpc["genid"], dims=2)
    genfuel = dropdims(mpc["genfuel"], dims=2)
    case["genfuel"] = convert(Array{String,1}, genfuel)
    case["gen_bus"] = convert(Array{Int,1}, mpc["gen"][:,1])
    case["gen_pmax"] = mpc["gen"][:,9]
    case["gen_pmin"] = mpc["gen"][:,10]
    case["gen_ramp30"] = mpc["gen"][:,19]

    # Generator costs
    case["gen_c2"] = mpc["gencost"][:,5]
    case["gen_c1"] = mpc["gencost"][:,6]
    case["gen_c0"] = mpc["gencost"][:,7]

    # Load all relevant profile data from CSV files
    case["demand"] = CSV.File("demand.csv") |> DataFrames.DataFrame
    case["hydro"] = CSV.File("hydro.csv") |> DataFrames.DataFrame
    case["wind"] = CSV.File("wind.csv") |> DataFrames.DataFrame
    case["solar"] = CSV.File("solar.csv") |> DataFrames.DataFrame

    return case
end


"""
    reise_data_mods(case)

Given a dictionary of input data, modify accordingly and return a Case object.
"""
function reise_data_mods(case::Dict)::Case
    # Take in a dict from source data, tweak values and return a Case struct.

    # Modify PMINs
    case["gen_pmin"][case["genfuel"] .!= "coal"] .= 0
    nuclear_idx = case["genfuel"] .== "nuclear"
    case["gen_pmin"][nuclear_idx] = 0.95 * (case["gen_pmax"][nuclear_idx])
    geo_idx = case["genfuel"] .== "geothermal"
    case["gen_pmin"][geo_idx] = 0.95 * (case["gen_pmax"][geo_idx])

    # convert 'ax^2 + bx + c' to single-segment 'ax + b'
    case["gen_a_new"] = (
        case["gen_c2"] .* (case["gen_pmax"] .+ case["gen_pmin"])
        .+ case["gen_c1"])
    case["gen_b_new"] = (
        case["gen_c0"]
        .- case["gen_c2"] .* case["gen_pmax"] .* case["gen_pmin"])

    # Relax ramp constraints
    case["gen_ramp30"] .= Inf
    # Then set them based on capacity
    ramp30_points = Dict(
        "coal" => Dict("xs" => (200, 1400), "ys" => (0.4, 0.15)),
        "dfo" => Dict("xs" => (200, 1200), "ys" => (0.5, 0.2)),
        "ng" => Dict("xs" => (200, 600), "ys" => (0.5, 0.2)),
        )
    for (fuel, points) in ramp30_points
        fuel_idx = findall(case["genfuel"] .== fuel)
        slope = (
            (points["ys"][2] - points["ys"][1])
            / (points["xs"][2] - points["xs"][1]))
        intercept = points["ys"][1] - slope * points["xs"][1]
        for idx in fuel_idx
            norm_ramp = case["gen_pmax"][idx] * slope + intercept
            if case["gen_pmax"][idx] < points["xs"][1]
                norm_ramp = points["ys"][1]
            end
            if case["gen_pmax"][idx] > points["xs"][2]
                norm_ramp = points["ys"][2]
            end
            case["gen_ramp30"][idx] = norm_ramp * case["gen_pmax"][idx]
        end
    end

    # Convert Dict to NamedTuple
    case = (; (Symbol(k) => v for (k,v) in case)...)
    # Convert NamedTuple to Case
    case = Case(; case...)

    return case
end


"""
    make_gen_map(case)

Given a Case object, build a sparse matrix representing generator topology.
"""
function make_gen_map(case::Case)::SparseMatrixCSC
    # Create generator topology matrix

    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    gen_bus_idx = [bus_id2idx[b] for b in case.gen_bus]
    gen_map = sparse(gen_bus_idx, gen_idx, 1)
    return gen_map
end


"""
    make_branch_map(case)

Given a Case object, build a sparse matrix representing branch topology.
"""
function make_branch_map(case::Case)::SparseMatrixCSC
    # Create branch topology matrix

    branch_ac_name = ["l" * string(b) for b in case.branchid]
    branch_dc_name = ["d" * string(d) for d in case.dclineid]
    branch_name = vcat(branch_ac_name, branch_dc_name)
    num_branch = length(branch_name)
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
    build_model(case=case, start_index=x, interval_length=y[, kwargs...])

Given a Case object and a set of options, build an optimization model.
Returns a JuMP.Model instance.
"""
function build_model(; case::Case, start_index::Int, interval_length::Int,
                     load_shed_enabled::Bool=false,
                     load_shed_penalty::Number=9000,
                     trans_viol_enabled::Bool=false,
                     trans_viol_penalty::Number=100)::JuMP.Model
    # Build an optimization model from a Case struct

    println("building sets: ", Dates.now())
    # Sets
    bus_name = ["b" * string(b) for b in case.busid]
    num_bus = length(case.busid)
    bus_idx = 1:num_bus
    bus_id2idx = Dict(case.busid .=> bus_idx)
    branch_ac_name = ["l" * string(b) for b in case.branchid]
    branch_dc_name = ["d" * string(d) for d in case.dclineid]
    branch_name = vcat(branch_ac_name, branch_dc_name)
    branch_rating = vcat(case.branch_rating, case.dcline_rating)
    branch_rating[branch_rating .== 0] .= Inf
    num_branch = length(branch_name)
    branch_idx = 1:num_branch
    num_branch_ac = length(case.branchid)
    branch_ac_idx = 1:num_branch_ac
    gen_name = ["g" * string(g) for g in case.genid]
    num_gen = length(case.genid)
    gen_idx = 1:num_gen
    end_index = start_index+interval_length-1
    hour_name = ["h" * string(h) for h in range(start_index, stop=end_index)]
    num_hour = length(hour_name)
    hour_idx = 1:num_hour
    # Subsets
    gen_wind_idx = gen_idx[findall(case.genfuel .== "wind")]
    gen_solar_idx = gen_idx[findall(case.genfuel .== "solar")]
    gen_hydro_idx = gen_idx[findall(case.genfuel .== "hydro")]
    renewable_idx = sort(vcat(gen_wind_idx, gen_solar_idx, gen_hydro_idx))
    case.gen_pmax[renewable_idx] .= Inf
    num_wind = length(gen_wind_idx)
    num_solar = length(gen_solar_idx)
    num_hydro = length(gen_hydro_idx)

    println("parameters: ", Dates.now())
    # Parameters
    # Generator topology matrix
    gen_map = make_gen_map(case)
    hydro_map = sparse(1:num_hydro, case.gen_bus[gen_hydro_idx], 1)
    solar_map = sparse(1:num_solar, case.gen_bus[gen_solar_idx], 1)
    wind_map = sparse(1:num_wind, case.gen_bus[gen_wind_idx], 1)
    # Branch connectivity matrix
    all_branch_to = vcat(case.branch_to, case.dcline_to)
    all_branch_from = vcat(case.branch_from, case.dcline_from)
    branch_to_idx = Int64[bus_id2idx[b] for b in all_branch_to]
    branch_from_idx = Int64[bus_id2idx[b] for b in all_branch_from]
    branch_map = make_branch_map(case)
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
    simulation_hydro = Matrix(case.hydro[start_index:end_index, 2:end])
    simulation_solar = Matrix(case.solar[start_index:end_index, 2:end])
    simulation_wind = Matrix(case.wind[start_index:end_index, 2:end])

    # Model
    m = JuMP.Model()

    println("variables: ", Dates.now())
    # Variables
    # Explicitly defined as 1:x so that JuMP Array, not DenseArrayAxis
    JuMP.@variable(m, pg[1:num_gen,1:num_hour] >= 0)
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

    println("constraints: ", Dates.now())
    # Constraints

    println("powerbalance: ", Dates.now())
    if load_shed_enabled
        JuMP.@constraint(m, powerbalance, (
            gen_map * pg + branch_map * pf + load_shed .== bus_demand))
    else
        JuMP.@constraint(m, powerbalance, (
            gen_map * pg + branch_map * pf .== bus_demand))
    end
    println("powerbalance, setting names: ", Dates.now())
    for i in 1:num_bus, j in 1:num_hour
        JuMP.set_name(powerbalance[i,j],
                      "powerbalance[" * string(i) * "," * string(j) * "]")
    end

    if length(hour_idx) > 1
        println("rampup: ", Dates.now())
        noninf_ramp_idx = findall(case.gen_ramp30 .!= Inf)
        JuMP.@constraint(m, rampup[i = noninf_ramp_idx, h = 1:(num_hour-1)], (
            pg[i,h+1] - pg[i,h] <= case.gen_ramp30[i] * 2)
            )
        println("rampdown: ", Dates.now())
        JuMP.@constraint(m, rampdown[i = noninf_ramp_idx, h = 1:(num_hour-1)],
            case.gen_ramp30[i] * -2 <= pg[i, h+1] - pg[i, h]
            )
    end

    println("gen_min: ", Dates.now())
    # Use this!
    #JuMP.@constraint(m, gen_min[i = 1:num_gen,h = 1:num_hour], (
    #    pg[i, h] >= case.gen_pmin[i]))
    # Or this!
    JuMP.@constraint(m, gen_min, pg .>= case.gen_pmin)
    # Do NOT use this! (bad broadcasting, extremely slow)
    #JuMP.@constraint(m, gen_min[1:num_gen,1:num_hour], pg .>= case.gen_pmin)

    println("gen_max: ", Dates.now())
    noninf_pmax = findall(case.gen_pmax .!= Inf)
    JuMP.@constraint(m, gen_max[i = noninf_pmax, h = hour_idx], (
        pg[i, h] <= case.gen_pmax[i]))

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
    reshaped_case_gen_a_new = reshape(
        case.gen_a_new, (1, num_gen))::Array{Float64,2}
    # Start with generator variable O & M
    obj = JuMP.@expression(m, sum(reshaped_case_gen_a_new * pg))
    # Add no-load costs
    JuMP.add_to_expression!(
        obj, JuMP.@expression(m, num_hour * sum(case.gen_b_new)))
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
    # Finally, set as objective of model
    JuMP.@objective(m, Min, obj)

    println(Dates.now())
    return m
end


"""Build and solve a model using a given Gurobi env."""
function build_and_solve(
        m_kwargs::Dict, s_kwargs::Dict, env::Gurobi.Env)::Results
    # Solve using a Gurobi Env
    # Convert Dicts to NamedTuples
    m_kwargs = (; (Symbol(k) => v for (k,v) in m_kwargs)...)
    s_kwargs = (; (Symbol(k) => v for (k,v) in s_kwargs)...)
    m = build_model(; m_kwargs...)
    JuMP.optimize!(
        m, JuMP.with_optimizer(Gurobi.Optimizer, env; s_kwargs...))
end


"""Build and solve a model using GLPK."""
function build_and_solve(
        m_kwargs::Dict, s_kwargs::Dict)::Results
    # Solve using GLPK
    # Convert Dicts to NamedTuples
    m_kwargs = (; (Symbol(k) => v for (k,v) in m_kwargs)...)
    s_kwargs = (; (Symbol(k) => v for (k,v) in s_kwargs)...)
    m = build_model(; m_kwargs...)
    JuMP.optimize!(m, JuMP.with_optimizer(GLPK.Optimizer; s_kwargs...))
end


"""
    get_results(model)

Extract the results of a simulation, store in a struct.
"""
function get_results(m::JuMP.Model)::Results
    pg = get_2d_variable_values(m, "pg")
    pf = get_2d_variable_values(m, "pf")
    lmp = -1 * get_2d_constraint_duals(m, "powerbalance")
    congl = -1 * get_2d_constraint_duals(m, "branch_min")
    congu = -1 * get_2d_constraint_duals(m, "branch_max")
    f = JuMP.objective_value(m)

    results = Results(; pg=pg, pf=pf, lmp=lmp, congl=congl, congu=congu, f=f)
    return results
end


"""
    get_2d_variable_values(m, "pg")

Get the values of the variables whose names begin with a given string.
Returns a 2d array of values, shape inferred from the last variable's name.
"""
function get_2d_variable_values(m::JuMP.Model, s::String)::Array{Float64,2}
    function stringmatch(s::String, v::JuMP.VariableRef)
        occursin(s, JuMP.name(v))
    end
    vars = JuMP.all_variables(m)
    match_idxs = stringmatch.(s, vars)::BitArray{1}
    match_vars = vars[match_idxs]::Array{JuMP.VariableRef,1}
    dim_strs = match(r"\[(\d+),(\d+)\]", JuMP.name(match_vars[end])).captures
    dims = tuple([parse(Int,s) for s in dim_strs]...)::Tuple{Int64,Int64}
    match_vars = reshape(match_vars, dims)
    match_vars = JuMP.value.(match_vars)
    return match_vars
end


"""
    get_2d_constraint_duals(m, "powerbalance")

Get the duals of the constraints whose names begin with a given string.
Returns a 2d array of values, shape inferred from the last constraints's name.
"""
function get_2d_constraint_duals(m::JuMP.Model, s::String)::Array{Float64,2}
    function stringmatch(s::String, v::JuMP.ConstraintRef)
        occursin(s, JuMP.name(v))
    end
    lt = JuMP.all_constraints(m, JuMP.AffExpr, JuMP.MOI.LessThan{Float64})
    eq = JuMP.all_constraints(m, JuMP.AffExpr, JuMP.MOI.EqualTo{Float64})
    gt = JuMP.all_constraints(m, JuMP.AffExpr, JuMP.MOI.GreaterThan{Float64})
    cons = [lt; eq; gt]
    match_idxs = stringmatch.(s, cons)::BitArray{1}
    match_cons = cons[match_idxs]::Array{
        JuMP.ConstraintRef{JuMP.Model,_A,JuMP.ScalarShape} where _A,1}
    dim_strs = match(r"\[(\d+),(\d+)\]", JuMP.name(match_cons[end])).captures
    dims = tuple([parse(Int,s) for s in dim_strs]...)::Tuple{Int64,Int64}
    match_cons = reshape(match_cons, (:, dims[2]))
    match_cons = JuMP.shadow_price.(match_cons)
    return match_cons
end


"""Run a single simulation, setting up & shutting down as necessary."""
function build_and_solve_and_cleanup(solver_name;
                                     m_kwargs::Dict, s_kwargs::Dict)
    if solver_name == "gurobi"
        env = Gurobi.Env()
        build_and_solve(m_kwargs, s_kwargs, env)
        GC.gc()
        Gurobi.free_env(env)
    elseif solver_name == "glpk"
        build_and_solve(m_kwargs, s_kwargs)
    else
        throw(ArgumentError)
    end
end


# Module end
end
