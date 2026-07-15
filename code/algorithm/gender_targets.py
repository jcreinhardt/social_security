"""
gender_targets.py
=================
Build MSM target moments for a SINGLE SEX (men or women) from the published
GKOS 2016 moment workbooks (``data/GKOS_2016_moments_{men,women}.xlsx``) plus
the PUF-constructed employment CDF, together with the matching simulation-side
moment/flatten functions, so the existing objective/optimizer/monitor stack
runs unchanged via ``Problem(gender=...)``.

The gender runs use their OWN flat moment layout (they already have their own
npz cache and Problem branch):

  * SdSkewKurt_L1   <- sheet ``L1_arc_age_re``  (1-yr arc-% growth)   117
  * SdSkewKurt_L5   <- sheet ``L5_arc_age_re``  (5-yr arc-% growth)   117
  * ir_repagent     <- sheet ``impulse log``    (repagent impulse)    8400
                       (2 age bins x 21 RE grps x 20 shock ranks x
                        [5 shocks | 5 responses]; only responses are
                        weighted -- shocks are diagnostics -- and the 42
                        all-zero shock-rank-10 anchor cells are excluded:
                        3990 weighted)
  * incgrwth        <- sheet ``incgrowth``      (mean earnings by LE pctile) 120
  * EmpCDF          <- men: data/intermediate/EmpCDF.dat (Guvenen MEF);
                       women: gender_targets/EmpCDF_women_pufadj.dat
                       (SSA 2004 PUF, gap-adjusted via men; see
                       code/build_puf_empcdf.py)                       37 (36 wtd)

Total 4380 targeted moments per sex. Dropped: ``var_lny`` (absent for women;
PUF substitute would inherit taxable-max top-coding bias). The workbook impulse
is the "representative agent" construction of impulse_LABOR_repagent_DIB.do --
NOT the estimation's ImpulseA_mean grid -- and is mirrored on the simulation
side by ``impulse_repagent.repagent_impulse`` and matched rank-to-rank; the
full-model men's replication keeps ImpulseA_mean.dat unchanged.

Block weights renormalize Guvenen's sevenths after dropping var_lny only:
SSK 1/3, impulse-short (t+1,2,3) 1/6, impulse-long (t+5,10) 1/6, incgrwth 1/6,
EmpCDF 1/6.

The SSK/incgrowth collapse from the workbook's fine grid to the estimation grid
was validated against the existing men ``.dat`` targets: it reproduces
``SdSkewKurt_L1/L5.dat`` to ~1e-6 and ``meanLTinc_level.dat`` exactly (the
``.dat`` is in $000s, hence the /1000). See ``code/tests/test_gender_targets.py``.
"""

import os

import numpy as np

from moments import (NVASEINC, NVASEMNT, NLTINCPCT, LTH, calculate_moments)
from impulse_repagent import NRE, NSHK, NHOR, repagent_impulse

# Percentile breakpoints used by the simulation moment kernels (moments.py), so
# the workbook's per-percentile rows aggregate into exactly our bins.
VASEINCPCT = np.array([1, 2, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 100, 101])
LTINCPCT = np.array([1, 2, 6, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 98, 100, 101])

IR_SHAPE = (2, NRE, NSHK, 2 * NHOR)

# Objective block-weight shares among the KEPT blocks: Guvenen's sevenths
# (SSK 2, IR-short 1, IR-long 1, incgrwth 1, var_lny 1, EmpCDF 1) minus the
# dropped var_lny, renormalized (x 7/6).
_SSK_SHARE = (2.0 / 7.0) * (7.0 / 6.0)      # 1/3
_IRS_SHARE = (1.0 / 7.0) * (7.0 / 6.0)      # 1/6  (responses at t+1,2,3)
_IRL_SHARE = (1.0 / 7.0) * (7.0 / 6.0)      # 1/6  (responses at t+5,10)
_INCG_SHARE = (1.0 / 7.0) * (7.0 / 6.0)     # 1/6
_EMP_SHARE = (1.0 / 7.0) * (7.0 / 6.0)      # 1/6
# Guvenen scale floors for the deviation denominator (OBJECTIVE.f90 scale_moments).
_SSK_PSI = 0.05
_IR_PSI = 0.0403


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


def load_impulse_xlsx(path, sheet="impulse log"):
    """Sheet ``impulse log`` -> (2, 21, 20, 10): per (agebin, RE group, shock
    rank) cell, columns 0-4 are the shocks and 5-9 the responses at horizons
    t+1,2,3,5,10 (the sheet interleaves them as Shock/Resp pairs). Absent cells
    are NaN (the log sheets are complete for both sexes; this is a safety net —
    NaN cells get zero weight in the target)."""
    arr = np.full(IR_SHAPE, np.nan)
    for r in _read_sheet(path, sheet):
        a, g, s = int(r[0]) - 1, int(r[1]) - 1, int(r[2]) - 1
        vals = [np.nan if v is None else float(v) for v in r[3:13]]
        arr[a, g, s, :NHOR] = vals[0::2]      # shocks
        arr[a, g, s, NHOR:] = vals[1::2]      # responses
    return arr


def load_empcdf(sex, data_dir):
    """Men: Guvenen's MEF-based EmpCDF.dat. Women: the SSA-PUF CDF gap-adjusted
    via men (built by code/build_puf_empcdf.py)."""
    if sex == "men":
        path = os.path.join(data_dir, "intermediate", "EmpCDF.dat")
    else:
        path = os.path.join(data_dir, "gender_targets", "EmpCDF_women_pufadj.dat")
    arr = np.loadtxt(path)
    if arr.shape != (37,):
        raise ValueError(f"EmpCDF at {path} has shape {arr.shape}, expected (37,)")
    return arr


# ---- flat layout (shared by target and simulated moments) -------------------

def flatten_gender_moments(mom_dict):
    """Flatten the gender moment dict into a single 1-D vector.
    Order: SSK_L1, SSK_L5, ir_repagent, incgrwth, EmpCDF.

    Returns:
        vec: 1-D array
        slices: dict mapping moment name -> (start_idx, end_idx)
    """
    arrays = [
        ('SdSkewKurt_L1', mom_dict['SdSkewKurt_L1'].ravel()),
        ('SdSkewKurt_L5', mom_dict['SdSkewKurt_L5'].ravel()),
        ('ir_repagent', mom_dict['ir_repagent'].ravel()),
        ('incgrwth', mom_dict['incgrwth'].ravel()),
        ('EmpCDF', mom_dict['EmpCDF'].ravel()),
    ]
    parts = []
    slices = {}
    idx = 0
    for name, arr in arrays:
        slices[name] = (idx, idx + len(arr))
        parts.append(arr)
        idx += len(arr)
    return np.concatenate(parts), slices


def calculate_gender_moments(ysim):
    """Simulation-side gender moments: the shared SSK/incgrwth/EmpCDF kernels
    plus the representative-agent impulse (var_lny and the estimation-grid
    irmoments are not targeted for the gender runs)."""
    full = calculate_moments(ysim)
    return {
        'SdSkewKurt_L1': full['SdSkewKurt_L1'],
        'SdSkewKurt_L5': full['SdSkewKurt_L5'],
        'ir_repagent': repagent_impulse(ysim),
        'incgrwth': full['incgrwth'],
        'EmpCDF': full['EmpCDF'],
    }


def _canonical_slices():
    """Slices for the flattened moment vector — deterministic from the block
    shapes, so the cache path can rebuild them without re-reading the workbook."""
    zero = {
        "SdSkewKurt_L1": np.zeros((3, NVASEINC, NVASEMNT)),
        "SdSkewKurt_L5": np.zeros((3, NVASEINC, NVASEMNT)),
        "ir_repagent": np.zeros(IR_SHAPE),
        "incgrwth": np.zeros((NLTINCPCT, LTH)),
        "EmpCDF": np.zeros(37),
    }
    _, slices = flatten_gender_moments(zero)
    return slices


def _cache_path(sex, data_dir):
    return os.path.join(data_dir, "gender_targets", f"{sex}.npz")


def _build_from_xlsx(sex, data_dir):
    """Collapse the workbook + EmpCDF file into ``(m_target, slices, w_diag,
    psi)``. Requires openpyxl + the GKOS_2016_moments_{sex}.xlsx file (and, for
    women, the PUF-built EmpCDF_women_pufadj.dat)."""
    path = _xlsx_path(sex, data_dir)
    if not os.path.exists(path):
        raise FileNotFoundError(f"moment workbook not found: {path}")

    mom = {
        "SdSkewKurt_L1": collapse_ssk(load_ssk_xlsx(path, "L1_arc_age_re")),
        "SdSkewKurt_L5": collapse_ssk(load_ssk_xlsx(path, "L5_arc_age_re")),
        "ir_repagent": load_impulse_xlsx(path),
        "incgrwth": collapse_incgrowth(load_incgrowth_xlsx(path)),
        "EmpCDF": load_empcdf(sex, data_dir),
    }
    m_target, slices = flatten_gender_moments(mom)

    n = len(m_target)
    w = np.zeros(n)
    psi = np.zeros(n)

    ssk_idx = np.concatenate([np.arange(*slices[k])
                              for k in ("SdSkewKurt_L1", "SdSkewKurt_L5")])
    w[ssk_idx] = _SSK_SHARE / ssk_idx.size
    psi[ssk_idx] = _SSK_PSI

    # Impulse: weight only the response columns (5-9), split short (t+1,2,3) /
    # long (t+5,10) like Guvenen; the shock columns (0-4) are diagnostics. NaN
    # cells (absent in the workbook) get zero weight and a zero target, and so
    # do the shock-rank-10 cells, which the workbook zeroes out identically
    # (the exact-zero-change point mass is an anchor row, not an estimate).
    s0, _ = slices["ir_repagent"]
    ir = mom["ir_repagent"]
    anchor = np.all(ir == 0.0, axis=-1, keepdims=True)     # (2,21,20,1)
    for cols, share in (((5, 6, 7), _IRS_SHARE), ((8, 9), _IRL_SHARE)):
        mask = np.zeros(IR_SHAPE, dtype=bool)
        mask[..., list(cols)] = True
        mask &= ~np.isnan(ir) & ~anchor
        idx = s0 + np.flatnonzero(mask.ravel())
        w[idx] = share / idx.size
        psi[idx] = _IR_PSI
    m_target = np.nan_to_num(m_target, nan=0.0)

    incg_idx = np.arange(*slices["incgrwth"])
    w[incg_idx] = _INCG_SHARE / incg_idx.size

    e0, e1 = slices["EmpCDF"]
    emp_idx = np.arange(e0, e1 - 1)          # last point is the forced 100
    w[emp_idx] = _EMP_SHARE / emp_idx.size

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
    openpyxl). ``m_target`` is in flatten_gender_moments order; the impulse
    shock columns and the final EmpCDF point carry zero weight.
    """
    cache = _cache_path(sex, data_dir)
    if os.path.exists(cache):
        z = np.load(cache)
        m_target = z["m_target"]
        # Stale-cache guard: pre-impulse caches are shorter than the current
        # layout — force a rebuild rather than fitting the wrong target.
        if m_target.size == sum(e - s for s, e in _canonical_slices().values()):
            return m_target, _canonical_slices(), z["w_diag"], z["psi"]
    return _build_from_xlsx(sex, data_dir)
