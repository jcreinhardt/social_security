"""
problem.py
==========
Defines an MSM estimation problem over an arbitrary subset of the 21 income-
process parameters: the chosen ("free") parameters are estimated, the rest are
held at their Guvenen-2021 values (THETA_TRUE). With all 21 free this is the
full problem; with ["a1", "rho1"] it is the 2-parameter test bed.

Targets default to SYNTHETIC (moments simulated at THETA_TRUE), so the known
ground truth for every free parameter is its Guvenen value — which is what the
result plots compare against. Pass a data dir to estimate against real moments.

A `Problem` instance exposes the same UPPER_CASE attribute names a plain module
would (FREE_NAMES, FREE_BOUNDS, ...), so callers can treat it interchangeably.
"""

import numpy as np

from msm_model import (
    PARAM_NAMES, PARAM_BOUNDS, PARAM_RANGE, THETA_TRUE,
    simulate_income, calculate_moments, flatten_moments,
    build_weight_and_psi, deviation_F, synthetic_target_moments,
    load_target_moments, load_ir_data_full, impulse_response_F, get_shocks,
)

ALL = "all"


def resolve_free(free):
    """Map a free-spec to (names, indices). ``free`` may be None/'all' (=> all
    21), a comma-separated string ('a1,rho1'), or a list of names."""
    if free is None or free == ALL:
        names = list(PARAM_NAMES)
    elif isinstance(free, str):
        names = [s.strip() for s in free.split(",") if s.strip()]
    else:
        names = list(free)
    for n in names:
        if n not in PARAM_NAMES:
            raise ValueError(f"unknown parameter {n!r}; valid: {PARAM_NAMES}")
    return names, [PARAM_NAMES.index(n) for n in names]


class Problem:
    def __init__(self, free=None):
        self.FREE_NAMES, self.FREE_IDXS = resolve_free(free)
        self.N_FREE = len(self.FREE_IDXS)
        self.FREE_BOUNDS = np.array([PARAM_BOUNDS[i] for i in self.FREE_IDXS])
        # Tighter, economically-informed SEARCH box for the Sobol screen (the
        # local search still refines within FREE_BOUNDS). Mirrors Guvenen's
        # param_range vs param_bound two-box design.
        self.FREE_RANGE = np.array([PARAM_RANGE[i] for i in self.FREE_IDXS])
        self.FREE_TRUE = np.array([THETA_TRUE[i] for i in self.FREE_IDXS])

    def build_full_theta(self, x):
        """Map a free-parameter vector into the full 21-vector, clipping the
        free entries to their bounds and holding the rest at THETA_TRUE."""
        theta = THETA_TRUE.copy()
        for j, idx in enumerate(self.FREE_IDXS):
            lo, hi = self.FREE_BOUNDS[j]
            theta[idx] = float(np.clip(x[j], lo, hi))
        return theta

    def build_target(self, cfg, real_data_path=None):
        """Returns (m_target, slices, w_diag, psi, ir_data). ``ir_data`` is the
        full 23-point impulse-response data grid for real-data targets (used to
        interpolate the impulse target to the simulated change, Guvenen-style),
        or None for synthetic targets (which are themselves on the simulation
        grid, so the impulse block uses the static target for exact recovery)."""
        if real_data_path is not None:
            m_target, slices = load_target_moments(real_data_path)
            ir_data = load_ir_data_full(real_data_path)
        else:
            m_target, slices = synthetic_target_moments(cfg)
            ir_data = None
        w_diag, psi, _, _ = build_weight_and_psi(m_target, slices)
        return m_target, slices, w_diag, psi, ir_data

    def make_objective(self, cfg, real_data_path=None):
        """Return ``f(x_free) -> float``, the MSM objective over the free
        parameters. Frozen CRN shocks and the target are built once and
        captured."""
        m_target, slices, w_diag, psi, ir_data = self.build_target(
            cfg, real_data_path)
        shocks = get_shocks(cfg.n_sim, cfg.hmax, cfg.seed)
        idxs = self.FREE_IDXS
        bounds = self.FREE_BOUNDS
        ir_slice = slices.get("irmoments")

        def objective(x):
            try:
                theta = THETA_TRUE.copy()
                for j, idx in enumerate(idxs):
                    theta[idx] = min(max(float(x[j]), bounds[j, 0]), bounds[j, 1])
                ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed,
                                       shocks=shocks)
                mom = calculate_moments(ysim)
                d, _ = flatten_moments(mom)
                if d.shape != m_target.shape:
                    return 1e20
                F = deviation_F(d, m_target, psi)
                # Impulse block: replace the static-target deviation with the
                # data response interpolated to the simulated change (Guvenen's
                # `impulse` subroutine). Real-data targets only.
                if ir_data is not None and ir_slice is not None:
                    s, e = ir_slice
                    F[s:e] = impulse_response_F(mom["irmoments"], ir_data).ravel()
                return float(np.sqrt(np.sum(w_diag * (F ** 2))))
            except Exception:
                return 1e20

        objective.m_target = m_target
        objective.slices = slices
        return objective
