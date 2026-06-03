"""
dgp.py
======
The income-process data-generating process (Fortran ``SIMULATE`` / ``SIM_RN``):
draw the Common-Random-Number shocks once, then simulate the income panel for a
given parameter vector. The shocks are frozen and reused across every objective
evaluation (only theta changes), exactly as the Guvenen Fortran does via
``SIM_RN``.
"""

from collections import namedtuple

import numpy as np

# Frozen Common-Random-Number shocks.
Shocks = namedtuple(
    "Shocks",
    "rn_hip1 rn_hip2 rn_z0 rn_p_ar rn_eta rn_unemp rn_nu rn_p_eps rn_eps")


def draw_shocks(n_sim, hmax, seed):
    """Draw all simulation shocks once, in the exact order the in-loop draws
    used to occur, so reusing them is bit-identical to re-seeding each call."""
    rng = np.random.default_rng(seed)
    rn_hip1 = rng.standard_normal(n_sim)
    rn_hip2 = rng.standard_normal(n_sim)
    rn_z0 = rng.standard_normal(n_sim)
    rn_p_ar = np.empty((hmax, n_sim))
    rn_eta = np.empty((hmax, n_sim))
    rn_unemp = np.empty((hmax, n_sim))
    rn_nu = np.empty((hmax, n_sim))
    rn_p_eps = np.empty((hmax, n_sim))
    rn_eps = np.empty((hmax, n_sim))
    for h in range(hmax):
        rn_p_ar[h] = rng.uniform(size=n_sim)
        rn_eta[h] = rng.standard_normal(n_sim)
        rn_unemp[h] = rng.uniform(size=n_sim)
        rn_nu[h] = rng.uniform(size=n_sim)
        rn_p_eps[h] = rng.uniform(size=n_sim)
        rn_eps[h] = rng.standard_normal(n_sim)
    return Shocks(rn_hip1, rn_hip2, rn_z0,
                  rn_p_ar, rn_eta, rn_unemp, rn_nu, rn_p_eps, rn_eps)


_SHOCK_CACHE = {}


def get_shocks(n_sim, hmax, seed):
    """Process-local cache of frozen shocks keyed by (n_sim, hmax, seed)."""
    key = (n_sim, hmax, seed)
    s = _SHOCK_CACHE.get(key)
    if s is None:
        s = draw_shocks(n_sim, hmax, seed)
        _SHOCK_CACHE[key] = s
    return s


def simulate_income(theta, n_sim, hmax, seed, shocks=None):
    """
    Simulate an income panel given parameters ``theta``.

    HOT PATH: this runs on every objective evaluation, so it is fully
    vectorized over the ``n_sim`` individuals (the only Python-level loop is
    over the ``hmax`` age periods).

    Args:
        theta:  length-21 parameter vector (see params.PARAM_NAMES)
        n_sim:  number of individuals
        hmax:   number of age periods (36 = ages 25..60)
        seed:   RNG seed (for Common Random Numbers)
        shocks: optional pre-drawn ``Shocks`` (from ``draw_shocks``/``get_shocks``);
                if None, shocks are drawn from ``seed``. Passing frozen shocks
                avoids re-drawing on every call and is bit-identical.

    Returns:
        ysim: (n_sim, hmax) array of income levels
    """
    (a0, a1, a2,
     sigma_alpha, sigma_beta, corr_ab,
     rho1, sd_z0,
     pdf_ar, mu_eta1, sd_eta1, sd_eta2,
     pr_eps, mu_eps1, sd_eps1, sd_eps2,
     nu_const, nu_age, nu_z, nu_inter, nu_lam) = theta

    # Derived quantities (mixture means chosen so each shock is mean-zero)
    mu_eta2 = -mu_eta1 * pdf_ar / (1.0 - pdf_ar)
    mu_eps2 = -mu_eps1 * pr_eps / (1.0 - pr_eps)

    # Cholesky of HIP covariance
    cov_ab = corr_ab * sigma_alpha * sigma_beta
    L11 = sigma_alpha
    L21 = cov_ab / sigma_alpha if sigma_alpha > 0 else 0.0
    L22 = np.sqrt(max(sigma_beta ** 2 - L21 ** 2, 1e-15))

    if shocks is None:
        shocks = draw_shocks(n_sim, hmax, seed)

    # HIP draws
    alpha = L11 * shocks.rn_hip1
    beta = L21 * shocks.rn_hip1 + L22 * shocks.rn_hip2

    # Initialize AR(1)
    ar_z1 = sd_z0 * shocks.rn_z0

    ysim = np.zeros((n_sim, hmax))

    for h in range(1, hmax + 1):
        age_s = h / 10.0

        rn_p_ar = shocks.rn_p_ar[h - 1]
        rn_eta = shocks.rn_eta[h - 1]
        rn_unemp = shocks.rn_unemp[h - 1]
        rn_nu = shocks.rn_nu[h - 1]
        rn_p_eps = shocks.rn_p_eps[h - 1]
        rn_eps = shocks.rn_eps[h - 1]

        # Advance AR(1) (state-dependent mixture innovation)
        mask_ar = rn_p_ar <= pdf_ar
        ar_z1 = np.where(
            mask_ar,
            rho1 * ar_z1 + mu_eta1 + sd_eta1 * rn_eta,
            rho1 * ar_z1 + mu_eta2 + sd_eta2 * rn_eta,
        )

        # Nonemployment (logit probability, exponential duration)
        xi = nu_const + nu_age * age_s + nu_z * ar_z1 + nu_inter * age_s * ar_z1
        xi = np.clip(xi, -500, 500)
        pnu = 1.0 / (1.0 + np.exp(-xi))
        nu = np.where(
            rn_unemp <= pnu,
            np.minimum(-np.log(np.maximum(rn_nu, 1e-15)) / max(nu_lam, 1e-15), 1.0),
            0.0,
        )

        # Transitory shock (mixture)
        eps = np.where(
            rn_p_eps <= pr_eps,
            mu_eps1 + sd_eps1 * rn_eps,
            mu_eps2 + sd_eps2 * rn_eps,
        )

        log_y = (a0 + a1 * age_s + a2 * age_s ** 2
                 + alpha + beta * age_s
                 + ar_z1 + eps)
        ysim[:, h - 1] = np.maximum(0.0, (1.0 - nu) * np.exp(log_y))

    return ysim
