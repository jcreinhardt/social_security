"""
monitor.py
==========
Read-only progress snapshot of a running (or finished) TikTak run: which phase
it's in, how far the Sobol and local stages have got, and where the current
best parameters stand vs. their Guvenen values.

Pure standard library on purpose -- no numpy, no project imports -- so it runs
with the plain system ``python`` on the cluster WITHOUT activating the conda
env. Safe to run anytime against the shared work directory while a job
optimizes: it only reads the small coordination files (counters, run_meta.json,
local/*.json), never the tens-of-thousands of Sobol result files.

Usage:
    python code/monitor.py <workdir>                  # one-shot snapshot
    watch -n 30 python code/monitor.py <workdir>      # refresh every 30s
"""

import argparse
import glob
import json
import os
import time


def _read_int(path):
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def _read_float(path):
    try:
        with open(path) as fh:
            return float(fh.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def _read_json(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _best_local(workdir):
    """Best (x, f) among finished local searches; None if none yet. Reads only
    the per-restart JSON files (<= keep_best of them)."""
    best = None
    for p in glob.glob(os.path.join(workdir, "local", "*.json")):
        r = _read_json(p)
        if r and (best is None or r["f"] < best[1]):
            best = (r["x"], r["f"])
    return best


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
    truth = meta["truth"]
    bounds = meta.get("free_bounds")   # may be absent for older runs

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
        print(f"Sobol screen : {c}/{n_sobol} claimed ({100.0 * c / n_sobol:.0f}%)")
    if n_starts:
        print(f"Local search : {loc_done}/{n_starts} restarts finished "
              f"({100.0 * loc_done / n_starts:.0f}%)")

    # Objective at the Guvenen parameter values (cached once at init by
    # run_tiktak.py) — the published-point baseline to beat.
    q_guv = _read_float(os.path.join(wd, "guvenen_objective"))
    if q_guv is not None:
        print(f"Guvenen-point objective: {q_guv:.6e}")

    best = _best_local(wd)
    if best is None:
        print("\nNo completed local search yet (still screening / first wave).")
        return
    x, f = best

    print(f"\ncurrent best objective: {f:.6e}")
    if q_guv is not None:
        if f < q_guv:
            print(f"  -> beats the Guvenen point by {q_guv - f:.6e} "
                  f"({100.0 * (q_guv - f) / abs(q_guv):.1f}% lower)")
        else:
            print(f"  -> still {f - q_guv:.6e} above the Guvenen point")
    print(f"\n{'param':12s} {'current':>13s} {'Guvenen':>13s} "
          f"{'diff':>12s} {'%range':>8s}")
    print("-" * 62)
    worst = (-1.0, "")
    for j, name in enumerate(free):
        diff = x[j] - truth[j]
        if bounds:
            lo, hi = bounds[j]
            span = (hi - lo) if hi > lo else 1.0
            pct = 100.0 * abs(diff) / span
            pct_s = f"{pct:7.1f}%"
            if pct > worst[0]:
                worst = (pct, name)
        else:
            pct_s = "      ?"
        print(f"{name:12s} {x[j]:13.6f} {truth[j]:13.6f} {diff:+12.5f} {pct_s}")
    print("-" * 62)
    if bounds:
        print(f"max |error| over bound range: {worst[0]:.1f}%   (param {worst[1]})")


if __name__ == "__main__":
    main()
