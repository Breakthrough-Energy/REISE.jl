"""
    get_results(model, case)

Extract the results of a simulation, store in a struct.
"""
function get_results(f::Float64, case::Case, demand_flexibility::DemandFlexibility)::Results
    status = "OPTIMAL"
    sets = _make_sets(case; storage=nothing, demand_flexibility=demand_flexibility)
    # These variables will always be in the results
    pg = JuMP.value.(m[:pg])
    pf = JuMP.value.(m[:pf])
    lmp = -1 * JuMP.shadow_price.(m[:powerbalance])
    congl_temp = -1 * JuMP.shadow_price.(m[:branch_min])
    congu_temp = -1 * JuMP.shadow_price.(m[:branch_max])
    # If DC lines are present, separate their results
    # Initialize with empty arrays, to be discarded later if they stay empty
    pf_dcline = zeros(0, 0)
    num_dclines = length(case.dclineid)
    if num_dclines > 0
        pf_dcline = pf[(end - num_dclines + 1):end, :]
        pf = pf[1:(end - num_dclines), :]
    end
    # Ensure that we report congestion on all branches, even infinite capacity
    num_hour = size(pf, 2)
    congl = zeros(sets.num_branch_ac, num_hour)
    congu = zeros(sets.num_branch_ac, num_hour)
    # Access congl_temp via key `i`, then store result in congl at position `i`
    for i in intersect(Set(sets.noninf_branch_idx), Set(1:(sets.num_branch_ac)))
        congl[i, :] = congl_temp[i, :]
        congu[i, :] = congu_temp[i, :]
    end
    # These variables will only be in the results if the model has storage
    # Initialize with empty arrays, to be discarded later if they stay empty
    storage_pg = zeros(0, 0)
    storage_e = zeros(0, 0)
    try
        storage_dis = JuMP.value.(m[:storage_dis])
        storage_chg = JuMP.value.(m[:storage_chg])
        storage_e = JuMP.value.(m[:storage_soc])
        storage_pg = storage_dis - storage_chg
    catch e
        if isa(e, KeyError)
            # Thrown when storage variables are not defined in the model
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    # This variable will only be in the results if load shedding is enabled
    # Initialize with empty arrays, to be discarded later if they stay empty
    load_shed = zeros(0, 0)
    try
        load_shed_temp = JuMP.value.(m[:load_shed])
        load_shed = sets.load_bus_map * load_shed_temp
    catch e
        if isa(e, KeyError)
            # Thrown when load_shed is not defined in the model
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    # These variables will only be in the results if the model has flexible demand
    # Initialize with empty arrays, to be discarded later if they stay empty
    load_shift_up = zeros(0, 0)
    load_shift_dn = zeros(0, 0)
    try
        load_shift_up_temp = JuMP.value.(m[:load_shift_up])
        load_shift_dn_temp = JuMP.value.(m[:load_shift_dn])
        load_shift_up = sets.flexible_load_bus_map * load_shift_up_temp
        load_shift_dn = sets.flexible_load_bus_map * load_shift_dn_temp
    catch e
        if isa(e, KeyError)
            # Thrown when load shift variables are `nothing`
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    trans_viol = zeros(0, 0)
    try
        trans_viol = JuMP.value.(m[:trans_viol])
    catch e
        if isa(e, MethodError)
            # Thrown when trans_viol is `nothing`
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    results = Results(;
        pg=pg,
        pf=pf,
        lmp=lmp,
        congl=congl,
        congu=congu,
        pf_dcline=pf_dcline,
        f=f,
        storage_pg=storage_pg,
        storage_e=storage_e,
        load_shed=load_shed,
        load_shift_up=load_shift_up,
        load_shift_dn=load_shift_dn,
        status=status,
        trans_viol=trans_viol,
    )
    return results
end
