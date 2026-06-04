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
import json
import shutil
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
from tiktak import FileCoordinator, run_worker, read_final


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
        blend_shape=args.blend_shape,
        local_methods=("Powell", "Nelder-Mead"),
        theta_min=0.1,
        theta_max=0.995,
        max_legit_obj_val=1e8,
        penalty_weight=1e6,
    )


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


def run_one_worker(args):
    cfg = build_cfg(args)
    prob = Problem(args.free)
    coord = FileCoordinator(args.workdir)
    real_path = args.real_moments if args.real_moments else None

    t0 = time.time()
    if args.worker_id == 0:
        # Drop metadata so a live monitor can interpret progress (which params
        # are free + their Guvenen values) before final_results.json exists.
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
        print(f"[worker 0] building objective "
              f"({'real' if real_path else 'synthetic'} targets, "
              f"{prob.N_FREE} free params, n_sim={cfg.n_sim}) ...", flush=True)
        print(f"[worker 0] monitor live with:  "
              f"python code/monitor.py {args.workdir}", flush=True)
    objective = prob.make_objective(cfg, real_data_path=real_path)

    run_worker(coord, objective, prob.FREE_BOUNDS, cfg, wid=args.worker_id)

    if args.worker_id == 0:
        aggregate_and_report(coord, cfg, prob)
        print(f"[worker 0] wall time {time.time() - t0:.1f}s", flush=True)


def spawn_workers(args):
    """Parent: clear the workdir (unless --resume) and launch N child workers
    on this machine, then wait for them all."""
    if not args.resume and os.path.isdir(args.workdir):
        shutil.rmtree(args.workdir)
    os.makedirs(args.workdir, exist_ok=True)

    n = args.spawn
    passthrough = [
        "--workdir", args.workdir,
        "--workers", str(n),
        "--n-sim", str(args.n_sim),
        "--n-sobol", str(args.n_sobol),
        "--keep-best", str(args.keep_best),
        "--maxiter", str(args.maxiter),
        "--maxiter-min-frac", str(args.maxiter_min_frac),
        "--blend-shape", args.blend_shape,
        "--free", args.free,
        "--seed", str(args.seed),
        "--sobol-seed", str(args.sobol_seed),
    ]
    if args.real_moments:
        passthrough += ["--real-moments", args.real_moments]

    print(f"Spawning {n} worker process(es) on workdir {args.workdir}", flush=True)
    procs = []
    for i in range(n):
        cmd = [sys.executable, os.path.abspath(__file__),
               "--worker-id", str(i)] + passthrough
        procs.append(subprocess.Popen(cmd))
    rc = 0
    for p in procs:
        rc |= p.wait()
    if rc != 0:
        print(f"[parent] a worker exited non-zero (rc bitmask={rc})", flush=True)
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--workdir", default=None,
                    help="shared run directory (default: output/run_2param)")
    ap.add_argument("--spawn", type=int, default=None,
                    help="parent mode: spawn this many local workers")
    ap.add_argument("--worker-id", type=int, default=None,
                    help="worker mode: this worker's id (0 aggregates)")
    ap.add_argument("--workers", type=int, default=1,
                    help="total number of workers (informational)")
    ap.add_argument("--resume", action="store_true",
                    help="do not wipe the workdir before spawning")
    # problem / config knobs
    ap.add_argument("--free", default="a1,rho1",
                    help="which parameters to estimate: 'all' (full 21-param "
                         "problem) or a comma-separated subset like 'a1,rho1' "
                         "(the rest are fixed at the Guvenen values)")
    ap.add_argument("--n-sim", type=int, default=25_000)
    ap.add_argument("--n-sobol", type=int, default=2048)
    ap.add_argument("--keep-best", type=int, default=40)
    ap.add_argument("--maxiter", type=int, default=600)
    ap.add_argument("--maxiter-min-frac", type=float, default=0.15,
                    help="exploit-heavy restarts get this fraction of --maxiter "
                         "(1.0 = no scaling)")
    ap.add_argument("--blend-shape", choices=("sqrt", "linear"), default="sqrt",
                    help="TikTak blend ramp: 'sqrt' (concave, exploits earlier) "
                         "or 'linear'")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--sobol-seed", type=int, default=999)
    ap.add_argument("--real-moments", default=None,
                    help="path to a data dir with intermediate/*.dat; if set, "
                         "estimate against real moments instead of synthetic")
    args = ap.parse_args()

    if args.workdir is None:
        repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        args.workdir = os.path.join(repo, "output", "run_2param")

    # Worker mode (explicit id) takes precedence; otherwise spawn.
    if args.worker_id is not None:
        run_one_worker(args)
    else:
        if args.spawn is None:
            args.spawn = 1
        spawn_workers(args)


if __name__ == "__main__":
    main()
