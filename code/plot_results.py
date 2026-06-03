"""
plot_results.py
===============
Post-process a finished run (any free-parameter set) into two figures:

  1. params_vs_guvenen.png  - the estimated minimum vs. the original Guvenen
     value for every free parameter, shown as normalized positions within each
     parameter's [lower, upper] search bounds (so all parameters are
     comparable on one axis), with the raw values annotated.

  2. objective_slices.png   - a 1-D slice of the MSM objective along each free
     parameter: hold the other parameters at the estimate and sweep this one
     across its bounds, marking the estimate and the Guvenen value. Shows how
     well each parameter is identified (curvature) and whether the found
     minimum sits at the Guvenen value.

The objective is rebuilt with the SAME config (n_sim, seed -> same frozen
shocks and synthetic target) recorded in the run's final_results.json, so the
slices are consistent with what the optimizer saw.

Usage:
    python plot_results.py <workdir> [--grid 41] [--real-moments PATH]
e.g.    python plot_results.py output/run_21param
"""

import argparse
import json
import os
import sys

import numpy as np
import matplotlib
matplotlib.use("Agg")  # headless (HPC nodes have no display)
import matplotlib.pyplot as plt

# Make ./algorithm importable (entry points stay flat at code/; the library
# modules live in code/algorithm/). Must precede the library imports below.
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "algorithm"))

from msm_model import MSMConfig
from problem import Problem


def load_run(workdir):
    with open(os.path.join(workdir, "final_results.json")) as fh:
        return json.load(fh)


def rebuild_objective(summary, real_data_path):
    c = summary["config"]
    cfg = MSMConfig(
        n_sim=c["n_sim"], hmax=36, seed=c["seed"],
        sobol_draws=c.get("n_sobol", 2048), sobol_seed=c.get("sobol_seed", 999),
        keep_best=c.get("keep_best", 40), maxiter_local=c.get("maxiter_local", 600),
    )
    prob = Problem(summary["free_names"])
    objective = prob.make_objective(cfg, real_data_path=real_data_path)
    return prob, objective


def plot_recovery(prob, est, truth, out_path):
    names = prob.FREE_NAMES
    lo, hi = prob.FREE_BOUNDS[:, 0], prob.FREE_BOUNDS[:, 1]
    span = np.where(hi > lo, hi - lo, 1.0)
    est_n = (np.asarray(est) - lo) / span
    tru_n = (np.asarray(truth) - lo) / span
    n = len(names)
    y = np.arange(n)[::-1]  # first param at top

    fig, ax = plt.subplots(figsize=(8, max(3, 0.42 * n + 1)))
    for yi, en, tn in zip(y, est_n, tru_n):
        ax.plot([0, 1], [yi, yi], color="0.85", lw=6, solid_capstyle="round", zorder=1)
        ax.plot([tn, en], [yi, yi], color="0.5", lw=1, zorder=2)
    ax.scatter(tru_n, y, marker="o", s=70, color="#1f77b4", label="Guvenen (truth)", zorder=3)
    ax.scatter(est_n, y, marker="*", s=160, color="#d62728", label="estimate", zorder=4)
    for yi, name, e, t in zip(y, names, est, truth):
        ax.annotate(f"est {e:.4g} / guv {t:.4g}", (1.02, yi),
                    va="center", ha="left", fontsize=7, annotation_clip=False)
    ax.set_yticks(y)
    ax.set_yticklabels(names, fontsize=8)
    ax.set_xlim(0, 1)
    ax.set_xlabel("position within [lower, upper] search bounds")
    ax.set_title(f"Estimated minimum vs. Guvenen value ({n} free parameter"
                 f"{'s' if n != 1 else ''})")
    ax.legend(loc="lower right", fontsize=8, framealpha=0.9)
    ax.margins(y=0.02)
    fig.tight_layout()
    fig.savefig(out_path, dpi=140)
    plt.close(fig)
    print(f"  wrote {out_path}")


def plot_slices(prob, objective, est, truth, out_path, grid):
    names = prob.FREE_NAMES
    lo, hi = prob.FREE_BOUNDS[:, 0], prob.FREE_BOUNDS[:, 1]
    est = np.asarray(est, float)
    n = len(names)
    ncols = 1 if n == 1 else (2 if n <= 4 else (3 if n <= 9 else 5))
    nrows = int(np.ceil(n / ncols))

    fig, axes = plt.subplots(nrows, ncols, figsize=(3.4 * ncols, 2.5 * nrows),
                             squeeze=False)
    axes_flat = axes.ravel()
    for j in range(n):
        ax = axes_flat[j]
        xs = np.linspace(lo[j], hi[j], grid)
        qs = np.empty(grid)
        for g, xv in enumerate(xs):
            x = est.copy()
            x[j] = xv
            qs[g] = objective(x)
        ax.plot(xs, qs, color="#333333", lw=1.3)
        ax.axvline(est[j], color="#d62728", lw=1.4, label="estimate")
        ax.axvline(truth[j], color="#1f77b4", lw=1.2, ls="--", label="Guvenen")
        ax.set_yscale("log")
        ax.set_title(names[j], fontsize=9)
        ax.tick_params(labelsize=7)
    for j in range(n, len(axes_flat)):
        axes_flat[j].axis("off")
    axes_flat[0].legend(loc="upper center", fontsize=7, framealpha=0.9)
    fig.suptitle("Objective slices: Q(theta) along each free parameter "
                 "(others held at the estimate)", fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    fig.savefig(out_path, dpi=140)
    plt.close(fig)
    print(f"  wrote {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("workdir", help="run directory containing final_results.json")
    ap.add_argument("--grid", type=int, default=41,
                    help="points per objective slice (default 41)")
    ap.add_argument("--real-moments", default=None,
                    help="data dir if the run used real moments (else synthetic)")
    args = ap.parse_args()

    summary = load_run(args.workdir)
    est = np.asarray(summary["estimate"], float)
    truth = np.asarray(summary["truth"], float)
    print(f"Run: {summary.get('n_free', len(est))} free params, "
          f"objective={summary['objective']:.4e}")

    print("Building figures (rebuilding objective for the slices) ...")
    prob, objective = rebuild_objective(summary, args.real_moments)

    plot_recovery(prob, est, truth, os.path.join(args.workdir, "params_vs_guvenen.png"))
    plot_slices(prob, objective, est, truth,
                os.path.join(args.workdir, "objective_slices.png"), args.grid)
    print("Done.")


if __name__ == "__main__":
    main()
