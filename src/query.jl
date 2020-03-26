"""
    get_results(model)

Extract the results of a simulation, store in a struct.
"""
function get_results(m::JuMP.Model, case::Case)::Results
    status = JuMP.termination_status(m)
    # These variables will always be in the results
    pg = _get_2d_variable_values(m, "pg")
    pf = _get_2d_variable_values(m, "pf")
    lmp = -1 * _get_2d_constraint_duals(m, "powerbalance")
    congl_temp = -1 * _get_2d_constraint_duals(m, "branch_min")
    congu_temp = -1 * _get_2d_constraint_duals(m, "branch_max")
    f = JuMP.objective_value(m)
    # Ensure that we report congestion on all branches, even infinite capacity
    num_branch = length(case.branchid) + length(case.dcline_rating)
    num_hour = size(pg, 2)
    congl = zeros(num_branch, num_hour)
    congu = zeros(num_branch, num_hour)
    branch_rating = vcat(case.branch_rating, case.dcline_rating)
    branch_rating[branch_rating .== 0] .= Inf
    noninf_branch_idx = findall(branch_rating .!= Inf)
    num_noninf = length(noninf_branch_idx)
    for i in 1:num_noninf
        congl[noninf_branch_idx[i], :] = congl_temp[i, :]
        congu[noninf_branch_idx[i], :] = congu_temp[i, :]
    end
    # These variables will only be in the results if the model has storage
    # Initialize with empty arrays, to be discarded later if they stay empty
    storage_pg = zeros(0, 0)
    storage_e = zeros(0, 0)
    try
        storage_dis = _get_2d_variable_values(m, "storage_dis")
        storage_chg = _get_2d_variable_values(m, "storage_chg")
        storage_pg = storage_dis - storage_chg
        storage_e = _get_2d_variable_values(m, "storage_soc")
    catch e
        if isa(e, BoundsError)
            # Thrown by _get_2d_variable_values, variable does not exist
        else
            # Unknown error, rethrow it
            rethrow(e)
        end
    end
    
    results = Results(;
        pg=pg, pf=pf, lmp=lmp, congl=congl, congu=congu, f=f,
        storage_pg=storage_pg, storage_e=storage_e, status=status)
    return results
end


"""
    _get_2d_variable_values(m, "pg")

Get the values of the variables whose names begin with a given string.
Returns a 2d array of values, shape inferred from the last variable's name.
"""
function _get_2d_variable_values(m::JuMP.Model, s::String)::Array{Float64,2}
    function stringmatch(s::String, v::JuMP.VariableRef)
        occursin(s * "[", JuMP.name(v))
    end
    vars = JuMP.all_variables(m)
    match_idxs = stringmatch.(s, vars)::BitArray{1}
    match_vars = vars[match_idxs]::Array{JuMP.VariableRef,1}
    # What do the indices of the first, second, and last look like?
    regex_str = r"\[(\d+),(\d+)\]"
    first_dim_strs = match(regex_str, JuMP.name(match_vars[1])).captures
    first_dims = Int64[parse(Int,s) for s in first_dim_strs]
    second_dim_strs = match(regex_str, JuMP.name(match_vars[2])).captures
    second_dims = Int64[parse(Int,s) for s in second_dim_strs]
    end_dim_strs = match(regex_str, JuMP.name(match_vars[end])).captures
    end_dims = Int64[parse(Int,s) for s in end_dim_strs]
    # Use our knowledge of the dims to appropriately reshape the outputs
    match_vars = JuMP.value.(match_vars)
    if (second_dims - first_dims) == [0, 1]
        match_vars = transpose(reshape(match_vars, (end_dims[2], end_dims[1])))
    else
        match_vars = reshape(match_vars, tuple(end_dims...))
    end
    return match_vars
end


"""
    _get_2d_constraint_duals(m, "powerbalance")

Get the duals of the constraints whose names begin with a given string.
Returns a 2d array of values, shape inferred from the last constraints's name.
"""
function _get_2d_constraint_duals(m::JuMP.Model, s::String)::Array{Float64,2}
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
    # What do the indices of the first, second, and last look like?
    regex_str = r"\[(\d+),(\d+)\]"
    first_dim_strs = match(regex_str, JuMP.name(match_cons[1])).captures
    first_dims = Int64[parse(Int,s) for s in first_dim_strs]
    second_dim_strs = match(regex_str, JuMP.name(match_cons[2])).captures
    second_dims = Int64[parse(Int,s) for s in second_dim_strs]
    end_dim_strs = match(regex_str, JuMP.name(match_cons[end])).captures
    end_dims = Int64[parse(Int,s) for s in end_dim_strs]
    # Use our knowledge of the dims to appropriately reshape the outputs
    match_cons = JuMP.shadow_price.(match_cons)
    if (second_dims - first_dims) == [0, 1]
        match_cons = transpose(reshape(match_cons, (end_dims[2], :)))
    else
        match_cons = reshape(match_cons, (:, end_dims[2]))
    end
    return match_cons
end
