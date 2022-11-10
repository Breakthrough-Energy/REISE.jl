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
