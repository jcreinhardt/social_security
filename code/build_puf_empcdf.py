"""
build_puf_empcdf.py
===================
Construct the employment-years CDF (the ``EmpCDF`` MSM target) for men and
women from the SSA 2004 OASDI Public-Use Files, and produce a gap-adjusted
women's target for the gender estimation.

Guvenen's EmpCDF (EmpCDF_ByAge.do, on the male MEF panel 1978-2013) counts, for
each person, the years between ages 25 and 60 with labor earnings above
Y_min(t) = 40*13*0.5*minwage(t), and reports ecdf[i] = 100*P(emp <= i) for
i = 0..35 plus a forced 100 at i = 36. The PUF only observes earnings 1951-2003
and only for December-2004 beneficiaries, so we mirror the construction on
cohorts born 1927-44 (whose full age-25-60 window lies inside 1951-2003; age
convention: age = year - yob + 1), using ALL beneficiary types (restricting to
retired workers would truncate the low-attachment left tail, especially for
women). PUF earnings are nominal, so the threshold is applied nominally.

The PUF CDF is still biased relative to Guvenen's (benefit-receipt
conditioning, survivorship to 2004, older cohorts), so the women's target is
gap-adjusted through men: women_adj = women_puf + (EmpCDF.dat - men_puf),
clipped to [0, 100] and made monotone.

Outputs (37 values each, same format as data/intermediate/EmpCDF.dat):
    data/gender_targets/EmpCDF_men_puf.dat        raw men PUF CDF (diagnostic)
    data/gender_targets/EmpCDF_women_puf.dat      raw women PUF CDF (diagnostic)
    data/gender_targets/EmpCDF_women_pufadj.dat   gap-adjusted women target
    output/gender_moments/empcdf_puf_gapadj.png   diagnostic plot

Run locally (needs the raw PUF text files): conda env socsec_mac.
"""

import argparse
import os

import numpy as np

YEARS = np.arange(1951, 2004)           # PUF covered earnings years
YOB_LO, YOB_HI = 1927, 1944             # full age-25-60 window inside 1951-2003

# Nominal federal minimum wage. 1951-55: $0.75; 1956-58: $1.00; 1959-2013 from
# the minwg matrix in EmpCDF_ByAge.do / main_YRCHANGE_LABOR_DIB.do.
MINWG_5913 = [1.00, 1.00, 1.00, 1.15, 1.15, 1.25, 1.25, 1.25, 1.25, 1.40,
              1.60, 1.60, 1.60, 1.60, 1.60, 1.60, 2.00, 2.10, 2.10, 2.30,
              2.65, 2.90, 3.10, 3.35, 3.35, 3.35, 3.35, 3.35, 3.35, 3.35,
              3.35, 3.35, 3.80, 4.25, 4.25, 4.25, 4.25, 4.25, 4.75, 5.15,
              5.15, 5.15, 5.15, 5.15, 5.15]                     # 1959-2003
MINWG = np.array([0.75] * 5 + [1.00] * 3 + MINWG_5913)          # 1951-2003
YMIN = 40 * 13 * 0.5 * MINWG            # Guvenen's Y_min, applied nominally


def parse_earnings(path, cache):
    """Earnings PUF: 279-char records wrapped over 6 CRLF lines. ID chars 1-6,
    SSTE1951-2003 in 5-char fields from position 15. Returns (ids, earn)."""
    if os.path.exists(cache):
        z = np.load(cache)
        return z["eids"], z["earn"]
    with open(path) as f:
        lines = [ln.rstrip("\r\n") for ln in f]
    records = ["".join(lines[i:i + 6]) for i in range(0, len(lines), 6)]
    eids = np.array([int(r[0:6]) for r in records])
    earn = np.array([[float(r[14 + 5 * k:19 + 5 * k]) for k in range(53)]
                     for r in records])
    np.savez(cache, eids=eids, earn=earn)
    return eids, earn


def parse_benefits(path):
    """Benefits PUF (46-char lines): ID 1-6, YOB 7-10, SEX 11-12.
    Returns (ids, yob, sex) with sex as 'M'/'F'."""
    ids, yob, sex = [], [], []
    with open(path) as f:
        for ln in f:
            if len(ln) < 12:
                continue
            ids.append(int(ln[0:6]))
            yob.append(int(ln[6:10]))
            sex.append(ln[10:12].strip())
    return np.array(ids), np.array(yob), np.array(sex)


def emp_years(earn, yob):
    """Years with earnings > Y_min within ages 25-60 (age = year - yob + 1)."""
    n = earn.shape[0]
    emp = np.zeros(n, dtype=int)
    age = YEARS[None, :] - yob[:, None] + 1
    inwin = (age >= 25) & (age <= 60)
    emp = ((earn > YMIN[None, :]) & inwin).sum(axis=1)
    return emp


def empcdf(emp):
    """ecdf[i] = 100*P(emp <= i), i = 0..35; ecdf[36] = 100."""
    out = np.zeros(37)
    for i in range(36):
        out[i] = 100.0 * np.mean(emp <= i)
    out[36] = 100.0
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--out", default="output/gender_moments")
    ap.add_argument("--cache", default=os.environ.get(
        "PUF_CACHE", os.path.join(os.path.dirname(__file__), "..", "data",
                                  "SSA_PUF_2004", "earn_cache.npz")))
    args = ap.parse_args()

    puf = os.path.join(args.data, "SSA_PUF_2004")
    eids, earn = parse_earnings(
        os.path.join(puf, "earnings04text", "OASDI Earnings PUF December 2004.txt"),
        args.cache)
    bids, yob, sex = parse_benefits(
        os.path.join(puf, "benefits04text", "OASDI Benefits PUF December 2004.txt"))
    print(f"earnings records: {len(eids):,};  beneficiaries: {len(bids):,}")

    # Link: beneficiaries with an earnings record, cohorts 1927-44 (any TOB).
    id2row = {int(i): k for k, i in enumerate(eids)}
    linked = np.array([int(i) in id2row for i in bids])
    coh = linked & (yob >= YOB_LO) & (yob <= YOB_HI)
    print(f"linked to earnings: {linked.sum():,};  born {YOB_LO}-{YOB_HI}: {coh.sum():,}")

    target = np.loadtxt(os.path.join(args.data, "intermediate", "EmpCDF.dat"))
    assert target.shape == (37,)

    cdfs = {}
    for label, code in (("men", "M"), ("women", "F")):
        sel = coh & (sex == code)
        rows = np.array([id2row[int(i)] for i in bids[sel]])
        emp = emp_years(earn[rows], yob[sel])
        cdfs[label] = empcdf(emp)
        print(f"{label}: n = {sel.sum():,}; share <=10 employed years = "
              f"{cdfs[label][10]:.2f}% (Guvenen men target: {target[10]:.2f}%)")

    # Gap-adjust women through men, then restore monotonicity.
    women_adj = np.clip(cdfs["women"] + (target - cdfs["men"]), 0.0, 100.0)
    women_adj = np.maximum.accumulate(women_adj)
    women_adj[36] = 100.0

    gt_dir = os.path.join(args.data, "gender_targets")
    os.makedirs(gt_dir, exist_ok=True)
    os.makedirs(args.out, exist_ok=True)
    np.savetxt(os.path.join(gt_dir, "EmpCDF_men_puf.dat"), cdfs["men"], fmt="%.4f")
    np.savetxt(os.path.join(gt_dir, "EmpCDF_women_puf.dat"), cdfs["women"], fmt="%.4f")
    np.savetxt(os.path.join(gt_dir, "EmpCDF_women_pufadj.dat"), women_adj, fmt="%.4f")

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    x = np.arange(37)
    fig, ax = plt.subplots(figsize=(9, 6))
    ax.plot(x, target, "k-", lw=2, label="Guvenen men (EmpCDF.dat, MEF)")
    ax.plot(x, cdfs["men"], "C0--", label="PUF men (raw)")
    ax.plot(x, cdfs["women"], "C3--", label="PUF women (raw)")
    ax.plot(x, women_adj, "C3-", lw=2, label="Women target (gap-adjusted)")
    ax.set_xlabel("Years employed between ages 25 and 60 ($\\leq$)")
    ax.set_ylabel("CDF (%)")
    ax.set_title("EmpCDF: SSA 2004 PUF (all beneficiaries, cohorts 1927-44)\n"
                 "vs Guvenen target; women gap-adjusted via men")
    ax.legend()
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(args.out, "empcdf_puf_gapadj.png"), dpi=150)
    print(f"wrote {gt_dir}/EmpCDF_*.dat and {args.out}/empcdf_puf_gapadj.png")


if __name__ == "__main__":
    main()
