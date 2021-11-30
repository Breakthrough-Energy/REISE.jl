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
    dcline_pmin::Array{Float64,1}
    dcline_pmax::Array{Float64,1}

    busid::Array{Int64,1}
    bus_demand::Array{Float64,1}
    bus_zone::Array{Int64,1}

    genid::Array{Int64,1}
    genfuel::Array{String,1}
    gen_bus::Array{Int64,1}
    gen_status::BitArray{1}
    gen_pmax::Array{Float64,1}
    gen_pmin::Array{Float64,1}
    gen_ramp30::Array{Float64,1}

    gencost::Array{Float64,2}
    gencost_orig::Array{Float64,2}

    demand::DataFrames.DataFrame
    hydro::DataFrames.DataFrame
    wind::DataFrames.DataFrame
    solar::DataFrames.DataFrame
end

Base.@kwdef struct Storage
    enabled::Bool
    gen::Array{Float64,2}
    sd_table::DataFrames.DataFrame
end

Base.@kwdef struct DemandFlexibility
    flex_amt_up::Union{DataFrames.DataFrame,Nothing}
    flex_amt_dn::Union{DataFrames.DataFrame,Nothing}
    cost_dn::Union{DataFrames.DataFrame,Nothing}
    cost_up::Union{DataFrames.DataFrame,Nothing}
    duration::Int64
    enabled::Bool
    interval_balance::Bool
    rolling_balance::Bool
    input_granularity::String
end

Base.@kwdef struct Results
    # We create a struct to hold case results in a type-declared format
    pg::Array{Float64,2}
    pf::Array{Float64,2}
    lmp::Array{Float64,2}
    congu::Array{Float64,2}
    congl::Array{Float64,2}
    pf_dcline::Array{Float64,2}
    storage_pg::Array{Float64,2}
    storage_e::Array{Float64,2}
    load_shed::Array{Float64,2}
    load_shift_up::Array{Float64,2}
    load_shift_dn::Array{Float64,2}
    trans_viol::Array{Float64,2}
    f::Float64
    status::String
end

Base.@kwdef struct Sets
    # Branch and branch subsets
    num_branch::Int64
    num_branch_ac::Int64
    branch_idx::UnitRange{Int64}
    noninf_branch_idx::Array{Int64,1}
    branch_to_idx::Array{Int64,1}
    branch_from_idx::Array{Int64,1}
    # Bus & bus subsets
    num_bus::Int64
    num_load_bus::Int64
    bus_idx::UnitRange{Int64}
    load_bus_idx::Array{Int64,1}
    bus_id2idx::Dict{Int64,Int64}
    load_bus_map::SparseMatrixCSC{Int64,Int64}
    # Gen & gen sub-sets
    num_gen::Int64
    num_wind::Int64
    num_solar::Int64
    num_hydro::Int64
    gen_idx::UnitRange{Int64}
    gen_wind_idx::Array{Int64,1}
    gen_solar_idx::Array{Int64,1}
    gen_hydro_idx::Array{Int64,1}
    renewable_idx::Array{Int64,1}
    noninf_pmax::Array{Int64,1}
    # Segments
    num_segments::Int64
    segment_idx::UnitRange{Int64}
    ## Demand Flexibility
    flexible_bus_idx::Union{Array{Int64,1},Nothing}
    num_flexible_bus::Int64
    flexible_load_bus_map::Union{SparseMatrixCSC,Nothing}
    # Storage
    num_storage::Int64
    storage_idx::Union{UnitRange{Int64},Nothing}
end
