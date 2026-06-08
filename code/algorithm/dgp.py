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

# Optional numba JIT (mirrors moments.py): falls back to a no-op decorator so
# the module always imports even without numba.
try:
    from numba import njit
    _HAVE_NUMBA = True
except Exception:  # pragma: no cover
    _HAVE_NUMBA = False

    def njit(*args, **kwargs):
        if len(args) == 1 and callable(args[0]) and not kwargs:
            return args[0]

        def deco(f):
            return f
        return deco

# Guvenen top-codes the simulated panel before computing any moments
# (OBJECTIVE.f90 SIMULATE: ``WHERE(ysim>truncate) ysim=truncate``, with
# ``truncate = 2*10**4`` in utilities.F90). Clipping the income right tail
# shapes the skew/kurtosis of income changes and var_lny, so it must be applied
# to match the data targets.
TRUNCATE = 2.0e4

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


@njit(cache=True)
def _simulate_income_kernel(
        n_sim, hmax,
        a0, a1, a2, L11, L21, L22, rho1, sd_z0,
        pdf_ar, mu_eta1, mu_eta2, sd_eta1, sd_eta2,
        pr_eps, mu_eps1, mu_eps2, sd_eps1, sd_eps2,
        nu_const, nu_age, nu_z, nu_inter, nu_lam,
        rn_hip1, rn_hip2, rn_z0,
        rn_p_ar, rn_eta, rn_unemp, rn_nu, rn_p_eps, rn_eps):
    """Fused per-individual income simulation. Each individual is independent
    given the frozen shocks, so we sweep ages inside a single i-loop and avoid
    the ~hmax x (several) temporary n_sim-arrays the vectorized version built.
    Numerically identical to the elementwise numpy form (same arithmetic on the
    same frozen shocks)."""
    ysim = np.zeros((n_sim, hmax))
    nu_lam_s = nu_lam if nu_lam > 1e-15 else 1e-15
    for i in range(n_sim):
        alpha = L11 * rn_hip1[i]
        beta = L21 * rn_hip1[i] + L22 * rn_hip2[i]
        z = sd_z0 * rn_z0[i]
        for h in range(hmax):
            age_s = (h + 1) / 10.0
            # Advance AR(1) with the state-dependent mixture innovation.
            if rn_p_ar[h, i] <= pdf_ar:
                z = rho1 * z + mu_eta1 + sd_eta1 * rn_eta[h, i]
            else:
                z = rho1 * z + mu_eta2 + sd_eta2 * rn_eta[h, i]
            # Nonemployment (logit probability, exponential duration capped at 1).
            xi = nu_const + nu_age * age_s + nu_z * z + nu_inter * age_s * z
            if xi > 500.0:
                xi = 500.0
            elif xi < -500.0:
                xi = -500.0
            pnu = 1.0 / (1.0 + np.exp(-xi))
            if rn_unemp[h, i] <= pnu:
                rnu = rn_nu[h, i]
                if rnu < 1e-15:
                    rnu = 1e-15
                nu = -np.log(rnu) / nu_lam_s
                if nu > 1.0:
                    nu = 1.0
            else:
                nu = 0.0
            # Transitory shock (mixture).
            if rn_p_eps[h, i] <= pr_eps:
                eps = mu_eps1 + sd_eps1 * rn_eps[h, i]
            else:
                eps = mu_eps2 + sd_eps2 * rn_eps[h, i]
            log_y = (a0 + a1 * age_s + a2 * age_s ** 2
                     + alpha + beta * age_s + z + eps)
            val = (1.0 - nu) * np.exp(log_y)
            ysim[i, h] = val if val > 0.0 else 0.0
    return ysim


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

    ysim = _simulate_income_kernel(
        n_sim, hmax,
        a0, a1, a2, L11, L21, L22, rho1, sd_z0,
        pdf_ar, mu_eta1, mu_eta2, sd_eta1, sd_eta2,
        pr_eps, mu_eps1, mu_eps2, sd_eps1, sd_eps2,
        nu_const, nu_age, nu_z, nu_inter, nu_lam,
        shocks.rn_hip1, shocks.rn_hip2, shocks.rn_z0,
        shocks.rn_p_ar, shocks.rn_eta, shocks.rn_unemp,
        shocks.rn_nu, shocks.rn_p_eps, shocks.rn_eps)
    # Top-code the panel (Guvenen's SIMULATE truncation), in place.
    np.minimum(ysim, TRUNCATE, out=ysim)
    return ysim
