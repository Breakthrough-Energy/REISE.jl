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
    storage = Dict("gen" => zeros(0, 21), "sd_table" => DataFrames.DataFrame())
    try
        case_storage_file = MAT.matopen(joinpath(filepath, "case_storage.mat"))
        storage_mat_data = read(case_storage_file, "storage")
        println("...loading case_storage.mat")
        # Convert N x 1 array of strings into 1D array of Symbols (length N)
        column_symbols = Symbol.(vec(storage_mat_data["sd_table"]["colnames"]))
        storage = Dict(
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
end
