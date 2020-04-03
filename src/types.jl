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

    gencost::Array{Float64,2}
    gencost_orig::Array{Float64,2}

    demand::DataFrames.DataFrame
    hydro::DataFrames.DataFrame
    wind::DataFrames.DataFrame
    solar::DataFrames.DataFrame
end


Base.@kwdef struct Storage
    gen::Array{Float64,2}
    sd_table::DataFrames.DataFrame
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
    f::Float64
    status::JuMP.MOI.TerminationStatusCode
end
