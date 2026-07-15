"""
impulse_repagent.py
===================
Simulation-side mirror of the GKOS 2016 workbook impulse-response moments
(sheets ``impulse log``), whose data construction is documented in
``impulse_LABOR_repagent_DIB.do`` + ``main_impulse_LABOR_repagent_DIB.do``.
Used by the single-sex (gender) estimation, where both sexes target their own
workbook sheet; the full-model men's replication keeps the estimation-version
impulse (``ImpulseA_mean.dat``, moments.py Section D) unchanged.

Construction (data | sim analog):
  * benchmark = year t, worker observed at t-1; age(t-1) in [25,50] with
    age(t+10) <= 60  |  panel index h = t-1, ages 27..49 (h = 2..24; the sim
    panel starts at age 25, so the youngest benchmarks need >= 3 past years
    for the RE window -- same young-end convention as moments.py Section D).
  * age bins: age(t-1) <= 34 / >= 35  |  h <= 9 / h >= 10.
  * RE (recent earnings) = mean over the last kk = min(h+1, 5) years of
    max(y, rmininc), requiring >= MINOBS years above rmininc and y(t-1) above
    rmininc (the do-file's numobs -5 penalty); residualized as
    ln(RE) - ln(age-mean of RE).
  * selection: positive earnings at t-1 and t (log version; the extensive
    margin is carried by the EmpCDF block).
  * shock = ln(y_t) - ln(y_{t-1}), demeaned by age(t-1).
  * levels normalized by their age(t-1)-specific selected-sample means.
  * within age bin: 100-tile the RE residual, collapse to 21 groups
    (nineteen 5-percentile bins, 96-99, 100); within (agebin, RE group):
    20-tile the shock.
  * "representative agent" per (agebin, RE group, shock rank) cell: means of
    the normalized levels, then log changes of the means --
    shock_cell = ln(mean res_t) - ln(mean res_{t-1});
    resp_k     = ln(mean res_{t+k}) - ln(mean res_t),  k in {1,2,3,5,10}.

Output layout (matches gender_targets.load_impulse_xlsx): array
(2, 21, 20, 10) with columns 0-4 the per-horizon shocks (zero-weighted
diagnostics; the sim shock is horizon-invariant and is duplicated) and columns
5-9 the responses at horizons 1,2,3,5,10. Empty cells are left at 0.0
(the same convention as the other moment kernels' empty bins).
"""

import numpy as np

from moments import RMINWAGE, MINOBS

HORIZONS = (1, 2, 3, 5, 10)
NRE = 21          # RE groups per age bin
NSHK = 20         # shock-quantile groups per (agebin, RE) cell
NHOR = len(HORIZONS)
H_LO, H_HI = 2, 24          # benchmark indices h = t-1 (ages 27..49 incl.)
AGEBIN_SPLIT = 9            # h <= 9 (age <= 34) -> bin 0, else bin 1


def _quantile_groups(key, ngroups):
    """Equal-count quantile group (0..ngroups-1) of each element of ``key``
    (1-D, no missings). Ties broken by sort order — keys are continuous in the
    simulated panel, so this matches Stata's xtile up to measure-zero ties."""
    n = key.size
    order = np.argsort(key, kind="stable")
    grp = np.empty(n, dtype=np.int64)
    grp[order] = (np.arange(n, dtype=np.int64) * ngroups) // n
    return grp


def _re_group(pctile):
    """Map a 0-based percentile (0..99) to the 21 workbook RE groups (0-based):
    0-94 -> nineteen 5-percentile bins, 95-98 -> group 19, 99 -> group 20."""
    g = pctile // 5
    g = np.where(pctile >= 95, 19, g)
    g = np.where(pctile >= 99, 20, g)
    return g


def repagent_impulse(ysim):
    """Compute the representative-agent impulse moments from a simulated panel
    ``ysim`` of shape (nsim, hmax) (hmax = 36, ages 25..60).

    Returns an array of shape (2, NRE, NSHK, 2*NHOR).
    """
    nsim, hmax = ysim.shape
    h_hi = min(H_HI, hmax - HORIZONS[-1] - 2)   # need h + 1 + 10 <= hmax - 1

    # ---- per-benchmark-age records, pooled ---------------------------------
    ab_list, re_list, shk_list = [], [], []
    lev_list = []                                # (n_sel, 2 + NHOR) levels
    for h in range(H_LO, h_hi + 1):
        y_tm1 = ysim[:, h]
        y_t = ysim[:, h + 1]

        kk = min(h + 1, 5)
        win = ysim[:, h - kk + 1:h + 1]
        api = np.maximum(win, RMINWAGE).sum(axis=1) / kk
        numobs = (win >= RMINWAGE).sum(axis=1) - 5 * (y_tm1 < RMINWAGE)
        re_valid = numobs >= MINOBS

        # RE residual: age-mean over RE-valid obs (before the t-positivity drop,
        # as in the do-file's egen-then-drop ordering).
        if not re_valid.any():
            continue
        agedum = api[re_valid].mean()
        sel = re_valid & (y_t > 0.0)
        if not sel.any():
            continue
        avgres = np.log(api[sel]) - np.log(agedum)

        yb, yt = y_tm1[sel], y_t[sel]
        shock = np.log(yt) - np.log(yb)
        shock -= shock.mean()                    # age-demeaned

        levs = np.empty((sel.sum(), 2 + NHOR))
        levs[:, 0] = yb / yb.mean()              # res_{t-1}
        levs[:, 1] = yt / yt.mean()              # res_t
        for j, k in enumerate(HORIZONS):
            yf = ysim[sel, h + 1 + k]
            m = yf.mean()
            levs[:, 2 + j] = yf / m if m > 0 else 0.0

        ab_list.append(np.full(sel.sum(), 0 if h <= AGEBIN_SPLIT else 1,
                               dtype=np.int64))
        re_list.append(avgres)
        shk_list.append(shock)
        lev_list.append(levs)

    out = np.zeros((2, NRE, NSHK, 2 * NHOR))
    if not ab_list:
        return out
    agebin = np.concatenate(ab_list)
    avgres = np.concatenate(re_list)
    shock = np.concatenate(shk_list)
    levs = np.vstack(lev_list)

    # ---- RE groups within age bin ------------------------------------------
    re_grp = np.empty(agebin.size, dtype=np.int64)
    for a in (0, 1):
        m = agebin == a
        if m.any():
            re_grp[m] = _re_group(_quantile_groups(avgres[m], 100))

    # ---- shock ranks within (agebin, RE group) -----------------------------
    cell = agebin * NRE + re_grp                 # 0..2*NRE-1
    shk_grp = np.empty(agebin.size, dtype=np.int64)
    order = np.lexsort((shock, cell))
    cs = cell[order]
    starts = np.flatnonzero(np.r_[True, cs[1:] != cs[:-1]])
    sizes = np.diff(np.r_[starts, cs.size])
    pos = np.arange(cs.size) - np.repeat(starts, sizes)
    shk_grp[order] = (pos * NSHK) // np.repeat(sizes, sizes)

    # ---- representative-agent statistics per cell --------------------------
    cid = cell * NSHK + shk_grp                  # 0 .. 2*NRE*NSHK-1
    ncell = 2 * NRE * NSHK
    cnt = np.bincount(cid, minlength=ncell).astype(float)
    nz = cnt > 0
    means = np.zeros((ncell, 2 + NHOR))
    for c in range(2 + NHOR):
        means[nz, c] = np.bincount(cid, weights=levs[:, c],
                                   minlength=ncell)[nz] / cnt[nz]

    ok = nz & (means[:, 0] > 0) & (means[:, 1] > 0)
    shock_cell = np.zeros(ncell)
    shock_cell[ok] = np.log(means[ok, 1]) - np.log(means[ok, 0])
    resp = np.zeros((ncell, NHOR))
    for j in range(NHOR):
        okj = ok & (means[:, 2 + j] > 0)
        resp[okj, j] = np.log(means[okj, 2 + j]) - np.log(means[okj, 1])

    out[..., :NHOR] = shock_cell.reshape(2, NRE, NSHK)[..., None]
    out[..., NHOR:] = resp.reshape(2, NRE, NSHK, NHOR)
    return out
