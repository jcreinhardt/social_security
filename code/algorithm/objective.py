"""
objective.py
============
The MSM objective, a faithful port of the Fortran ``dfovec`` / ``OBJ_FUNC``
(guvenen_2021_replication/.../Estimation/OBJECTIVE.f90):

  * scale-robust symmetric percentage deviation
        F_n = (d_n - m_n) / (0.5(|d_n| + |m_n|) + scale_n)
    with ``scale_n`` a FIXED per-block constant (Guvenen's ``scale_moments``,
    OBJECTIVE.f90:79), not data-driven;
  * block weights that give each economic moment group a fixed share of the
    objective (each 1/7, the Sd/Skew/Kurt block 2/7, impulse responses split
    into short- and long-lag 1/7 blocks), divided within a block by its moment
    count (OBJECTIVE.f90:152-172);
  * the scalar
        Q(theta) = sqrt( sum_n w_n F_n^2 )
    matching ``OBJ_FUNC = dsqrt(dot_product(verr, verr))`` (OBJECTIVE.f90:1430).
"""

import numpy as np

from params import PARAM_BOUNDS
from dgp import simulate_income, get_shocks
from moments import calculate_moments, flatten_moments

# Guvenen's fixed scale floors added to the deviation denominator, by moment
# block (OBJECTIVE.f90:79 scale_moments; the EmpCDF block adds nothing).
GUV_SCALE = {
    "SdSkewKurt_L1": 0.05,
    "SdSkewKurt_L5": 0.05,
    "irmoments": 0.0403,
    "incgrwth": 0.0,
    "var_lny": 0.0,
    "EmpCDF": 0.0,
}

# irmoments internal layout (moments.calculate_moments): the slice is a raveled
# (2, NIRINC, NIRCHG, NLAG+1) array, so within each consecutive group of NLAG+1
# the first entry is the conditioning income *change* (the interpolation x, NOT
# a targeted moment) and entries 1..NLAG are the responses at lags 1..NLAG.
# Guvenen targets only the responses, splitting short lags (1-3) and long lags
# (4-5) into separate 1/7 weight blocks (OBJECTIVE.f90:160-161, 1319-1325).
_IR_GROUP = 6           # NLAG + 1
_IR_SHORT_LAGS = (1, 2, 3)
_IR_LONG_LAGS = (4, 5)


def project_to_bounds(x, bounds):
    return np.minimum(np.maximum(x, bounds[:, 0]), bounds[:, 1])


def make_diagonal_weights(n_mom, groups):
    """Build diagonal weight vector from group definitions."""
    w = np.zeros(n_mom, dtype=float)
    for name, (idxs, gw) in groups.items():
        idxs = np.asarray(idxs, dtype=int)
        if idxs.size == 0:
            continue
        w[idxs] = float(gw) / idxs.size
    return w


def compute_psi(m, moment_sets, floor=1e-12):
    """psi_n = 10th percentile of |m_n| within each moment set (scale floor)."""
    m = np.asarray(m, float)
    psi = np.zeros_like(m)
    abs_m = np.abs(m)
    for _, idxs in moment_sets.items():
        idxs = np.asarray(idxs, dtype=int)
        if idxs.size == 0:
            continue
        p10 = np.percentile(abs_m[idxs], 10)
        psi[idxs] = max(float(p10), floor)
    psi[psi == 0] = floor
    return psi


def deviation_F(d, m, psi):
    """F_n(theta) = (d_n - m_n) / (0.5(|d_n| + |m_n|) + psi_n). Where the
    denominator would be exactly zero (a zero scale floor on a moment that is
    zero in both data and simulation) it is floored to avoid 0/0; everywhere
    else this is Guvenen's formula verbatim."""
    denom = 0.5 * (np.abs(d) + np.abs(m)) + psi
    denom = np.where(denom > 0.0, denom, 1e-12)
    return (d - m) / denom


def build_weight_and_psi(m_target, slices):
    """Diagonal weights ``w`` and denominator scale floors ``psi`` that
    faithfully reproduce Guvenen et al.'s objective (OBJECTIVE.f90).

    psi is a fixed per-block constant (``GUV_SCALE``). The weights give each
    moment block a fixed share of the objective -- each block 1/7, the Sd/Skew/
    Kurt block (L1+L5 together) 2/7, and the impulse responses split into
    short-lag and long-lag 1/7 blocks -- divided within a block by its moment
    count, so a block contributes its share times the *mean* squared deviation
    over its moments (the seven shares sum to 1). Non-targeted entries get
    weight 0: the impulse change columns (the interpolation x) and the final
    EmpCDF point (a forced 100). Returns (w, psi, None, None); the trailing
    Nones preserve the old 4-tuple signature for callers.
    """
    n_mom = len(m_target)
    w = np.zeros(n_mom, float)
    psi = np.zeros(n_mom, float)
    seventh = 1.0 / 7.0

    # Denominator scale floors, per block.
    for name, (s, e) in slices.items():
        psi[s:e] = GUV_SCALE.get(name, 0.0)

    # Sd/Skew/Kurt (L1 + L5 together): a single 2/7 share over all of them.
    ssk = [np.arange(*slices[n]) for n in ("SdSkewKurt_L1", "SdSkewKurt_L5")
           if n in slices]
    if ssk:
        ssk = np.concatenate(ssk)
        w[ssk] = (2.0 * seventh) / ssk.size

    # Impulse responses: short lags 1/7, long lags 1/7; change columns -> 0.
    if "irmoments" in slices:
        s, e = slices["irmoments"]
        lag = np.arange(e - s) % _IR_GROUP   # 0 = change, 1..NLAG = responses
        short = s + np.nonzero(np.isin(lag, _IR_SHORT_LAGS))[0]
        long_ = s + np.nonzero(np.isin(lag, _IR_LONG_LAGS))[0]
        if short.size:
            w[short] = seventh / short.size
        if long_.size:
            w[long_] = seventh / long_.size

    # Income-growth, var(log y), EmpCDF: 1/7 each.
    for name in ("incgrwth", "var_lny", "EmpCDF"):
        if name not in slices:
            continue
        idx = np.arange(*slices[name])
        if name == "EmpCDF":
            idx = idx[:-1]                    # drop the forced-100 final point
        if idx.size:
            w[idx] = seventh / idx.size

    return w, psi, None, None


def interp_impulse_targets(d_irm, ir_data):
    """Interpolate the data impulse-response curve to each bin's SIMULATED
    change, reproducing OBJECTIVE.f90's ``impulse`` subroutine: piecewise-linear
    in the data change grid, with endpoint *extrapolation* (the Fortran
    ``LOCATE`` result is clamped to an interior segment, so a simulated change
    outside the data grid is linearly extended from the nearest segment).

    d_irm:   simulated irmoments, (n_i, n_j, n_k, NLAG+1); ``[...,0]`` is the
             simulated mean change in each bin, ``[...,1:]`` the simulated
             responses.
    ir_data: data grid, (n_i, n_j, n_data, NLAG+1); ``[...,0]`` the ascending
             data change points, ``[...,1:]`` the data responses.
    Returns: targ, (n_i, n_j, n_k, NLAG) -- the data response interpolated to
             each simulated change.
    """
    n_i, n_j, n_k, ncol = d_irm.shape
    n_data = ir_data.shape[2]
    targ = np.empty((n_i, n_j, n_k, ncol - 1))
    for i in range(n_i):
        for j in range(n_j):
            xg = ir_data[i, j, :, 0]
            yg = ir_data[i, j, :, 1:]                 # (n_data, NLAG)
            x = d_irm[i, j, :, 0]                      # (n_k,)
            # left bracket index, clamped to an interior segment (Fortran LOCATE
            # clamp) so out-of-grid changes extrapolate rather than saturate.
            lo = np.clip(np.searchsorted(xg, x, side="right") - 1, 0, n_data - 2)
            x0, x1 = xg[lo], xg[lo + 1]
            sx = (x - x0) / (x1 - x0)                  # may be <0 or >1 (extrapolation)
            y0, y1 = yg[lo], yg[lo + 1]                # (n_k, NLAG) each
            targ[i, j] = y0 + (y1 - y0) * sx[:, None]
    return targ


def impulse_response_F(d_irm, ir_data, scale=None):
    """Deviation array for the impulse-response block with the data response
    interpolated to the simulated change (Guvenen's method). Shaped like
    ``d_irm`` (n_i,n_j,n_k,NLAG+1): the change column (index 0) is 0 (it is the
    interpolation abscissa, not a targeted moment); the response columns are the
    symmetric percentage error ``(targ - sim)/(0.5(|targ|+|sim|) + scale)``."""
    if scale is None:
        scale = GUV_SCALE["irmoments"]
    targ = interp_impulse_targets(d_irm, ir_data)      # (..., NLAG)
    sim = d_irm[..., 1:]
    denom = 0.5 * (np.abs(targ) + np.abs(sim)) + scale
    denom = np.where(denom > 0.0, denom, 1e-12)
    F = np.zeros_like(d_irm)
    F[..., 1:] = (targ - sim) / denom
    return F


def msm_objective(theta, m_target, w_diag, psi, cfg):
    """
    The MSM objective Q(theta) = sqrt( sum_n w_n F_n(theta)^2 ), with Common
    Random Numbers (fixed seed). Returns a large penalty on any numerical
    failure.

    NOTE: this convenience form uses the *static* impulse-response target baked
    into ``m_target``. The faithful interpolated-impulse path (Guvenen's
    ``impulse`` subroutine) lives in ``Problem.make_objective``, which is what
    the run/plot pipeline uses.
    """
    try:
        theta = project_to_bounds(theta, PARAM_BOUNDS)
        shocks = get_shocks(cfg.n_sim, cfg.hmax, cfg.seed)
        ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed, shocks=shocks)
        mom = calculate_moments(ysim)
        d, _ = flatten_moments(mom)
        if d.shape != m_target.shape:
            return 1e20
        F = deviation_F(d, m_target, psi)
        return float(np.sqrt(np.sum(w_diag * (F ** 2))))
    except Exception:
        return 1e20
