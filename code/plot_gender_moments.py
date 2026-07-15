"""
plot_gender_moments.py
======================
Data-side men-vs-women comparison of the collapsed GKOS-2016 + PUF target
moments the single-sex estimation actually fits (``gender_targets.build_gender_
target``). No parameter estimates are involved — this is purely the *targets*
the SMM objective sees for each sex, so it visualizes the "compare the male vs
female moments" step end-to-end on the estimation grid.

Six panels (5-yr arc-% earnings change SdSkewKurt by recent-earnings percentile;
lifecycle earnings growth and level by lifetime-earnings percentile; the
employment-years CDF). ``var_lny`` is intentionally absent: the women's GKOS
workbook has no variance-of-log sheet, so that block is dropped from both sexes'
objective and cannot be compared here.

  python code/plot_gender_moments.py [--data data] [--out output/gender_moments]
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "algorithm"))

import gender_targets as gt          # noqa: E402
from moments import NVASEINC, NVASEMNT, NLTINCPCT, LTH  # noqa: E402

# Percentile-bin midpoints for the x-axes (the collapse averages each raw
# percentile range into one bin; plot at the range midpoint).
_VASE_MID = 0.5 * (gt.VASEINCPCT[:-1] + gt.VASEINCPCT[1:] - 1)   # 13 RE bins
_LT_MID = 0.5 * (gt.LTINCPCT[:-1] + gt.LTINCPCT[1:] - 1)         # 15 LE bins
_AGES = np.arange(25, 61, 5)                                     # incgrwth columns 25..60


def _blocks(sex, data):
    m, sl, _, _ = gt.build_gender_target(sex, data)
    l5 = m[slice(*sl["SdSkewKurt_L5"])].reshape(3, NVASEINC, NVASEMNT)
    inc = m[slice(*sl["incgrwth"])].reshape(NLTINCPCT, LTH)
    emp = m[slice(*sl["EmpCDF"])]
    return l5.mean(axis=0), inc, emp        # SSK averaged over the 3 age bins


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--out", default="output/gender_moments")
    args = ap.parse_args()

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    men = _blocks("men", args.data)
    women = _blocks("women", args.data)
    colors = {"men": "C0", "women": "C3"}

    fig, ax = plt.subplots(2, 3, figsize=(15, 9))
    a55, a25 = np.where(_AGES == 55)[0][0], np.where(_AGES == 25)[0][0]

    for label, (ssk, inc, emp) in (("men", men), ("women", women)):
        c = colors[label]
        for k, (title, ylab) in enumerate(
                [("A. SD of 5-yr arc % change", "std dev"),
                 ("B. Skewness of 5-yr arc % change", "skewness"),
                 ("C. Kurtosis of 5-yr arc % change", "kurtosis")]):
            ax[0, k].plot(_VASE_MID, ssk[:, k], "-o", color=c, ms=4, label=label)
            ax[0, k].set_title(title)
            ax[0, k].set_xlabel("recent-earnings percentile")
            ax[0, k].set_ylabel(ylab)
        # D. lifecycle earnings growth log(mean age55) - log(mean age25)
        growth = np.log(inc[:, a55]) - np.log(inc[:, a25])
        ax[1, 0].plot(_LT_MID, growth, "-o", color=c, ms=4, label=label)
        # E. mean lifetime earnings LEVEL ($000s) by LE pctile
        ax[1, 1].plot(_LT_MID, inc.mean(axis=1), "-o", color=c, ms=4, label=label)
        # F. employment-years CDF
        ax[1, 2].plot(np.arange(emp.size), emp, "-", color=c, lw=2, label=label)

    ax[1, 0].set(title="D. Lifecycle earnings growth", xlabel="lifetime-earnings percentile",
                 ylabel="log(earn@55) - log(earn@25)")
    ax[1, 1].set(title="E. Mean lifetime earnings level", xlabel="lifetime-earnings percentile",
                 ylabel="mean earnings ($000s)")
    ax[1, 1].set_yscale("log")
    ax[1, 2].set(title="F. Employment-years CDF (PUF)",
                 xlabel="years employed, age 25-60 ($\\leq k$)", ylabel="CDF (%)")
    for a in ax.ravel():
        a.grid(alpha=0.3)
        a.legend()
    fig.suptitle("GKOS-2016 + PUF estimation targets: men vs women "
                 "(SSK averaged over the 3 age bins)", fontsize=13)
    fig.tight_layout(rect=(0, 0, 1, 0.97))

    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, "gender_targets_men_vs_women.png")
    fig.savefig(path, dpi=150)
    print(f"wrote {path}")
    # A couple of headline gaps for the writeup.
    print(f"EmpCDF P[emp<=10]:  men {men[2][10]:.1f}%  women {women[2][10]:.1f}%")
    print(f"top-bin lifetime earn ($000s):  men {men[1].mean(1)[-1]:.0f}  "
          f"women {women[1].mean(1)[-1]:.0f}")


if __name__ == "__main__":
    main()
