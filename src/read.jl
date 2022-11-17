"""Read REISE input files, return parsed relevant data in a Case object."""
function read_case(filepath)
    println("Reading from folder: " * filepath)

    # New case.mat analog
    case = Dict()

    # AC branches
    branch = CSV.File(joinpath(filepath, "branch.csv"))
    case["branchid"] = convert(Array{Int,1}, branch.branch_id)
    case["branch_from"] = convert(Array{Int,1}, branch.from_bus_id)
    case["branch_to"] = convert(Array{Int,1}, branch.to_bus_id)
    case["branch_reactance"] = convert(Array{Float64,1}, branch.x)
    case["branch_rating"] = convert(Array{Float64,1}, branch.rateA)

    # DC branches
    dcline = CSV.File(joinpath(filepath, "dcline.csv"))
    case["dclineid"] = convert(Array{Int,1}, dcline.dcline_id)
    case["dcline_from"] = convert(Array{Int,1}, dcline.from_bus_id)
    case["dcline_to"] = convert(Array{Int,1}, dcline.to_bus_id)
    case["dcline_pmin"] = convert(Array{Float64,1}, dcline.Pmin)
    case["dcline_pmax"] = convert(Array{Float64,1}, dcline.Pmax)

    # Buses
    bus = CSV.File(joinpath(filepath, "bus.csv"))
    case["busid"] = convert(Array{Int,1}, bus.bus_id)
    case["bus_demand"] = convert(Array{Float64,1}, bus.Pd)
    case["bus_zone"] = convert(Array{Int,1}, bus.zone_id)
    try
        case["bus_eiaid"] = convert(Array{Int,1}, bus.eia_id)
    catch e
        case["bus_eiaid"] = zeros(size(case["busid"], 1), 1)
    end

    # Generators
    plant = CSV.File(joinpath(filepath, "plant.csv"))
    case["genid"] = convert(Array{Int,1}, plant.plant_id)
    case["genfuel"] = convert(Array{String,1}, plant.type)
    case["gen_bus"] = convert(Array{Int,1}, plant.bus_id)
    case["gen_status"] = convert(BitArray{1}, plant.status)
    case["gen_pmax"] = convert(Array{Float64,1}, plant.Pmax)
    case["gen_pmin"] = convert(Array{Float64,1}, plant.Pmin)
    case["gen_ramp30"] = convert(Array{Float64,1}, plant.ramp_30)

    # Generator immutables
    plant_immutables = JSON.parsefile(joinpath(filepath, "plant_immutables.json"))
    case["pmin_as_share_of_pmax"] = plant_immutables["pmin_as_share_of_pmax"]
    case["group_profile_resources"] = plant_immutables["group_profile_resources"]
    case["profile_resources"] = plant_immutables["profile_resources"]

    # Generator costs
    case["gencost_before"] = DataFrames.DataFrame(
        CSV.File(joinpath(filepath, "gencost_before.csv"))
    )
    case["gencost_after"] = DataFrames.DataFrame(
        CSV.File(joinpath(filepath, "gencost_after.csv"))
    )

    # Set the PMAX for all profile-based generators to Inf; the true PMAX for profile-
    # based generators will be determined by the provided profile
    for g in unique(case["genfuel"])
        gen_idx = case["genfuel"] .== g
        if g in case["profile_resources"]
            case["gen_pmax"][gen_idx] .= Inf
        end
    end

    # Load all relevant profile data from CSV files
    println("...loading demand.csv")
    case["demand"] = DataFrames.DataFrame(CSV.File(joinpath(filepath, "demand.csv")))

    println("...loading hydro.csv")
    case["hydro"] = DataFrames.DataFrame(CSV.File(joinpath(filepath, "hydro.csv")))

    println("...loading wind.csv")
    case["wind"] = DataFrames.DataFrame(CSV.File(joinpath(filepath, "wind.csv")))

    println("...loading solar.csv")
    case["solar"] = DataFrames.DataFrame(CSV.File(joinpath(filepath, "solar.csv")))

    # Convert Dict to NamedTuple
    case = (; (Symbol(k) => v for (k, v) in case)...)
    # Convert NamedTuple to Case
    case = Case(; case...)
    return case
end

"""Read input file (if present), return parsed data in a Storage struct."""
function read_storage(filepath)::Storage
    # Fallback dataframe, in case there's no input files
    storage = Dict(
        "enabled" => false, "gen" => zeros(0, 21), "sd_table" => DataFrames.DataFrame()
    )
    try
        println("...loading storage")
        gen = DataFrames.DataFrame(CSV.File(joinpath(filepath, "storage_gen.csv")))

        # Convert N x 1 array of strings into 1D array of Symbols (length N)
        data = DataFrames.DataFrame(CSV.File(joinpath(filepath, "StorageData.csv")))
        storage = Dict(
            "enabled" => true, "gen" => convert(Array{Float64,2}, gen), "sd_table" => data
        )
    catch
        println("Storage information not found in " * filepath)
    end

    # Convert Dict to NamedTuple
    storage = (; (Symbol(k) => v for (k, v) in storage)...)
    # Convert NamedTuple to Storage
    storage = Storage(; storage...)

    return storage
end

"""
    read_demand_flexibility(filepath, interval)

Load demand flexibility profiles and parameters from .csv files and return them in a 
DemandFlexibility struct.
"""
function read_demand_flexibility(filepath, interval)::DemandFlexibility
    # Initialize demand flexibility
    demand_flexibility = Dict(
        "duration" => interval,
        "enabled" => "not_specified",
        "interval_balance" => true,
        "rolling_balance" => true,
        "enable_doe_flexibility" => false,
    )

    # Try loading the demand flexibility parameters
    demand_flexibility_parameters = DataFrames.DataFrame()
    try
        demand_flexibility_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "demand_flexibility_parameters.csv"))
        )
        println("...loading demand flexibility parameters")

        # Create a dictionary to hold the warning messages relevant to loading the 
        # demand flexibility parameters
        demand_flexibility_params_warns = Dict(
            "duration" => (
                "The demand flexibility duration parameter is not defined. Will " *
                "default to being the size of the interval."
            ),
            "enabled" => (
                "The parameter that indicates if demand flexibility is enabled is not " *
                "defined. Will default to being enabled."
            ),
            "interval_balance" => (
                "The parameter that indicates if the interval load balance constraint " *
                "is enabled is not defined. Will default to being enabled."
            ),
            "rolling_balance" => (
                "The parameter that indicates if the rolling load balance constraint " *
                "is enabled is not defined. Will default to being enabled."
            ),
            "enable_doe_flexibility" => (
                "The parameter that indicates if the DOE flexibility data will be used" *
                " to parameterize demand flexibility profiles. Will default to disabled."
            ),
        )

        # Try assigning the different demand flexibility parameters from the file
        for k in keys(demand_flexibility_params_warns)
            try
                demand_flexibility[k] = demand_flexibility_parameters[1, k]
            catch
                println(demand_flexibility_params_warns[k])
            end
        end

    catch
        println("Demand flexibility parameters not found in " * filepath)
        println(
            "Demand flexibility parameters will default to allowing demand flexibility " *
            "to occur.",
        )
    end

    # Check the feasibility of the duration parameter
    if demand_flexibility["duration"] > interval
        @warn (
            "Demand flexibility durations greater than the interval length are " *
            "set equal to the interval length."
        )
        demand_flexibility["duration"] = interval
    end

    # Prevent the rolling_balance constraint according to the duration parameter
    demand_flexibility["rolling_balance"] &= !(demand_flexibility["duration"] == interval)

    # Try loading the demand flexibility and demand flexibility cost profiles
    for s in ["up", "dn"]
        # Pre-specify the demand flexibility and demand flexibility cost profiles
        demand_flexibility["flex_amt_" * s] = nothing
        demand_flexibility["cost_" * s] = nothing

        # Only try loading the profiles if demand flexibility is enabled
        if demand_flexibility["enabled"] == "not_specified" ||
            (demand_flexibility["enabled"])
            try
                demand_flexibility["flex_amt_" * s] = DataFrames.DataFrame(
                    CSV.File(joinpath(filepath, "demand_flexibility_" * s * ".csv"))
                )
                println("...loading demand flexibility " * s * " profiles")
                println(
                    "Flexibility profiles in user-provided csvs will overide " *
                    "DOE profiles for affected buses or load zones!",
                )
            catch e
                println("Demand flexibility " * s * " profile not found in " * filepath)
            end

            # Try loading the demand flexibility cost profiles
            try
                demand_flexibility["cost_" * s] = DataFrames.DataFrame(
                    CSV.File(joinpath(filepath, "demand_flexibility_cost_" * s * ".csv"))
                )
                println("...loading demand flexibility " * s * "-shift cost profiles")
            catch e
                println(
                    "Demand flexibility " *
                    s *
                    "-shift cost profiles not found in " *
                    filepath *
                    ". Will default to no cost for " *
                    s *
                    "-shifting demand.",
                )
            end
        end
    end

    # If demand flexibility is enabled but at least one demand flexibility profile is nothing
    if demand_flexibility["enabled"] == true &&
        (
            isnothing(demand_flexibility["flex_amt_up"]) ||
            (isnothing(demand_flexibility["flex_amt_dn"]))
        ) &&
        isnothing(demand_flexibility["doe_flex_amt"])
        throw(
            ErrorException(
                "Demand flexibility was specified to be enabled, however at " *
                "least one demand flexibility profile is missing. Please make sure both " *
                "demand flexibility profiles are included in " *
                filepath,
            ),
        )
    elseif demand_flexibility["enabled"] == "not_specified"
        if !isnothing(demand_flexibility["flex_amt_up"]) &&
           (!isnothing(demand_flexibility["flex_amt_dn"])) ||
            !isnothing(demand_flexibility["doe_flex_amt"])
            demand_flexibility["enabled"] = true
        else
            if !isnothing(demand_flexibility["flex_amt_up"]) ||
                (!isnothing(demand_flexibility["flex_amt_dn"]))
                @warn (
                    "The exclusion of one of the demand flexibility profiles has resulted " *
                    "in demand flexibility not being enabled."
                )
            end
            demand_flexibility["enabled"] = false
        end
    end

    # Try loading DOE flexibility profile if enabled
    demand_flexibility["doe_flex_amt"] = nothing
    if demand_flexibility["enable_doe_flexibility"] == true && demand_flexibility["enabled"]
        try
            # check if DOE data is present, if not, download from BLOB server
            if !isfile(joinpath(filepath, "doe_flexibility_2016.csv"))
                println(
                    "DOE flexibility data is enabled, but a local copy " *
                    "is not present. Downloading data from BLOB storage..",
                )
                @sync download(
                    "https://besciences.blob.core.windows.net/datasets/" *
                    "demand_flexibility_doe/doe_flexibility_2016.csv",
                    joinpath(filepath, "doe_flexibility_2016.csv"),
                )
                println("Successfully downloaded DOE flexibility file.")
            end
            # read local file
            demand_flexibility["doe_flex_amt"] = DataFrames.DataFrame(
                CSV.File(joinpath(filepath, "doe_flexibility_2016.csv"))
            )
            println("...loading DOE demand flexibility profiles")
        catch e
            println("DOE demand flexibility profile not found on BLOB storage")
        end
    end

    # Set the demand flexibility constraints to false if enabled is false
    if !demand_flexibility["enabled"]
        demand_flexibility["interval_balance"] = false
        demand_flexibility["rolling_balance"] = false
    end

    # Convert Dict to NamedTuple
    demand_flexibility = (; (Symbol(k) => v for (k, v) in demand_flexibility)...)

    # Convert NamedTuple to DemandFlexibility object
    demand_flexibility = DemandFlexibility(; demand_flexibility...)

    return demand_flexibility
end

"""
    _make_bus_demand_weighting(case)

Given a Case object, build a sparse matrix that indicates the weighting of each bus in 
    each zone.
"""
function _make_bus_demand_weighting(case::Case)::SparseMatrixCSC
    bus_idx = 1:length(case.busid)
    bus_df = DataFrames.DataFrame(;
        name=case.busid, load=case.bus_demand, zone=case.bus_zone
    )
    zone_demand = DataFrames.combine(DataFrames.groupby(bus_df, :zone), :load => sum)
    zone_list = sort(collect(Set(case.bus_zone)))
    zone_idx = 1:length(zone_list)
    zone_id2idx = Dict(zone_list .=> zone_idx)
    bus_df_with_zone_load = DataFrames.innerjoin(bus_df, zone_demand; on=:zone)
    bus_share = bus_df[:, :load] ./ bus_df_with_zone_load[:, :load_sum]
    bus_zone_idx = Int64[zone_id2idx[z] for z in case.bus_zone]
    zone_to_bus_shares = sparse(bus_zone_idx, bus_idx, bus_share)::SparseMatrixCSC
    return zone_to_bus_shares
end

"""
    reformat_demand_flexibility_input(case, demand_flexibility, sets)

Inspect the raw input files of flexiblility amount and cost, convert the zone/bus mixed 
    data to bus data
"""
function reformat_demand_flexibility_input(
    case::Case, demand_flexibility::DemandFlexibility, sets::Sets
)

    # check consistency of flexibility input headers
    if !all(
        sort(names(demand_flexibility.flex_amt_up)) .==
        sort(names(demand_flexibility.flex_amt_dn)),
    )
        throw(
            ErrorException(
                "The flexible bus/load zone specified in the up/down " *
                "input csvs do not match. Please check the input files to make sure " *
                "every flexible bus or load zone has corresponding columns in both " *
                "flexibility csvs.",
            ),
        )
    end

    # list of zones in the network
    zone_list = sort(collect(Set(case.bus_zone)))
    # distribute zone-level aggregated number to buses
    zone_to_bus_shares = _make_bus_demand_weighting(case)
    # incidence matrix of mapping between zone and bus
    zone_to_bus_incidence = deepcopy(zone_to_bus_shares)
    (x, y, v) = findnz(zone_to_bus_incidence)
    for i in 1:nnz(zone_to_bus_incidence)
        # buses with no load still show up as nonzero entries
        if v[i] > 0
            zone_to_bus_incidence[x[i], y[i]] = 1
        end
    end

    # create an empty demand flexibility object and copy unchanged fields
    demand_flexibility_updated = Dict(
        "duration" => demand_flexibility.duration,
        "enabled" => demand_flexibility.enabled,
        "interval_balance" => demand_flexibility.interval_balance,
        "rolling_balance" => demand_flexibility.rolling_balance,
        "flex_amt_up" => nothing,
        "flex_amt_dn" => nothing,
        "cost_up" => nothing,
        "cost_dn" => nothing,
        "doe_flex_amt" => nothing,
        "enable_doe_flexibility" => demand_flexibility.enable_doe_flexibility,
    )

    # iterate through fields
    for field in ["flex_amt_up", "flex_amt_dn", "cost_up", "cost_dn"]
        # dataframe in the corresponding field
        demand_flex_field = getfield(demand_flexibility, Symbol(field))

        # skip if no cost
        if isnothing(demand_flex_field)
            continue
        end

        # headers
        flexible_str = names(demand_flex_field)[2:end]

        # index of columns specifing the flexibility of a zone
        zone_columns_idx = findall(x -> occursin("zone.", x), flexible_str)

        # numeric ID corresponding to zone columns
        flexible_zone_id = [
            parse(Int64, replace(flexible_str[i], "zone." => "")) for i in zone_columns_idx
        ]
        flexible_zone_num = length(flexible_zone_id)

        # do zone-bus conversion only when zone columns are present
        if flexible_zone_num > 0

            # index of columns specifing the flexibility of a bus
            bus_columns_idx = findall(x -> !occursin(".", x), flexible_str)

            # numeric ID corresponding to bus columns
            flexible_bus_id = [parse(Int64, flexible_str[i]) for i in bus_columns_idx]
            flexible_bus_idx = [sets.bus_id2idx[x] for x in flexible_bus_id]
            flexible_bus_num = length(flexible_bus_id)

            # remove bus columns from zone to bus mapping
            zone_to_bus_shares[:, flexible_bus_idx] .= 0

            # re-normalize the rows to distribute flexiblity among un-specified buses
            for i in 1:length(zone_list)
                zone_to_bus_shares[i, :] ./= sum(zone_to_bus_shares[i, :])
            end

            # check if zone numbers are correct
            if !all([issubset(i, zone_list) for i in flexible_zone_id])
                throw(
                    ErrorException(
                        "Invalid load zone numeric ID(s) in demand flexibility input files!"
                    ),
                )
            elseif !all([issubset(i, case.busid) for i in flexible_bus_id])
                throw(
                    ErrorException(
                        "Invalid load bus numeric ID(s) in demand flexibility input files!"
                    ),
                )
            end

            # list index of each zone in input file in the sorted list of zones
            zone_cols_idx = [findfirst(y -> y == x, zone_list) for x in flexible_zone_id]

            # for flex amt, the zone numbers are the total flexibility in the zone
            if field == "flex_amt_up" || field == "flex_amt_dn"
                # if input contains bus columns
                if flexible_bus_num > 0
                    # find if the flexibility of any bus is also specified in a zone column
                    bus_cols_zone_id = case.bus_zone[findall(
                        x -> x in flexible_bus_id, case.busid
                    )]
                    bus_cols_zone_idx = [
                        findfirst(isequal(i), flexible_zone_id) for i in bus_cols_zone_id
                    ]

                    # substract individual bus columns from zone total flexibility
                    for i in 1:flexible_bus_num
                        # substract from total if the zone of this bus is specified in a zone column
                        if !isnothing(bus_cols_zone_idx[i])
                            demand_flex_field[:, zone_columns_idx[bus_cols_zone_idx[i]] + 1] -= demand_flex_field[
                                :, bus_columns_idx[i] + 1
                            ]
                        end
                    end

                    # check if flexibility in any zone is less than the sum of buses
                    for i in 1:flexible_zone_num
                        if any(
                            x -> x < 0,
                            demand_flex_field[:, zone_columns_idx[flexible_zone_num] + 1],
                        )
                            throw(
                                ErrorException(
                                    "Input ERROR: Total zone flexibility less than sum of bus
                       flexibility for zone " * string(flexible_zone_id[i]),
                                ),
                            )
                        end
                    end
                end

                # convert zone-level to bus-level
                converted_zone_flexibility =
                    Matrix(demand_flex_field[:, [i + 1 for i in zone_columns_idx]]) * zone_to_bus_shares[zone_cols_idx, :]

                # add bus-level columns on top of converted bus-level flexibility matrix
                flex_bus_idx = zeros(Int64, 0)
                for i in sets.bus_idx
                    bus = case.busid[i]
                    # add specified flexibility to the corresponding bus
                    if bus in flexible_bus_id
                        converted_zone_flexibility[:, i] += demand_flex_field[
                            !, string(bus)
                        ]
                    end

                    # identify flexible bus by their total flexibility and append to list
                    if any(x -> x > 0, converted_zone_flexibility[:, i])
                        append!(flex_bus_idx, i)
                    end
                end
                eq_bus_df = DataFrames.DataFrame(
                    converted_zone_flexibility[:, flex_bus_idx], :auto
                )
                # for cost, the zone numbers apply to all buses except those with dedicated columns
            else
                # convert zone-level cost using incidence matrix
                converted_zone_cost =
                    Matrix(demand_flex_field[:, [i + 1 for i in zone_columns_idx]]) * zone_to_bus_incidence[zone_cols_idx, :]

                # replace bus-level cost for bus columns in converted bus-level cost matrix
                flex_bus_idx = zeros(Int64, 0)
                for i in sets.bus_idx
                    bus = case.busid[i]
                    # add specified cost to the corresponding bus
                    if bus in flexible_bus_id
                        converted_zone_cost[:, i] = demand_flex_field[!, string(bus)]
                    end

                    # identify flexible bus by their total cost and append to list
                    if any(x -> x > 0, converted_zone_cost[:, i])
                        append!(flex_bus_idx, i)
                    end
                end

                # if DOE flexibility is used, add columns for flexible buses there

                # find all flexible buses
                if demand_flexibility.enable_doe_flexibility
                    doe_flexible_bus_idx = sort(
                        intersect(sets.load_bus_idx, findall(case.bus_eiaid .> 0))
                    )
                else
                    doe_flexible_bus_idx = nothing
                end

                # assume each flexible bus can go up/dn, so only use the Dataframe for up
                csv_flexible_bus_str = names(demand_flexibility_updated["flex_amt_up"])[2:end]
                csv_flexible_bus_id = [parse(Int64, bus) for bus in csv_flexible_bus_str]
                csv_flexible_bus_idx = [sets.bus_id2idx[bus] for bus in csv_flexible_bus_id]

                # all flexible buse
                if !isnothing(doe_flexible_bus_idx)
                    flex_bus_idx = sort([
                        i for i in union(doe_flexible_bus_idx, csv_flexible_bus_idx)
                    ])
                else
                    flex_bus_idx = sort(csv_flexible_bus_idx)
                end

                new_demand_flex_cost = zeros(size(converted_zone_cost, 1), sets.num_bus)
                for i in 1:length(flex_bus_idx)
                    new_demand_flex_cost[:, flex_bus_idx[i]] = converted_zone_cost[:, i]
                end

                eq_bus_df = DataFrames.DataFrame(
                    new_demand_flex_cost[:, flex_bus_idx], :auto
                )
            end

            # add header and datetime index column
            DataFrames.rename!(eq_bus_df, Symbol.(case.busid[flex_bus_idx]))
            DataFrames.insertcols!(
                eq_bus_df, 1, :"UTC Time" => demand_flex_field[!, "UTC Time"]
            )

            # store to new df object
            demand_flexibility_updated[field] = eq_bus_df

            # if all columns are buses, use the original dataframe
        else
            demand_flexibility_updated[field] = demand_flex_field
        end
    end

    # re-format DOE flexibility using bus EIA ID
    if demand_flexibility.enable_doe_flexibility == true
        demand_flex_field = getfield(demand_flexibility, Symbol("doe_flex_amt"))

        # all load buses with valid EIA ID 
        flexible_bus_idx = intersect(sets.load_bus_idx, findall(case.bus_eiaid .> 0))
        flexible_bus_num = length(flexible_bus_idx)

        # bus flexibility Percentage matrix
        doe_bus_flexibility = zeros(size(case.demand, 1), flexible_bus_num)
        for i in 1:flexible_bus_num
            doe_bus_flexibility[:, i] = demand_flex_field[
                !, Symbol(case.bus_eiaid[flexible_bus_idx[i]])
            ]
        end

        eq_bus_df = DataFrames.DataFrame(doe_bus_flexibility, :auto)
        # add header and datetime index column
        DataFrames.rename!(eq_bus_df, Symbol.(case.busid[flexible_bus_idx]))
        DataFrames.insertcols!(
            eq_bus_df, 1, :"UTC Time" => demand_flex_field[!, "UTC Time"]
        )

        # store to new df object
        demand_flexibility_updated["doe_flex_amt"] = eq_bus_df
    end

    # Convert Dict to type DemandFlexibility
    demand_flexibility_updated = (;
        (Symbol(k) => v for (k, v) in demand_flexibility_updated)...
    )
    demand_flexibility_updated = DemandFlexibility(; demand_flexibility_updated...)

    return demand_flexibility_updated
end
