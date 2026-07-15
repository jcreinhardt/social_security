"""
freeze_gender_targets.py
========================
Collapse the GKOS_2016 moment workbooks (men + women) into the estimation-grid
target vectors and persist them as numpy .npz caches under
``<data>/gender_targets/{men,women}.npz``.

Run this ONCE locally (where openpyxl + the .xlsx files live); the cluster run
then loads the small .npz caches with numpy alone — no openpyxl, no .xlsx.

  python code/freeze_gender_targets.py --data data
"""
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "algorithm"))

from gender_targets import freeze, build_gender_target  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data",
                    help="dir holding GKOS_2016_moments_{men,women}.xlsx")
    args = ap.parse_args()

    for sex in ("men", "women"):
        out = freeze(sex, args.data)
        m, _, w, psi = build_gender_target(sex, args.data)  # round-trips via cache
        print(f"{sex:5s}: wrote {out}  "
              f"(n={m.size}, targeted={int((w > 0).sum())}, "
              f"|m_target| sum={np.abs(m).sum():.3f})")


if __name__ == "__main__":
    main()
