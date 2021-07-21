"""Read REISE input matfiles, return parsed relevant data in a Dict."""
function read_case(filepath)
    println("Reading from folder: " * filepath)
    
    println("...loading case.mat")
    case_mat_file = MAT.matopen(joinpath(filepath, "case.mat"))
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
    if "dcline" in keys(mpc)
        if isa(mpc["dclineid"], Int)
            case["dclineid"] = Int64[mpc["dclineid"]]
        else
            case["dclineid"] = dropdims(mpc["dclineid"], dims=2)
        end
        case["dcline_from"] = convert(Array{Int,1}, mpc["dcline"][:,1])
        case["dcline_to"] = convert(Array{Int,1}, mpc["dcline"][:,2])
        case["dcline_pmin"] = mpc["dcline"][:,10]
        case["dcline_pmax"] = mpc["dcline"][:,11]
    else
        case["dclineid"] = Int64[]
        case["dcline_from"] = Int64[]
        case["dcline_to"] = Int64[]
        case["dcline_pmin"] = Float64[]
        case["dcline_pmax"] = Float64[]
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
    case["gen_status"] = mpc["gen"][:,8]
    case["gen_pmax"] = mpc["gen"][:,9]
    case["gen_pmin"] = mpc["gen"][:,10]
    case["gen_ramp30"] = mpc["gen"][:,19]

    # Generator costs
    case["gencost"] = mpc["gencost"]

    # Load all relevant profile data from CSV files
    println("...loading demand.csv")
    case["demand"] = CSV.File(joinpath(filepath, "demand.csv")) |> DataFrames.DataFrame
    
    println("...loading hydro.csv")
    case["hydro"] = CSV.File(joinpath(filepath, "hydro.csv")) |> DataFrames.DataFrame
    
    println("...loading wind.csv")
    case["wind"] = CSV.File(joinpath(filepath, "wind.csv")) |> DataFrames.DataFrame
    
    println("...loading solar.csv")
    case["solar"] = CSV.File(joinpath(filepath, "solar.csv")) |> DataFrames.DataFrame

    return case
end


"""Read input matfile (if present), return parsed data in a Storage struct."""
function read_storage(filepath)::Storage
    # Fallback dataframe, in case there's no case_storage.mat file
    storage = Dict(
        "enabled" => false, "gen" => zeros(0, 21), "sd_table" => DataFrames.DataFrame()
    )
    try
        case_storage_file = MAT.matopen(joinpath(filepath, "case_storage.mat"))
        storage_mat_data = read(case_storage_file, "storage")
        println("...loading case_storage.mat")
        # Convert N x 1 array of strings into 1D array of Symbols (length N)
        column_symbols = Symbol.(vec(storage_mat_data["sd_table"]["colnames"]))
        storage = Dict(
            "enabled" => true,
            "gen" => storage_mat_data["gen"],
            "sd_table" => DataFrames.DataFrame(
                storage_mat_data["sd_table"]["data"], column_symbols
                )
            )
    catch e
        println("File case_storage.mat not found in " * filepath)
    end

    # Convert Dict to NamedTuple
    storage = (; (Symbol(k) => v for (k,v) in storage)...)
    # Convert NamedTuple to Storage
    storage = Storage(; storage...)

    return storage
end


"""Load demand flexibility profile from .csv files into DataFrame(s)."""
function read_demand_flexibility(filepath, interval)::DemandFlexibility
    # Initialize demand flexibility
    demand_flexibility = Dict()

    # Try loading demand flexibility profiles. Otherwise, create a DataFrame of zeros
    try
        demand_flexibility["flex_amt"] = CSV.File(
            joinpath(filepath, "demand_flexibility.csv")
        ) |> DataFrames.DataFrame
        println("...loading demand flexibility profiles")
        demand_flexibility["enabled"] = true
    catch e
        println("Demand flexibility profiles not found in " * filepath)
        demand_flexibility["flex_amt"] = nothing
        demand_flexibility["enabled"] = false
        demand_flexibility["duration"] = nothing
        demand_flexibility["interval_balance"] = false
        demand_flexibility["rolling_balance"] = false
        demand_flexibility["cost_up"] = nothing
        demand_flexibility["cost_dn"] = nothing
    end

    # Set the demand flexibility costs and parameters
    if demand_flexibility["enabled"]
        # Pre-specify the demand flexibility parameters
        demand_flexibility["duration"] = nothing
        demand_flexibility["interval_balance"] = true
        demand_flexibility["rolling_balance"] = true

        # Try loading the demand flexibility parameters
        demand_flexibility_parameters = DataFrames.DataFrame()
        try
            demand_flexibility_parameters = CSV.File(
                joinpath(filepath, "demand_flexibility_parameters.csv")
            ) |> DataFrames.DataFrame
            println("...loading demand flexibility parameters")

            # Create a dictionary to hold the error messages relevant to loading the 
                # demand flexibility parameters
            demand_flexibility_params_errs = Dict()
            demand_flexibility_params_errs["duration"] = (
                "The demand flexibility duration parameter is not defined. Will "
                * "default to nothing."
            )
            demand_flexibility_params_errs["enabled"] = (
                "The parameter that indicates if demand flexibility is enabled is not "
                * "defined. Will default to being enabled."
            )
            demand_flexibility_params_errs["interval_balance"] = (
                "The parameter that indicates if the interval load balance constraint "
                * "is enabled is not defined. Will default to being enabled."
            )
            demand_flexibility_params_errs["rolling_balance"] = (
                "The parameter that indicates if the rolling load balance constraint "
                * "is enabled is not defined. Will default to being enabled."
            )

            # Try assigning the different demand flexibility parameters from the file
            for k in keys(demand_flexibility_params_errs)
                try
                    demand_flexibility[k] = demand_flexibility_parameters[1, k]
                catch e
                    println(demand_flexibility_params_errs[k])
                end
            end

            # Set the demand flexibility constraints to false if enabled is false
            if !demand_flexibility["enabled"]
                demand_flexibility["interval_balance"] = false
                demand_flexibility["rolling_balance"] = false
            end
        catch e
            println("Demand flexibility parameters not found in " * filepath)
            println(
                "Demand flexibility parameters will default to allowing demand "
                * "flexibility to occur."
            )
        end

        # Check the feasibility of the duration parameter
        if demand_flexibility["duration"] == nothing
            demand_flexibility["duration"] = interval
        elseif demand_flexibility["duration"] > interval
            @warn (
                "Demand flexibility durations greater than the interval length are "
                * "set equal to the interval length."
            )
            demand_flexibility["duration"] = interval
        end
        
        # Try reading the cost for up- and down-shifting loads
        for cost_file_suffix in ("up", "dn")
            try 
                demand_flexibility["cost_$cost_file_suffix"] = CSV.File(
                    joinpath(filepath, "demand_flexibility_cost_$cost_file_suffix.csv")
                ) |> DataFrames.DataFrame
                println("...loading demand flexibility $cost_file_suffix-shift cost profiles")
            catch e
                println(
                    "Demand flexibility down-shift cost profiles not found in " * filepath
                )
                demand_flexibility["cost_$cost_file_suffix"] = nothing
            end
        end
    end

    # Convert Dict to NamedTuple
    demand_flexibility = (; (Symbol(k) => v for (k,v) in demand_flexibility)...)

    # Convert NamedTuple to DemandFlexibility object
    demand_flexibility = DemandFlexibility(; demand_flexibility...)

    return demand_flexibility
end
