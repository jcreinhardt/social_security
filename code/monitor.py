"""
monitor.py
==========
Read-only progress snapshot of a running (or finished) TikTak run: which phase
it's in, how far the Sobol and local stages have got, and where the current
best parameters stand vs. their Guvenen values. Safe to run anytime against the
shared work directory while the job optimizes -- it never writes and only reads
the small coordination files (not the tens-of-thousands of Sobol result files).

Usage:
    python monitor.py <workdir>            # one-shot snapshot
    watch -n 30 python code/monitor.py <workdir>   # refresh every 30s
"""

import argparse
import glob
import json
import os
import time

import numpy as np

from msm_model import PARAM_NAMES, PARAM_BOUNDS, THETA_TRUE


def _read_int(path):
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def _read_json(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def current_best(workdir):
    """Best (x, f, source) so far: the best Sobol start (once selected) improved
    on by any finished local search. Cheap -- reads x_starts + local/*.json
    only, never the full Sobol dump."""
    best_x, best_f, src = None, np.inf, None
    sp = os.path.join(workdir, "x_starts.npy")
    sv = os.path.join(workdir, "x_starts_vals.npy")
    if os.path.exists(sp) and os.path.exists(sv):
        xs, vs = np.load(sp), np.load(sv)
        if len(vs):
            best_x, best_f, src = xs[0], float(vs[0]), "sobol"
    for p in glob.glob(os.path.join(workdir, "local", "*.json")):
        r = _read_json(p)
        if r and r["f"] < best_f:
            best_x, best_f, src = np.array(r["x"], float), float(r["f"]), "local"
    return best_x, best_f, src


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workdir")
    args = ap.parse_args()
    wd = args.workdir

    meta = _read_json(os.path.join(wd, "run_meta.json"))
    if meta is None:
        print(f"No run_meta.json in {wd} yet — the run hasn't initialized. "
              f"(Is the path right?)")
        return
    free = meta["free_names"]
    truth = np.array(meta["truth"], float)
    idxs = [PARAM_NAMES.index(n) for n in free]
    lo = PARAM_BOUNDS[idxs, 0]
    hi = PARAM_BOUNDS[idxs, 1]
    span = np.where(hi > lo, hi - lo, 1.0)

    state = "?"
    try:
        with open(os.path.join(wd, "state")) as fh:
            state = fh.read().strip()
    except FileNotFoundError:
        pass

    n_sobol = (meta.get("config") or {}).get("n_sobol")
    sob_claim = _read_int(os.path.join(wd, "sobol_counter"))
    n_starts = _read_int(os.path.join(wd, "n_starts"))
    loc_done = len(glob.glob(os.path.join(wd, "local", "*.json")))

    print("=" * 64)
    print(f"{wd}   @ {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"phase: {state}   |   {len(free)} free parameters")
    if n_sobol:
        c = min(sob_claim, n_sobol) if sob_claim is not None else 0
        print(f"Sobol screen : {c}/{n_sobol} claimed "
              f"({100.0 * c / n_sobol:.0f}%)")
    if n_starts:
        print(f"Local search : {loc_done}/{n_starts} restarts finished "
              f"({100.0 * loc_done / n_starts:.0f}%)")

    best_x, best_f, src = current_best(wd)
    if best_x is None:
        print("\nNo best point yet (still screening Sobol points).")
        return

    print(f"\ncurrent best objective: {best_f:.6e}   (from {src})")
    print(f"\n{'param':12s} {'current':>13s} {'Guvenen':>13s} "
          f"{'diff':>12s} {'%range':>8s}")
    print("-" * 62)
    norm_err = np.abs(best_x - truth) / span
    for j, name in enumerate(free):
        print(f"{name:12s} {best_x[j]:13.6f} {truth[j]:13.6f} "
              f"{best_x[j] - truth[j]:+12.5f} {100 * norm_err[j]:7.1f}%")
    print("-" * 62)
    print(f"max |error| over bound range: {100 * norm_err.max():.1f}%   "
          f"(param {free[int(norm_err.argmax())]})")


if __name__ == "__main__":
    main()
