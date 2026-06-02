"""
scaling_report.py
=================
Aggregate the per-core-count runs produced by hpc_scaling_test.slurm into a
single speed + accuracy comparison table.

Reads each ``<base>/cores_<N>/final_results.json`` (written by run_tiktak's
worker 0) and the matching ``wall_seconds.txt`` (the externally-timed wall
clock for that run), then reports, per core count: wall time, speedup and
parallel efficiency relative to the smallest core count, the objective, and the
estimate + error vs. the known truth for each free parameter.

Usage:
    python scaling_report.py [base_dir]      # default base: output/scaling
"""

import csv
import glob
import json
import os
import sys


def main(base="output/scaling"):
    rows = []
    truth = names = None
    for d in sorted(glob.glob(os.path.join(base, "cores_*"))):
        try:
            cores = int(os.path.basename(d).split("_")[1])
        except (IndexError, ValueError):
            continue
        fr = os.path.join(d, "final_results.json")
        if not os.path.exists(fr):
            print(f"[warn] missing {fr} (run may have failed)")
            continue
        with open(fr) as fh:
            r = json.load(fh)
        wf = os.path.join(d, "wall_seconds.txt")
        wall = float(open(wf).read().strip()) if os.path.exists(wf) else float("nan")
        truth, names = r["truth"], r["free_names"]
        rows.append((cores, wall, r["objective"], r["estimate"]))

    rows.sort()
    if not rows:
        print(f"No completed runs found under {base!r}.")
        return

    base_cores, base_wall = rows[0][0], rows[0][1]

    hdr = f"{'cores':>6} {'wall_s':>9} {'speedup':>8} {'effic%':>7} {'objective':>12}"
    for nm in names:
        hdr += f" {nm:>11} {nm + '_err':>12}"
    print("\n" + "=" * len(hdr))
    print(f"SCALING SUMMARY  (speedup/efficiency relative to {base_cores} cores)")
    print("=" * len(hdr))
    print(hdr)
    print("-" * len(hdr))

    out = []
    for cores, wall, obj, est in rows:
        speedup = base_wall / wall if wall else float("nan")
        ideal = cores / base_cores
        eff = 100.0 * speedup / ideal if ideal else float("nan")
        line = f"{cores:6d} {wall:9.1f} {speedup:8.2f} {eff:7.1f} {obj:12.3e}"
        rec = {"cores": cores, "wall_s": round(wall, 2),
               "speedup": round(speedup, 4), "efficiency_pct": round(eff, 2),
               "objective": obj}
        for k, nm in enumerate(names):
            err = est[k] - truth[k]
            line += f" {est[k]:11.6f} {err:+12.2e}"
            rec[nm] = est[k]
            rec[f"{nm}_err"] = err
        print(line)
        out.append(rec)

    print("-" * len(hdr))
    print(f"truth: " + ", ".join(f"{nm}={truth[k]:.6f}"
                                 for k, nm in enumerate(names)))

    csv_path = os.path.join(base, "scaling_summary.csv")
    with open(csv_path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)
    print(f"\nWrote {csv_path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "output/scaling")
