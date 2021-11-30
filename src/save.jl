"""
    save_input_mat(case)

Read the original case.mat file, replace relevant parameters from Case struct,
save a new input.mat file with parameters as they're passed to solver.
"""
function save_input_mat(
    case::Case, storage::Storage, inputfolder::String, outputfolder::String
)
    # MATPOWER column indices
    gen_PMAX = 9
    gen_PMIN = 10
    gen_RAMP_30 = 19
    gencost_MODEL = 1
    gencost_NCOST = 4
    gencost_COST = 5

    # Read original
    case_mat_file = MAT.matopen(joinpath(inputfolder, "case.mat"))
    mpc = read(case_mat_file, "mpc")
    mdi = Dict("mpc" => mpc)

    # Save modifications to gen
    mpc["gen"][:, gen_PMIN] = case.gen_pmin
    mpc["gen"][:, gen_RAMP_30] = case.gen_ramp30
    # Save modifications to gencost table
    mpc["gencost"] = case.gencost
    mpc["gencost_orig"] = case.gencost_orig

    # Save storage details in mpc.[gencost, genfuel, gencost] and in 'Storage'
    if size(storage.gen, 1) > 0
        num_storage = size(storage.gen, 1)
        # Add fuel types for storage 'generators'. ESS = energy storage system
        mpc["genfuel"] = [mpc["genfuel"]; repeat(["ess"], num_storage)]
        # Save storage modifications to gen table
        mpc["gen"] = [mpc["gen"]; storage.gen]
        # Save storage modifications to gencost
        #@show case.gencost[:, gencost_MODEL]
        segment_indices = findall(case.gencost[:, gencost_MODEL] .== 1)
        segment_orders = case.gencost[segment_indices, gencost_NCOST]
        num_segments = convert(Int, maximum(segment_orders)) - 1
        storage_gencost = zeros(num_storage, (6 + 2 * num_segments))
        # Storage is specified by two points, PMIN and PMAX, both with cost 0
        storage_gencost[:, gencost_MODEL] .= 1
        storage_gencost[:, gencost_NCOST] .= 2
        storage_gencost[:, gencost_COST] = storage.gen[:, gen_PMIN]
        storage_gencost[:, gencost_COST + 2] = storage.gen[:, gen_PMAX]
        mpc["gencost"] = [mpc["gencost"]; storage_gencost]
        # Save addition of 'iess' field (index, energy storage systems) to mpc
        num_gen = length(case.genid)
        # Mimic the array that MATPOWER/MOST would create
        iess = collect((num_gen + 1):(num_gen + num_storage))
        mpc["iess"] = iess
        # Build new struct for data in 'Storage'
        input_mat_storage = Dict(
            String(s) => storage.sd_table[!, s] for s in DataFrames.names(storage.sd_table)
        )
        mdi["Storage"] = input_mat_storage
    end

    output_path = joinpath(outputfolder, "input.mat")
    MAT.matwrite(output_path, Dict("mdi" => mdi); compress=true)
    return nothing
end

"""Given a Results object and a filename, save a matfile with results data."""
function save_results(results::Results, filename::String; demand_scaling::Number=1.0)
    mdo_save = Dict(
        "results" => Dict("f" => results.f),
        "demand_scaling" => demand_scaling,
        "flow" => Dict(
            "mpc" => Dict(
                "bus" => Dict("LAM_P" => results.lmp),
                "gen" => Dict("PG" => results.pg),
                "branch" => Dict(
                    "PF" => results.pf,
                    "MU_SF" => results.congu,
                    "MU_ST" => results.congl,
                ),
            ),
        ),
    )
    # For DC lines, storage power/energy, load_shed, and flexible demand,
    # save only if nonempty
    if size(results.pf_dcline) != (0, 0)
        mdo_save["flow"]["mpc"]["dcline"] = Dict("PF_dcline" => results.pf_dcline)
    end
    if size(results.storage_pg) != (0, 0)
        mdo_save["flow"]["mpc"]["storage"] = Dict(
            "PG" => results.storage_pg, "Energy" => results.storage_e
        )
    end
    if size(results.load_shed) != (0, 0)
        mdo_save["flow"]["mpc"]["load_shed"] = Dict("load_shed" => results.load_shed)
    end
    if size(results.load_shift_dn) != (0, 0)
        mdo_save["flow"]["mpc"]["flexible_demand"] = Dict(
            "load_shift_up" => results.load_shift_up,
            "load_shift_dn" => results.load_shift_dn,
        )
    end
    if size(results.trans_viol) != (0, 0)
        mdo_save["flow"]["mpc"]["trans_viol"] = Dict("trans_viol" => results.trans_viol)
    end
    return MAT.matwrite(filename, Dict("mdo_save" => mdo_save); compress=true)
end

"""
    redirect_stdout_stderr("stdout.log", "stderr.err") do
        run_scenario(; kwargs...)
    end

While executing a function, redirect stdout and stderr to files.
"""
function redirect_stdout_stderr(dofunc, stdoutfile, stderrfile)
    open(stdoutfile, "a") do out
        open(stderrfile, "a") do err
            redirect_stdout(out) do
                redirect_stderr(err) do
                    dofunc()
                end
            end
        end
    end
end
