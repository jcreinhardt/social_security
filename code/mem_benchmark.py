"""
mem_benchmark.py
================
Estimate how much memory to request for an HPC run.

Our worker (`run_tiktak --spawn N`) forks N independent Python processes, so the
job's total memory is ~N times one worker's peak RSS -- but SLURM's
`sacct MaxRSS` usually reports only the largest single process, undercounting a
multi-process job. Instead, this measures ONE worker's peak resident memory
(interpreter + numba + frozen CRN shocks + transient moment arrays) and
extrapolates to N workers.

Usage:
    python mem_benchmark.py --n-sim 25000 --cores 12 24 36 48 60
"""

import argparse
import resource
import sys

import numpy as np

from msm_model import MSMConfig
import problem_2param as prob
from tiktak import local_search


def peak_rss_mb():
    """Peak resident set size of this process so far, in MB.
    ru_maxrss is bytes on macOS, kilobytes on Linux."""
    r = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return r / (1024.0 ** 2) if sys.platform == "darwin" else r / 1024.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n-sim", type=int, default=25_000)
    ap.add_argument("--maxiter", type=int, default=600)
    ap.add_argument("--cores", type=int, nargs="+", default=[12, 24, 36, 48, 60])
    ap.add_argument("--headroom", type=float, default=1.30,
                    help="safety multiplier on the estimate (default 1.30)")
    args = ap.parse_args()

    base = peak_rss_mb()  # interpreter + imports (numpy/scipy/numba already loaded)

    cfg = MSMConfig(n_sim=args.n_sim, maxiter_local=args.maxiter)
    # Building the objective allocates this worker's frozen CRN shocks + target;
    # then exercise the realistic hot-path peak (a few evals + one local search,
    # which is where transient moment arrays like `longdata` are largest).
    objective = prob.make_objective(cfg)
    for _ in range(3):
        objective(prob.FREE_TRUE)
    local_search(objective, np.array([0.7, 0.95]), prob.FREE_BOUNDS, cfg)
    peak = peak_rss_mb()

    print(f"n_sim = {args.n_sim}, maxiter = {args.maxiter}")
    print(f"  interpreter + imports baseline : {base:8.1f} MB")
    print(f"  per-worker PEAK RSS            : {peak:8.1f} MB")
    print()
    print(f"  {'cores':>6} {'est. total':>12} {'+headroom':>12}   <- request this")
    print("  " + "-" * 44)
    for n in args.cores:
        total_gb = n * peak / 1024.0
        print(f"  {n:6d} {total_gb:9.2f} GB {args.headroom * total_gb:9.2f} GB")
    print()
    print(f"Set --mem to the headroom column for your largest core count "
          f"(round up to a whole GB). Memory scales with n_sim, so re-run this "
          f"if you change it.")
    print("Cross-check on the cluster after a run with:  seff <jobid>   or")
    print("  sacct -j <jobid> -o JobID,MaxRSS,MaxVMSize,ReqMem,State,Elapsed")
    print("(but remember MaxRSS may report only the largest single worker).")


if __name__ == "__main__":
    main()
