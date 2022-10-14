"""
    reise_data_mods(case)

Given a dictionary of input data, modify accordingly and return a Case object.
"""
function reise_data_mods(case::Dict)::Case
    # Take in a dict from source data, tweak values and return a Case struct.

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
