"""
problem_2param.py
=================
Defines the reduced 2-parameter estimation problem used to optimize and
benchmark the file-coordinated TikTak engine.

Free parameters:  a1 (life-cycle slope) and rho1 (AR(1) persistence).
The other 19 parameters are fixed at their Guvenen-2021 values (THETA_TRUE).

a1 and rho1 are identified by largely separate moment groups (the life-cycle
income profile vs. the impulse responses / autocovariance), so the 2-D
objective surface is well behaved -- a clean test bed for the optimizer.

By default the targets are SYNTHETIC: moments simulated at THETA_TRUE. That
gives a known ground truth, so a correct optimizer must recover
    a1   -> 0.811530
    rho1 -> 0.959229
with an objective value near zero. Pass real targets instead via
``make_objective(cfg, real_data_path=...)``.
"""

import numpy as np

from msm_model import (
    PARAM_NAMES, PARAM_BOUNDS, THETA_TRUE,
    simulate_income, calculate_moments, flatten_moments,
    build_weight_and_psi, deviation_F, synthetic_target_moments,
    load_target_moments, get_shocks,
)

# ── Free-parameter selection ────────────────────────────────────────────
FREE_NAMES = ["a1", "rho1"]
FREE_IDXS = [PARAM_NAMES.index(n) for n in FREE_NAMES]
N_FREE = len(FREE_IDXS)
FREE_BOUNDS = np.array([PARAM_BOUNDS[i] for i in FREE_IDXS])  # (2, 2)
FREE_TRUE = np.array([THETA_TRUE[i] for i in FREE_IDXS])


def build_full_theta(x2):
    """Map a length-2 vector (a1, rho1) into the full 21-vector, clipping the
    free entries to their bounds and holding the other 19 at THETA_TRUE."""
    theta = THETA_TRUE.copy()
    for j, idx in enumerate(FREE_IDXS):
        theta[idx] = float(np.clip(x2[j], FREE_BOUNDS[j, 0], FREE_BOUNDS[j, 1]))
    return theta


def build_target(cfg, real_data_path=None):
    """Return (m_target, slices, w_diag, psi). Synthetic unless a real data
    path is given."""
    if real_data_path is not None:
        m_target, slices = load_target_moments(real_data_path)
    else:
        m_target, slices = synthetic_target_moments(cfg)
    w_diag, psi, _, _ = build_weight_and_psi(m_target, slices)
    return m_target, slices, w_diag, psi


def make_objective(cfg, real_data_path=None):
    """
    Build the scalar objective ``f(x2) -> float`` over the 2 free parameters.

    The returned closure is picklable-friendly only if cfg / targets are
    captured as module-level state; for the file-coordinated engine each worker
    process builds its own objective (cheap: one simulation for the synthetic
    target), so no cross-process pickling of the closure is needed.
    """
    m_target, slices, w_diag, psi = build_target(cfg, real_data_path)
    shocks = get_shocks(cfg.n_sim, cfg.hmax, cfg.seed)  # drawn once, reused

    def objective(x2):
        try:
            theta = build_full_theta(x2)
            ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed, shocks=shocks)
            mom = calculate_moments(ysim)
            d, _ = flatten_moments(mom)
            if d.shape != m_target.shape:
                return 1e20
            F = deviation_F(d, m_target, psi)
            return float(np.sum(w_diag * (F ** 2)))
        except Exception:
            return 1e20

    objective.m_target = m_target
    objective.slices = slices
    return objective
