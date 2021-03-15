"""
    get_results(model)

Extract the results of a simulation, store in a struct.
"""
function get_results(f::Float64, voi::VariablesOfInterest, case::Case)::Results
    status = "OPTIMAL"
    sets = _make_sets(case)
    # These variables will always be in the results
    pg = JuMP.value.(voi.pg)
    pf = JuMP.value.(voi.pf)
    lmp = -1 * JuMP.shadow_price.(voi.powerbalance)
    congl_temp = -1 * JuMP.shadow_price.(voi.branch_min)
    congu_temp = -1 * JuMP.shadow_price.(voi.branch_max)
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
    for i in intersect(Set(sets.noninf_branch_idx), Set(1:sets.num_branch_ac))
        congl[i, :] = congl_temp[i, :]
        congu[i, :] = congu_temp[i, :]
    end
    # These variables will only be in the results if the model has storage
    # Initialize with empty arrays, to be discarded later if they stay empty
    storage_pg = zeros(0, 0)
    storage_e = zeros(0, 0)
    try
        storage_dis = JuMP.value.(voi.storage_dis)
        storage_chg = JuMP.value.(voi.storage_chg)
        storage_e = JuMP.value.(voi.storage_soc)
        storage_pg = storage_dis - storage_chg
    catch e
        if isa(e, MethodError)
            # Thrown when storage variables are `nothing`
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end
    
    # This variable will only be in the results if load shedding is enabled
    # Initialize with empty arrays, to be discarded later if they stay empty
    load_shed = zeros(0, 0)
    try
        load_shed_temp = JuMP.value.(voi.load_shed)
        load_bus_map = sparse(sets.load_bus_idx, 1:sets.num_load_bus, 1,
                              sets.num_bus, sets.num_load_bus)
        load_shed = load_bus_map * load_shed_temp
    catch e
        if isa(e, MethodError)
            # Thrown when load_shed is `nothing`
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    # These variables will only be in the results if the model has flexible demand
    # Initialize with empty arrays, to be discarded later if they stay empty
    load_shift = zeros(0, 0)
    try
        load_shift_temp = JuMP.value.(voi.load_shift)
        load_bus_map = sparse(
            sets.load_bus_idx, 1:sets.num_load_bus, 1, sets.num_bus, sets.num_load_bus
        )
        load_shift = load_bus_map * load_shift_temp
    catch e
        if isa(e, MethodError)
            # Thrown when storage variables are `nothing`
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end

    results = Results(;
        pg=pg, pf=pf, lmp=lmp, congl=congl, congu=congu, pf_dcline=pf_dcline,
        f=f, storage_pg=storage_pg, storage_e=storage_e, load_shed=load_shed,
        load_shift=load_shift, status=status)
    return results
end
