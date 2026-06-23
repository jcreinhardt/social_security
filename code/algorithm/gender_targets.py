"""
gender_targets.py
=================
Build MSM target moments for a SINGLE SEX (men or women) from the published
GKOS 2016 moment workbooks (``data/GKOS_2016_moments_{men,women}.xlsx``), in the
same flattened layout ``moments.flatten_moments`` produces for the simulated
panel, so the existing objective/optimizer/monitor stack runs unchanged.

Only the moment blocks that are present for BOTH sexes AND map cleanly onto our
estimation grid are targeted:

  * SdSkewKurt_L1   <- sheet ``L1_arc_age_re``  (1-yr arc-% growth)
  * SdSkewKurt_L5   <- sheet ``L5_arc_age_re``  (5-yr arc-% growth)
  * incgrwth        <- sheet ``incgrowth``      (mean earnings by LE pctile/age)

Dropped: ``var_lny`` (absent for women), ``EmpCDF`` (absent for both), and the
impulse-response block (the workbook's ``impulse arc`` sheet is a different
moment construction than the estimation's ``ImpulseA_mean`` — it conditions on
recent-earnings groups x shock ranks, not avg-past-income bins x change
percentiles — and cannot be validated against the known men ``.dat``).

The collapse from the workbook's fine grid to our estimation grid was validated
against the existing men ``.dat`` targets: it reproduces ``SdSkewKurt_L1/L5.dat``
to ~1e-6 and ``meanLTinc_level.dat`` exactly (the ``.dat`` is in $000s, hence
the /1000 on earnings). See ``code/tests/test_gender_targets.py``.
"""

import os

import numpy as np

from moments import (NVASEINC, NVASEMNT, NLTINCPCT, LTH, NIRINC, NIRCHG, NLAG,
                     flatten_moments)

# Percentile breakpoints used by the simulation moment kernels (moments.py), so
# the workbook's per-percentile rows aggregate into exactly our bins.
VASEINCPCT = np.array([1, 2, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 100, 101])
LTINCPCT = np.array([1, 2, 6, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 98, 100, 101])

# Objective block-weight shares among the KEPT blocks. In the full Guvenen
# objective the Sd/Skew/Kurt block (L1+L5) is 2/7 and income-growth is 1/7;
# dropping the other five-sevenths and renormalizing leaves SSK 2/3, incg 1/3.
_SSK_SHARE = 2.0 / 3.0
_INCG_SHARE = 1.0 / 3.0
# Guvenen scale floors for the deviation denominator (OBJECTIVE.f90 scale_moments).
_SSK_PSI = 0.05
_INCG_PSI = 0.0


def _xlsx_path(sex, data_dir):
    sex = sex.lower()
    if sex not in ("men", "women"):
        raise ValueError(f"sex must be 'men' or 'women', got {sex!r}")
    return os.path.join(data_dir, f"GKOS_2016_moments_{sex}.xlsx")


def _read_sheet(path, sheet):
    import openpyxl  # lazy: only needed when building from the workbook, not the cache
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows = [r for r in wb[sheet].iter_rows(values_only=True)][1:]
    rows = [r for r in rows if r[0] is not None]
    wb.close()
    return rows


def load_ssk_xlsx(path, sheet):
    """Sheet L{1,5}_arc_age_re -> (6 age groups, 100 RE pctiles, 3 stats)."""
    arr = np.zeros((6, 100, 3))
    for r in _read_sheet(path, sheet):
        arr[int(r[0]) - 1, int(r[1]) - 1, :] = [r[2], r[3], r[4]]  # sd, skew, kurt
    return arr


def collapse_ssk(arr6):
    """(6,100,3) -> (3,13,3): average the 6 fine age groups into 3 bins (pairwise,
    matching NAGEBIN=[2,2,2]) and the 100 RE percentiles into the 13 VASEINCPCT
    bins (mean of per-percentile stats over each bin's percentile range)."""
    out = np.zeros((3, NVASEINC, NVASEMNT))
    for i in range(3):
        sub = arr6[2 * i:2 * i + 2].mean(axis=0)              # (100, 3)
        for j in range(NVASEINC):
            lo, hi = VASEINCPCT[j] - 1, VASEINCPCT[j + 1] - 1
            out[i, j, :] = sub[lo:hi].mean(axis=0)
    return out


def load_incgrowth_xlsx(path):
    """Sheet incgrowth -> (100 LE pctiles, 8 ages) of mean earnings at 25..60."""
    arr = np.zeros((100, LTH))
    for r in _read_sheet(path, "incgrowth"):
        arr[int(r[0]) - 1, :] = r[1:1 + LTH]                  # Earnings at 25..60
    return arr


def collapse_incgrowth(arr100):
    """(100,8) -> (15,8): average earnings over each LTINCPCT percentile bin and
    convert to $000s (the .dat meanLTinc_level is in thousands)."""
    out = np.zeros((NLTINCPCT, LTH))
    for j in range(NLTINCPCT):
        lo, hi = LTINCPCT[j] - 1, LTINCPCT[j + 1] - 1
        out[j] = arr100[lo:hi].mean(axis=0)
    return out / 1000.0


def _canonical_slices():
    """Slices for the flattened moment vector — deterministic from the block
    shapes, so the cache path can rebuild them without re-reading the workbook."""
    zero = {
        "SdSkewKurt_L1": np.zeros((3, NVASEINC, NVASEMNT)),
        "SdSkewKurt_L5": np.zeros((3, NVASEINC, NVASEMNT)),
        "irmoments": np.zeros((2, NIRINC, NIRCHG, NLAG + 1)),
        "incgrwth": np.zeros((NLTINCPCT, LTH)),
        "var_lny": np.zeros(36),
        "EmpCDF": np.zeros(37),
    }
    _, slices = flatten_moments(zero)
    return slices


def _cache_path(sex, data_dir):
    return os.path.join(data_dir, "gender_targets", f"{sex}.npz")


def _build_from_xlsx(sex, data_dir):
    """Collapse the workbook into ``(m_target, slices, w_diag, psi)``. Requires
    openpyxl + the GKOS_2016_moments_{sex}.xlsx file."""
    path = _xlsx_path(sex, data_dir)
    if not os.path.exists(path):
        raise FileNotFoundError(f"moment workbook not found: {path}")

    ssk_l1 = collapse_ssk(load_ssk_xlsx(path, "L1_arc_age_re"))
    ssk_l5 = collapse_ssk(load_ssk_xlsx(path, "L5_arc_age_re"))
    incg = collapse_incgrowth(load_incgrowth_xlsx(path))

    # Zero placeholders for the dropped blocks, in the exact shapes the simulated
    # moment dict has, so the flattened target aligns element-for-element.
    mom = {
        "SdSkewKurt_L1": ssk_l1,
        "SdSkewKurt_L5": ssk_l5,
        "irmoments": np.zeros((2, NIRINC, NIRCHG, NLAG + 1)),
        "incgrwth": incg,
        "var_lny": np.zeros(36),
        "EmpCDF": np.zeros(37),
    }
    m_target, slices = flatten_moments(mom)

    n = len(m_target)
    w = np.zeros(n)
    psi = np.zeros(n)
    ssk_idx = np.concatenate([np.arange(*slices[k])
                              for k in ("SdSkewKurt_L1", "SdSkewKurt_L5")])
    incg_idx = np.arange(*slices["incgrwth"])
    w[ssk_idx] = _SSK_SHARE / ssk_idx.size
    w[incg_idx] = _INCG_SHARE / incg_idx.size
    psi[ssk_idx] = _SSK_PSI
    psi[incg_idx] = _INCG_PSI
    return m_target, slices, w, psi


def freeze(sex, data_dir="data"):
    """Collapse the workbook and persist the target/weights to the npz cache
    (numpy-only, no openpyxl) so a cluster run needs neither the .xlsx nor
    openpyxl. Returns the cache path written."""
    m_target, _, w, psi = _build_from_xlsx(sex, data_dir)
    out = _cache_path(sex, data_dir)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    np.savez(out, m_target=m_target, w_diag=w, psi=psi)
    return out


def build_gender_target(sex, data_dir="data"):
    """Return ``(m_target, slices, w_diag, psi)`` for ``sex`` ('men'|'women').

    Prefers the frozen npz cache (``<data_dir>/gender_targets/<sex>.npz``,
    numpy-only); falls back to collapsing the .xlsx workbook directly (needs
    openpyxl). ``m_target`` is a full-length moment vector in flatten_moments
    order; the dropped blocks (irmoments, var_lny, EmpCDF) are zero and carry
    zero weight, so the objective compares only the targeted blocks.
    """
    cache = _cache_path(sex, data_dir)
    if os.path.exists(cache):
        z = np.load(cache)
        return z["m_target"], _canonical_slices(), z["w_diag"], z["psi"]
    return _build_from_xlsx(sex, data_dir)
