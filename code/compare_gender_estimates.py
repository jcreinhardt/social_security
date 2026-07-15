"""
compare_gender_estimates.py
===========================
Tabulate the separately-estimated men and women parameter vectors next to
Guvenen et al.'s published (men) estimate, and plot the model-implied vs.
target moments (SSK + incgrwth, the common subset) for each sex.

Usage:
  python code/compare_gender_estimates.py \
      --men    output/run_gender_men/final_results.json \
      --women  output/run_gender_women/final_results.json \
      --out    output/gender_compare
"""
import argparse
import json
import os
import sys

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "algorithm"))

from params import PARAM_NAMES, THETA_TRUE                # noqa: E402
from dgp import simulate_income, get_shocks               # noqa: E402
from moments import calculate_moments                     # noqa: E402
from gender_targets import (build_gender_target, VASEINCPCT,  # noqa: E402
                            collapse_ssk)

RE_X = np.array([1, 6, 15.5, 25.5, 35.5, 45.5, 55.5, 65.5, 75.5, 85.5, 93, 97.5, 100])


def load_est(path):
    if path is None or not os.path.exists(path):
        return None
    with open(path) as fh:
        return json.load(fh)


def table(men, women):
    guv = np.asarray(THETA_TRUE, float)
    me = np.asarray(men["estimate"], float) if men else None
    wo = np.asarray(women["estimate"], float) if women else None
    print("\n" + "=" * 78)
    print("PARAMETER ESTIMATES  (common-moment subset: SSK_L1 + SSK_L5 + incgrwth)")
    print("=" * 78)
    hdr = f"{'param':14s}{'Guvenen':>12s}{'men':>12s}{'women':>12s}{'men-Guv':>12s}{'wom-men':>12s}"
    print(hdr); print("-" * len(hdr))
    for i, name in enumerate(PARAM_NAMES):
        row = f"{name:14s}{guv[i]:12.5f}"
        row += f"{me[i]:12.5f}" if me is not None else f"{'--':>12s}"
        row += f"{wo[i]:12.5f}" if wo is not None else f"{'--':>12s}"
        row += f"{me[i]-guv[i]:+12.5f}" if me is not None else f"{'--':>12s}"
        row += f"{wo[i]-me[i]:+12.5f}" if (me is not None and wo is not None) else f"{'--':>12s}"
        print(row)
    print("-" * len(hdr))
    if men:
        print(f"objective  men={men['objective']:.6e}", end="")
    if women:
        print(f"   women={women['objective']:.6e}", end="")
    print()


def model_ssk_incg(theta, n_sim, hmax, seed):
    sh = get_shocks(n_sim, hmax, seed)
    mom = calculate_moments(simulate_income(np.asarray(theta, float), n_sim, hmax, seed, shocks=sh))
    l5 = np.asarray(mom["SdSkewKurt_L5"]).mean(axis=0)   # (13,3) avg over age bins
    return l5, np.asarray(mom["incgrwth"])


def target_ssk(sex):
    """Target L5 SSK curve (13,3), age-bin-averaged, from the workbook."""
    from gender_targets import load_ssk_xlsx
    return collapse_ssk(load_ssk_xlsx(
        f"data/GKOS_2016_moments_{sex}.xlsx", "L5_arc_age_re")).mean(axis=0)


def plot(men, women, out, n_sim, hmax, seed):
    fig, ax = plt.subplots(2, 3, figsize=(16, 9))
    stats = ["Std Dev", "Skewness", "Kurtosis"]
    for r, (sex, est) in enumerate([("men", men), ("women", women)]):
        if est is None:
            continue
        tgt = target_ssk(sex)
        guv_l5, _ = model_ssk_incg(THETA_TRUE, n_sim, hmax, seed)
        est_l5, _ = model_ssk_incg(est["estimate"], n_sim, hmax, seed)
        for c in range(3):
            a = ax[r, c]
            a.plot(RE_X, tgt[:, c], "k--", lw=2, label=f"{sex} data")
            a.plot(RE_X, guv_l5[:, c], color="#1f77b4", marker="o", ms=3, label="Guvenen θ")
            a.plot(RE_X, est_l5[:, c], color="#d62728", marker="s", ms=3, label=f"{sex} est θ")
            a.set_title(f"{sex}: {stats[c]} of 5-yr arc-% change")
            a.set_xlabel("Recent-earnings percentile")
            if r == 0 and c == 0:
                a.legend(fontsize=8)
    fig.suptitle("Separately-estimated fit vs. workbook moments (5-yr SSK)", fontsize=14)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    os.makedirs(os.path.dirname(os.path.abspath(out + ".png")), exist_ok=True)
    fig.savefig(out + ".png", dpi=140)
    print(f"\nWrote {out}.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--men", default="output/run_gender_men/final_results.json")
    ap.add_argument("--women", default="output/run_gender_women/final_results.json")
    ap.add_argument("--out", default="output/gender_compare")
    ap.add_argument("--n-sim", type=int, default=100000)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--hmax", type=int, default=36)
    ap.add_argument("--no-plot", action="store_true")
    args = ap.parse_args()

    men, women = load_est(args.men), load_est(args.women)
    if men is None and women is None:
        sys.exit("no final_results.json found for either sex yet")
    table(men, women)
    if not args.no_plot:
        plot(men, women, args.out, args.n_sim, args.hmax, args.seed)


if __name__ == "__main__":
    main()
