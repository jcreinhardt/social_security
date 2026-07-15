"""
run_tiktak.py
=============
CLI entry point for the file-coordinated TikTak MSM estimation of the 2 free
parameters (a1, rho1).

One invocation == one worker process. Workers coordinate only through the
shared ``--workdir`` directory, so the *same* command runs as:

  * a single process:
        python run_tiktak.py --spawn 1
  * N local processes on one machine (parent spawns N children):
        python run_tiktak.py --spawn 8
  * an HPC SLURM array (each array task is one worker, no parent):
        python run_tiktak.py --worker-id $SLURM_ARRAY_TASK_ID \
                             --workers  $SLURM_ARRAY_TASK_COUNT \
                             --workdir  /shared/fs/run_2param
    (run the array on a shared filesystem; see code/README.md.)

Worker 0 aggregates results once the run reaches DONE: it writes
``final_results.json`` and ``tiktak_2param_results.csv`` into the workdir and
prints the parameter-recovery table.
"""

import os

# Pin BLAS to a single thread BEFORE numpy is imported, so N worker processes
# don't oversubscribe cores fighting over the same BLAS pool.
for _v in ("OMP_NUM_THREADS", "MKL_NUM_THREADS",
           "OPENBLAS_NUM_THREADS", "NUMEXPR_NUM_THREADS"):
    os.environ.setdefault(_v, "1")

import argparse
import dataclasses
import json
import shutil
import signal
import subprocess
import sys
import time

import numpy as np
import pandas as pd

# Make ./algorithm importable (entry points stay flat at code/; the library
# modules live in code/algorithm/). Must precede the library imports below.
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "algorithm"))

from msm_model import MSMConfig
from problem import Problem
from tiktak import (DONE, EVAL_SOBOL, LOCAL_SEARCH, FileCoordinator,
                    _stage_polish, _stage_select, _try_become_leader,
                    read_final, run_worker)


def build_cfg(args):
    return MSMConfig(
        n_sim=args.n_sim,
        hmax=36,
        seed=args.seed,
        sobol_draws=args.n_sobol,
        sobol_seed=args.sobol_seed,
        keep_best=args.keep_best,
        maxiter_local=args.maxiter,
        maxiter_min_frac=args.maxiter_min_frac,
        maxiter_polish=args.maxiter_polish,
        n_sim_screen=args.n_sim_screen,
        blend_shape=args.blend_shape,
        local_methods=("Powell", "Nelder-Mead"),
        theta_min=0.1,
        theta_max=0.995,
        max_legit_obj_val=1e8,
        penalty_weight=1e6,
        lease_ttl=args.lease_ttl,
        babysit_interval=args.babysit_interval,
    )


def build_objectives(prob, cfg, real_path):
    """Build (objective_screen, objective_polish). With multi-fidelity
    (0 < cfg.n_sim_screen < cfg.n_sim) the Sobol screen + local restarts use the
    cheaper screen objective and the final polish uses the full-n_sim one;
    otherwise both are the same object. The polish objective is also the one to
    use as the reported / Guvenen-comparison reference (full fidelity)."""
    obj_polish = prob.make_objective(cfg, real_data_path=real_path)
    ns = cfg.n_sim_screen
    if not ns or ns >= cfg.n_sim:
        return obj_polish, obj_polish
    cfg_screen = dataclasses.replace(cfg, n_sim=ns)
    obj_screen = prob.make_objective(cfg_screen, real_data_path=real_path)
    return obj_screen, obj_polish


def aggregate_and_report(coord, cfg, prob):
    """Worker-0 post-processing: assemble per-start results + final estimate."""
    recs = coord.load_local_results()
    recs.sort(key=lambda r: r["f"] if np.isfinite(r["f"]) else np.inf)

    rows = []
    for r in recs:
        row = {"k": r["k"], "objective": r["f"]}
        for j, name in enumerate(prob.FREE_NAMES):
            row[f"{name}_estimate"] = r["x"][j]
        rows.append(row)
    csv_path = os.path.join(coord.workdir, "tiktak_results.csv")
    pd.DataFrame(rows).to_csv(csv_path, index=False)

    final = read_final(coord)
    if final is None and recs:
        final = {"x": recs[0]["x"], "f": recs[0]["f"]}
    best_x = np.asarray(final["x"], float)

    summary = {
        "objective": final["f"],
        "free_names": prob.FREE_NAMES,
        "estimate": best_x.tolist(),
        "truth": prob.FREE_TRUE.tolist(),
        "n_free": prob.N_FREE,
        "n_starts": len(recs),
        "config": {
            "n_sim": cfg.n_sim, "n_sobol": cfg.sobol_draws,
            "keep_best": cfg.keep_best, "maxiter_local": cfg.maxiter_local,
            "seed": cfg.seed, "sobol_seed": cfg.sobol_seed,
        },
    }
    with open(os.path.join(coord.workdir, "final_results.json"), "w") as fh:
        json.dump(summary, fh, indent=2)

    print("\n" + "=" * 60)
    print(f"ESTIMATION COMPLETE  ({prob.N_FREE} free parameters)")
    print("=" * 60)
    print(f"Objective: {final['f']:.6e}")
    print(f"\n{'Param':12s} {'Estimate':>14s} {'Guvenen':>14s} {'Diff':>14s}")
    print("-" * 56)
    for j, name in enumerate(prob.FREE_NAMES):
        diff = best_x[j] - prob.FREE_TRUE[j]
        print(f"{name:12s} {best_x[j]:14.6f} {prob.FREE_TRUE[j]:14.6f} {diff:+14.6f}")
    print(f"\nResults written to {coord.workdir}")


def record_guvenen_objective(coord, objective, prob):
    """Cache Q(theta) evaluated at the Guvenen parameter values once, so
    monitor.py can show that published-point baseline next to the optimizer's
    current best. It is constant for a given config (the shocks and target are
    frozen), so a single evaluation at init is enough. Best-effort: a failure
    here must not derail the run."""
    try:
        q = float(objective(prob.FREE_TRUE))
        coord.write_meta("guvenen_objective", q)
        print(f"[init] objective at Guvenen parameters: {q:.6e}", flush=True)
    except Exception as e:  # pragma: no cover - diagnostic only
        print(f"[init] could not evaluate the Guvenen-point objective: {e}",
              flush=True)


def write_run_meta(coord, cfg, prob):
    """Drop metadata so a live monitor can interpret progress (which params are
    free + their Guvenen values) before final_results.json exists."""
    with open(os.path.join(coord.workdir, "run_meta.json"), "w") as fh:
        json.dump({
            "free_names": prob.FREE_NAMES,
            "truth": prob.FREE_TRUE.tolist(),
            "free_bounds": prob.FREE_BOUNDS.tolist(),
            "n_free": prob.N_FREE,
            "config": {
                "n_sim": cfg.n_sim, "n_sobol": cfg.sobol_draws,
                "keep_best": cfg.keep_best, "maxiter_local": cfg.maxiter_local,
                "seed": cfg.seed, "sobol_seed": cfg.sobol_seed,
            },
        }, fh, indent=2)


def run_one_worker(args):
    cfg = build_cfg(args)
    prob = Problem(args.free, gender=args.gender, gender_data=args.gender_data)
    coord = FileCoordinator(args.workdir)
    real_path = args.real_moments if args.real_moments else None

    wid = (args.worker_id or 0) + args.worker_id_offset
    # role 'worker' (scavenge array task): never elects a leader, never writes
    # metadata, never aggregates -- the stable coordinator owns those. role
    # 'auto' (single-node --spawn): worker 0 leads/aggregates as before.
    elect = args.role != "worker"
    is_auto_lead = args.role == "auto" and (args.worker_id or 0) == 0

    t0 = time.time()
    if is_auto_lead:
        write_run_meta(coord, cfg, prob)
        screen = cfg.n_sim_screen if (0 < cfg.n_sim_screen < cfg.n_sim) else cfg.n_sim
        tgt = (f"gender:{args.gender}" if args.gender
               else ("real" if real_path else "synthetic"))
        print(f"[worker 0] building objective "
              f"({tgt} targets, "
              f"{prob.N_FREE} free params, screen n_sim={screen}, "
              f"polish n_sim={cfg.n_sim}) ...", flush=True)
        print(f"[worker 0] monitor live with:  "
              f"python code/monitor.py {args.workdir}", flush=True)
    objective, objective_polish = build_objectives(prob, cfg, real_path)
    if is_auto_lead:
        record_guvenen_objective(coord, objective_polish, prob)

    run_worker(coord, objective, prob.FREE_BOUNDS, cfg, wid=wid, elect=elect,
               objective_polish=objective_polish, search_box=prob.FREE_RANGE)

    if is_auto_lead:
        aggregate_and_report(coord, cfg, prob)
        print(f"[worker 0] wall time {time.time() - t0:.1f}s", flush=True)


def spawn_workers(args):
    """Parent: launch N child workers on this machine, then wait for them all.
    In the default role ('auto') the workdir is cleared first (unless --resume);
    in role 'worker' (a scavenge node joining a shared run) it is NEVER cleared,
    so a node can contribute cores without nuking peers' results."""
    if args.role != "worker" and not args.resume and os.path.isdir(args.workdir):
        shutil.rmtree(args.workdir)
    os.makedirs(args.workdir, exist_ok=True)

    n = args.spawn
    passthrough = [
        "--workdir", args.workdir,
        "--workers", str(n),
        "--role", args.role,
        "--worker-id-offset", str(args.worker_id_offset),
        "--lease-ttl", str(args.lease_ttl),
        "--n-sim", str(args.n_sim),
        "--n-sim-screen", str(args.n_sim_screen),
        "--n-sobol", str(args.n_sobol),
        "--keep-best", str(args.keep_best),
        "--maxiter", str(args.maxiter),
        "--maxiter-min-frac", str(args.maxiter_min_frac),
        "--maxiter-polish", str(args.maxiter_polish),
        "--blend-shape", args.blend_shape,
        "--free", args.free,
        "--seed", str(args.seed),
        "--sobol-seed", str(args.sobol_seed),
    ]
    if args.real_moments:
        passthrough += ["--real-moments", args.real_moments]
    if args.gender:
        passthrough += ["--gender", args.gender, "--gender-data", args.gender_data]

    print(f"Spawning {n} worker process(es) (role={args.role}) on workdir "
          f"{args.workdir}", flush=True)
    procs = []

    # Forward a preemption signal (SLURM --signal) to the children so each can
    # finish its current task and drop its lease before dying. We record the
    # signal so the parent can ITSELF die by it below (rather than exiting 0).
    # (The lease TTL reaper recovers any in-flight work regardless.)
    _preempt = {"sig": None}

    def _forward(signum, frame):
        _preempt["sig"] = signum
        for p in procs:
            try:
                p.send_signal(signal.SIGTERM)
            except Exception:
                pass
    for _sig in (signal.SIGTERM, signal.SIGUSR1):
        try:
            signal.signal(_sig, _forward)
        except (ValueError, OSError):
            pass

    for i in range(n):
        cmd = [sys.executable, os.path.abspath(__file__),
               "--worker-id", str(i)] + passthrough
        procs.append(subprocess.Popen(cmd))
    rc = 0
    for p in procs:
        rc |= p.wait()

    # If SLURM signalled us (scavenge preemption), the children have already
    # dropped their leases and exited. We must NOT exit 0: a voluntary clean
    # exit is recorded COMPLETED and is NOT requeued, so the worker array would
    # only ever shrink. Re-raise the same signal to die by it -- a signalled
    # termination is requeue-eligible, so SLURM --requeue brings this task back
    # and it rejoins the run.
    if _preempt["sig"] is not None:
        sig = _preempt["sig"]
        print(f"[parent] preemption signal {sig}; re-raising for a "
              f"requeue-eligible exit", flush=True)
        signal.signal(sig, signal.SIG_DFL)
        os.kill(os.getpid(), sig)
        sys.exit(128 + sig)  # fallback if the signal does not terminate us
    if rc != 0:
        print(f"[parent] a worker exited non-zero (rc bitmask={rc})", flush=True)
        sys.exit(1)


# ── Coordinator (stable partition): init + babysit + aggregate ──────────────

def _submit_array(submit_cmd, n, maxpar):
    """Submit the scavenge worker array sized to ``n`` tasks (at most ``maxpar``
    running at once) and return its job id. The ``--array`` spec is appended
    here so the coordinator can size each (re)submission to the current deficit.
    Parses both `--parsable` and the normal 'Submitted batch job <id>' forms;
    returns None on failure."""
    import shlex
    cmd = shlex.split(submit_cmd) + [f"--array=0-{n - 1}%{maxpar}"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        print(f"[coordinator] array submit failed: {out.stderr.strip()}",
              flush=True)
        return None
    s = out.stdout.strip()
    return s.split(";")[0].split()[-1] if s else None


def _array_alive_count(jobid):
    """Number of pending+running tasks of ``jobid`` still in the queue (0 if
    none / unknown). A requeued (preempted) task is still counted -- it sits
    PENDING and will rerun -- so this measures live worker width."""
    if not jobid:
        return 0
    out = subprocess.run(["squeue", "-j", str(jobid), "-h", "-o", "%i"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return 0
    return sum(1 for line in out.stdout.splitlines() if line.strip())


def run_coordinator(args):
    """Stable-partition babysitter: initialize the run, keep a scavenge worker
    array alive (resubmitting it if it drains), drive the leader-only stage
    transitions even when no scavenge worker is up, and aggregate at the end.

    Resumes by default (re-attaches to an initialized workdir); pass --fresh to
    wipe and start over. The array (re)submission command is taken from the
    WORKER_SUBMIT_CMD env var; if unset, the coordinator only orchestrates +
    aggregates (workers are expected to be launched separately, e.g. in tests)."""
    workdir = os.path.abspath(args.workdir)
    if args.fresh and os.path.isdir(workdir):
        print(f"[coordinator] --fresh: wiping {workdir}", flush=True)
        shutil.rmtree(workdir)

    cfg = build_cfg(args)
    prob = Problem(args.free, gender=args.gender, gender_data=args.gender_data)
    coord = FileCoordinator(workdir)
    real_path = args.real_moments if args.real_moments else None

    write_run_meta(coord, cfg, prob)
    tgt = (f"gender:{args.gender}" if args.gender
           else ("real" if real_path else "synthetic"))
    print(f"[coordinator] building objective "
          f"({tgt} targets, "
          f"{prob.N_FREE} free params, n_sim={cfg.n_sim}) ...", flush=True)
    objective = prob.make_objective(cfg, real_data_path=real_path)
    bounds = prob.FREE_BOUNDS
    record_guvenen_objective(coord, objective, prob)

    # Initialize the run (draw the Sobol set, open EVAL_SOBOL) if not already.
    if coord.get_state() is None:
        _try_become_leader(coord, objective, bounds, cfg,
                           search_box=prob.FREE_RANGE)
    print(f"[coordinator] run state: {coord.get_state()}", flush=True)
    print(f"[coordinator] monitor live with:  "
          f"python code/monitor.py {workdir}", flush=True)

    submit_cmd = os.environ.get("WORKER_SUBMIT_CMD", "").strip()
    target = int(os.environ.get("WORKER_ARRAY_TARGET", "0") or 0)
    maxpar = int(os.environ.get("WORKER_ARRAY_MAXPAR", "0") or target or 1)
    array_jobids = []
    if submit_cmd and target > 0:
        jid = _submit_array(submit_cmd, target, maxpar)
        if jid:
            array_jobids.append(jid)
        print(f"[coordinator] submitted scavenge worker array: {jid} "
              f"(target={target} tasks, maxpar={maxpar})", flush=True)
    elif submit_cmd:
        print("[coordinator] WORKER_ARRAY_TARGET unset/0; not managing worker "
              "array width.", flush=True)
    else:
        print("[coordinator] WORKER_SUBMIT_CMD unset; not managing a worker "
              "array (launch workers separately).", flush=True)

    t0 = time.time()
    while coord.get_state() != DONE:
        # Advance the leader-only stages. Each no-ops until its stage is
        # complete, so it is safe to poll-call every tick -- this guarantees
        # forward progress even if every scavenge worker is preempted.
        if coord.get_state() == EVAL_SOBOL:
            _stage_select(coord, cfg, wid=-1)
        if coord.get_state() == LOCAL_SEARCH:
            _stage_polish(coord, objective, bounds, cfg, wid=-1)
        # Keep the scavenge array at full WIDTH. Preempted tasks self-heal via
        # --requeue (so they still count as alive); this tops up the DEFICIT
        # left by tasks that terminally ended (walltime TIMEOUT) or failed to
        # requeue. Sizing each refill to the deficit -- not resubmitting the
        # whole array -- avoids over-provisioning, and just-submitted tasks show
        # up PENDING immediately so they are counted next tick (no double-fill).
        if submit_cmd and target > 0 and coord.get_state() != DONE:
            array_jobids = [j for j in array_jobids
                            if _array_alive_count(j) > 0]
            alive = sum(_array_alive_count(j) for j in array_jobids)
            deficit = target - alive
            if deficit > 0:
                jid = _submit_array(submit_cmd, deficit, min(maxpar, deficit))
                if jid:
                    array_jobids.append(jid)
                    print(f"[coordinator] topped up scavenge array: +{deficit} "
                          f"tasks ({jid}); was {alive}/{target} alive",
                          flush=True)
        if coord.get_state() == DONE:
            break
        time.sleep(cfg.babysit_interval)

    aggregate_and_report(coord, cfg, prob)
    print(f"[coordinator] run complete; wall time {time.time() - t0:.1f}s",
          flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--workdir", default=None,
                    help="shared run directory (default: output/run_2param)")
    ap.add_argument("--spawn", type=int, default=None,
                    help="parent mode: spawn this many local workers")
    ap.add_argument("--worker-id", type=int, default=None,
                    help="worker mode: this worker's id (0 aggregates in role "
                         "'auto')")
    ap.add_argument("--worker-id-offset", type=int, default=0,
                    help="added to --worker-id (and to each --spawn child's id) "
                         "so a scavenge array task's workers get distinct ids; "
                         "for logging only")
    ap.add_argument("--workers", type=int, default=1,
                    help="total number of workers (informational)")
    ap.add_argument("--role", choices=("auto", "worker", "coordinator"),
                    default="auto",
                    help="auto: single-node --spawn (worker 0 leads+aggregates). "
                         "worker: scavenge array task (no lead/meta/aggregate, "
                         "waits for the coordinator's init). coordinator: stable "
                         "babysitter that inits, keeps the array alive, and "
                         "aggregates.")
    ap.add_argument("--resume", action="store_true",
                    help="do not wipe the workdir before spawning")
    ap.add_argument("--fresh", action="store_true",
                    help="coordinator only: wipe the workdir and start over "
                         "(default is to resume an existing run)")
    ap.add_argument("--lease-ttl", type=float, default=600.0,
                    help="seconds before an unrefreshed in-flight task is "
                         "presumed abandoned and reclaimed (preemption recovery)")
    ap.add_argument("--babysit-interval", type=float, default=60.0,
                    help="coordinator poll cadence (s): stage transitions + "
                         "array-alive checks")
    # problem / config knobs
    ap.add_argument("--free", default="a1,rho1",
                    help="which parameters to estimate: 'all' (full 21-param "
                         "problem) or a comma-separated subset like 'a1,rho1' "
                         "(the rest are fixed at the Guvenen values)")
    ap.add_argument("--n-sim", type=int, default=25_000)
    ap.add_argument("--n-sim-screen", type=int, default=0,
                    help="multi-fidelity: run the Sobol screen + local restarts "
                         "at this (smaller) n_sim, and the final polish at the "
                         "full --n-sim. 0 disables (everything at --n-sim).")
    ap.add_argument("--n-sobol", type=int, default=2048)
    ap.add_argument("--keep-best", type=int, default=40)
    ap.add_argument("--maxiter", type=int, default=600,
                    help="per-restart local-search budget (LOCAL_SEARCH stage). "
                         "Keep small enough that one restart finishes inside a "
                         "preemptible worker's walltime; the POLISH refines.")
    ap.add_argument("--maxiter-min-frac", type=float, default=0.15,
                    help="exploit-heavy restarts get this fraction of --maxiter "
                         "(1.0 = no scaling)")
    ap.add_argument("--maxiter-polish", type=int, default=1000,
                    help="budget for the final POLISH local search (runs on the "
                         "stable coordinator, no walltime pressure). Decoupled "
                         "from --maxiter so restarts can be coarse but the final "
                         "estimate still converges.")
    ap.add_argument("--blend-shape", choices=("sqrt", "linear"), default="sqrt",
                    help="TikTak blend ramp: 'sqrt' (concave, exploits earlier) "
                         "or 'linear'")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--sobol-seed", type=int, default=999)
    ap.add_argument("--real-moments", default=None,
                    help="path to a data dir with intermediate/*.dat; if set, "
                         "estimate against real moments instead of synthetic")
    ap.add_argument("--gender", choices=("men", "women"), default=None,
                    help="estimate against a single sex's GKOS workbook moments "
                         "(common subset: SSK_L1+SSK_L5+incgrwth). Overrides "
                         "--real-moments. See algorithm/gender_targets.py")
    ap.add_argument("--gender-data", default="data",
                    help="dir holding GKOS_2016_moments_{men,women}.xlsx")
    args = ap.parse_args()

    if args.workdir is None:
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        args.workdir = os.path.join(repo, "output", "run_2param")

    # Coordinator mode first; then worker mode (explicit id); else spawn.
    if args.role == "coordinator":
        run_coordinator(args)
    elif args.worker_id is not None:
        run_one_worker(args)
    else:
        if args.spawn is None:
            args.spawn = 1
        spawn_workers(args)


if __name__ == "__main__":
    main()
