"""
    reise_data_mods(case)

Given a dictionary of input data, modify accordingly and return a Case object.
"""
function reise_data_mods(case::Dict; num_segments::Int=1)::Case
    # Take in a dict from source data, tweak values and return a Case struct.

    # Modify PMINs
    case["gen_pmin"][case["genfuel"] .!= "coal"] .= 0
    nuclear_idx = case["genfuel"] .== "nuclear"
    case["gen_pmin"][nuclear_idx] = 0.95 * (case["gen_pmax"][nuclear_idx])
    geo_idx = case["genfuel"] .== "geothermal"
    case["gen_pmin"][geo_idx] = 0.95 * (case["gen_pmax"][geo_idx])
    offstatus_idx = case["gen_status"] .== 0
    case["gen_pmin"][offstatus_idx] .= 0

    # Save original gencost to gencost_orig
    case["gencost_orig"] = copy(case["gencost"])
    # Modify gencost based on desired linearization structure
    case["gencost"] = _linearize_gencost(case; num_segments=num_segments)

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
        slope = ((points["ys"][2] - points["ys"][1]) / (points["xs"][2] - points["xs"][1]))
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
    case = (; (Symbol(k) => v for (k, v) in case)...)
    # Convert NamedTuple to Case
    case = Case(; case...)

    return case
end

"""
    _linearize_gencost(case)
    _linearize_gencost(case; num_segments=2)

Using case dict data, linearize cost curves with a give number of segments.
"""
function _linearize_gencost(case::Dict; num_segments::Int=1)::Array{Float64,2}
    # Positional indices from mpc.gencost
    MODEL = 1
    STARTUP = 2
    SHUTDOWN = 3
    NCOST = 4
    COST = 5

    println("linearizing")
    num_gens = size(case["gencost"], 1)
    non_polynomial = (case["gencost"][:, MODEL] .!= 2)::BitArray{1}
    if sum(non_polynomial) > 0
        throw(ArgumentError("gencost currently limited to polynomial"))
    end
    non_quadratic = (case["gencost"][:, NCOST] .!= 3)::BitArray{1}
    if sum(non_quadratic) > 0
        throw(ArgumentError("gencost currently limited to quadratic"))
    end
    old_a = case["gencost"][:, COST]
    old_b = case["gencost"][:, COST + 1]
    old_c = case["gencost"][:, COST + 2]
    diffP_mask = (case["gen_pmin"] .!= case["gen_pmax"])::BitArray{1}
    # Convert non-fixed generators to piecewise segments
    if sum(diffP_mask) > 0
        # If we are linearizing at least one generator, need to expand gencost
        gencost_width = 6 + 2 * num_segments
        new_gencost = zeros(num_gens, gencost_width)
        new_gencost[diffP_mask, MODEL] .= 1
        new_gencost[:, STARTUP:SHUTDOWN] = case["gencost"][:, STARTUP:SHUTDOWN]
        new_gencost[diffP_mask, NCOST] .= num_segments + 1
        power_step = (case["gen_pmax"] - case["gen_pmin"]) / num_segments
        for i in 0:num_segments
            x_index = COST + 2 * i
            y_index = COST + 1 + (2 * i)
            x_data = (case["gen_pmin"] + power_step * i)
            y_data = old_a .* x_data .^ 2 + old_b .* x_data + old_c
            new_gencost[diffP_mask, x_index] = x_data[diffP_mask]
            new_gencost[diffP_mask, y_index] = y_data[diffP_mask]
        end
    else
        # If we are not linearizing any segments, gencost can stay as is
        new_gencost = copy(case["gencost"])
    end
    # Convert fixed gens to fixed values
    sameP_mask = .!diffP_mask
    if sum(sameP_mask) > 0
        new_gencost[sameP_mask, MODEL] = case["gencost"][sameP_mask, MODEL]
        new_gencost[sameP_mask, NCOST] = case["gencost"][sameP_mask, NCOST]
        power = case["gen_pmax"]
        y_data = old_a .* power .^ 2 + old_b .* power + old_c
        new_gencost[sameP_mask, COST:(COST + 1)] .= 0
        new_gencost[sameP_mask, COST + 2] = y_data[sameP_mask]
    end

    return new_gencost
end
