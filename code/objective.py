"""
objective.py
============
The MSM objective (Fortran ``dfovec`` / ``OBJ_FUNC``): the scale-robust moment
deviation, the diagonal moment weights and psi scaling, and the scalar
``Q(theta) = F(theta)' W F(theta)``.
"""

import numpy as np

from params import PARAM_BOUNDS
from dgp import simulate_income, get_shocks
from moments import calculate_moments, flatten_moments


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
    """F_n(theta) = (d_n - m_n) / (0.5(|d_n| + |m_n|) + psi_n)."""
    denom = 0.5 * (np.abs(d) + np.abs(m)) + psi
    return (d - m) / denom


def build_weight_and_psi(m_target, slices):
    """
    Build the diagonal weight vector and the psi (scaling) vector from the
    target moments. Relative group weights:
      var_lny, EmpCDF        -> high (tightly identified)
      SdSkewKurt_*           -> medium
      irmoments, incgrwth    -> lower (noisier)
    """
    n_mom = len(m_target)
    weight_groups = {}
    moment_sets = {}

    for name, (s, e) in slices.items():
        idxs = np.arange(s, e)
        moment_sets[name] = idxs

        if name == 'var_lny':
            weight_groups[name] = (idxs, 5.0)
        elif name == 'EmpCDF':
            weight_groups[name] = (idxs, 5.0)
        elif name.startswith('SdSkewKurt'):
            weight_groups[name] = (idxs, 3.0)
        else:  # irmoments, incgrwth, ...
            weight_groups[name] = (idxs, 1.0)

    w_diag = make_diagonal_weights(n_mom, weight_groups)
    psi = compute_psi(m_target, moment_sets)
    return w_diag, psi, weight_groups, moment_sets


def msm_objective(theta, m_target, w_diag, psi, cfg):
    """
    The MSM objective Q(theta) = F(theta)' W F(theta), with Common Random
    Numbers (fixed seed). Returns a large penalty on any numerical failure.
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
        return float(np.sum(w_diag * (F ** 2)))
    except Exception:
        return 1e20
