"""
msm_model.py
============
Economics core for the Guvenen et al. (2021) income-process estimation:
the data-generating process (DGP), the moment computation, and the MSM
objective.

This is a self-contained, lightly-cleaned copy of the proven building blocks in
``earning_dynamics/code/msm_optimizer.py`` (originally integrated from Alex Vu /
Jackson Howell / team code). It is kept dependency-free of the optimizer so the
same functions back both the sequential reference implementation and the
file-coordinated parallel engine in ``tiktak.py``.

The 21-parameter income process and the ~670 targeted moments are a faithful
translation of ``guvenen_2021_replication/.../Estimation/OBJECTIVE.f90``
(``SIMULATE`` and ``MOMENTS``).
"""

import os
from collections import namedtuple
from dataclasses import dataclass

import numpy as np

# Optional numba JIT for the moment kernels. Falls back to a no-op decorator
# (pure-Python loops) if numba is unavailable, so the module always imports.
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

# ============================================================================
# SECTION 0: CONFIGURATION
# ============================================================================


@dataclass
class MSMConfig:
    """All tuning knobs for the estimation."""

    n_sim: int = 50_000          # Number of simulated individuals
    hmax: int = 36               # Ages 25-60
    seed: int = 42               # CRN seed for simulation

    # Stage A: Sobol screening
    sobol_draws: int = 250_000   # Appendix D uses 250K
    sobol_seed: int = 999        # Sobol scramble seed (shared across workers)
    keep_best: int = 1_000       # Keep top-K legitimate points for local stage

    # Stage B: local optimization
    local_methods: tuple = ("Powell", "Nelder-Mead")
    maxiter_local: int = 1_000

    # TikTak blending (theta_k ramps from theta_min -> theta_max)
    theta_min: float = 0.1
    theta_max: float = 0.995

    # Filtering / penalties
    max_legit_obj_val: float = 1e8
    penalty_weight: float = 1e6


# ============================================================================
# SECTION 1: PARAMETER NAMES, BOUNDS, AND TRUE VALUES
# ============================================================================

# The 21 parameters to estimate, in order:
PARAM_NAMES = [
    'a0',           # life-cycle intercept
    'a1',           # life-cycle linear
    'a2',           # life-cycle quadratic
    'sigma_alpha',  # HIP: std of alpha
    'sigma_beta',   # HIP: std of beta
    'corr_ab',      # HIP: correlation(alpha, beta)
    'rho1',         # AR(1) persistence
    'sd_z0',        # AR(1) initial std
    'pdf_ar',       # AR(1) mixture weight (prob of component 1)
    'mu_eta1',      # AR(1) innovation: mean of component 1
    'sd_eta1',      # AR(1) innovation: std of component 1
    'sd_eta2',      # AR(1) innovation: std of component 2
    'pr_eps',       # Transitory: mixture weight
    'mu_eps1',      # Transitory: mean of component 1
    'sd_eps1',      # Transitory: std of component 1
    'sd_eps2',      # Transitory: std of component 2
    'nu_const',     # Nonemployment: constant
    'nu_age',       # Nonemployment: age coefficient
    'nu_z',         # Nonemployment: z coefficient
    'nu_inter',     # Nonemployment: interaction (z * age)
    'nu_lam',       # Nonemployment: exponential rate
]

# True parameter values (Guvenen 2021 replication estimates;
# matches param_diagnostic.dat / data_generating_sim.ipynb).
THETA_TRUE = np.array([
    2.580861694,    # a0
    0.811530031,    # a1
    -0.185093302,   # a2
    0.299819619,    # sigma_alpha
    0.196328895,    # sigma_beta
    0.767749193,    # corr_ab
    0.959229453,    # rho1
    0.713648178,    # sd_z0
    0.406559194,    # pdf_ar
    -0.085236482,   # mu_eta1
    0.363928061,    # sd_eta1
    0.06891405,     # sd_eta2
    0.129904327,    # pr_eps
    0.271112226,    # mu_eps1
    0.284541004,    # sd_eps1
    0.036545913,    # sd_eps2
    -3.352949544,   # nu_const
    -0.859498283,   # nu_age
    -5.034075647,   # nu_z
    -2.895204912,   # nu_inter
    0.000265509,    # nu_lam
])

# Bounds: (lower, upper) for each parameter.
PARAM_BOUNDS = np.array([
    [0.0,    5.0],     # a0
    [-2.0,   3.0],     # a1
    [-1.0,   1.0],     # a2
    [0.01,   1.0],     # sigma_alpha  (>0)
    [0.01,   1.0],     # sigma_beta   (>0)
    [-0.99,  0.99],    # corr_ab
    [0.5,    0.999],   # rho1
    [0.05,   2.0],     # sd_z0        (>0)
    [0.01,   0.99],    # pdf_ar       (probability)
    [-1.0,   1.0],     # mu_eta1
    [0.01,   1.0],     # sd_eta1      (>0)
    [0.001,  0.5],     # sd_eta2      (>0)
    [0.01,   0.5],     # pr_eps       (probability)
    [-1.0,   1.0],     # mu_eps1
    [0.01,   1.0],     # sd_eps1      (>0)
    [0.001,  0.3],     # sd_eps2      (>0)
    [-10.0,  0.0],     # nu_const
    [-5.0,   5.0],     # nu_age
    [-15.0,  0.0],     # nu_z
    [-10.0,  5.0],     # nu_inter
    [1e-6,   0.01],    # nu_lam       (>0)
])


# ============================================================================
# SECTION 2: DATA GENERATING PROCESS  (Fortran: SIMULATE / SIM_RN)
# ============================================================================

# Frozen Common-Random-Number shocks. Drawn once and reused across every
# objective evaluation (this is how the Guvenen Fortran does it via SIM_RN):
# only theta changes between evaluations, the shocks are constant.
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
        theta:  length-21 parameter vector (see PARAM_NAMES)
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


# ============================================================================
# SECTION 3: TOOLBOX — Moment computation  (Fortran: MOMENTS)
# ============================================================================

NVASEINC = 13
NVASEMNT = 3
NIRINC = 8
NIRCHG = 10
NLAG = 5
NLTINCPCT = 15
LTH = 8
MINOBS = 3
MINEMP = 15
RMINWAGE = 1.5
DPMISSING = 1.0e15
_MISS = DPMISSING - 1.0   # values >= this are treated as missing

VASEINCPCT = np.array([1, 2, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 100, 101])
IRAVGINCPCT = np.array([1, 6, 11, 31, 51, 71, 91, 96, 101])
IRCHGPCT = np.array([1, 3, 6, 11, 31, 51, 71, 91, 96, 99, 101])
LTINCPCT = np.array([1, 2, 6, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 98, 100, 101])
NAGEBIN = np.array([2, 2, 2])
AGEBINL = np.array([1, 9, 19]) - 1
DF1 = np.array([2, 6, 1, 2, 3, 4, 6, 11]) - 1
DF2 = np.array([1, 1, 0, 0, 0, 0, 0, 0]) - 1
_DF1_I64 = DF1.astype(np.int64)
_DF2_I64 = DF2.astype(np.int64)


@njit(cache=True)
def _mean_miss(x):
    """Mean of non-missing entries (single pass; replaces scipy/numpy masks)."""
    n = 0
    s = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            n += 1
            s += v
    if n == 0:
        return 0.0
    return s / n


@njit(cache=True)
def _sdskewkurt_miss(x):
    """Sample sd (ddof=1) plus bias-corrected skewness and (excess) kurtosis of
    the non-missing entries. Reproduces scipy.stats.skew/kurtosis(bias=False)
    exactly: bias-corrected for n>=3 (skew) / n>=4 (kurt), biased estimator
    below that (matching scipy's small-n branch), all in two passes and with no
    scipy wrapper overhead."""
    n = 0
    s = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            n += 1
            s += v
    if n < 2:
        return 0.0, 0.0, 0.0
    mean = s / n
    m2 = 0.0
    m3 = 0.0
    m4 = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            d = v - mean
            d2 = d * d
            m2 += d2
            m3 += d2 * d
            m4 += d2 * d2
    m2 /= n
    m3 /= n
    m4 /= n
    sd = (m2 * n / (n - 1)) ** 0.5      # sample std, ddof=1
    if m2 <= 0.0:
        return sd, 0.0, 0.0
    if n >= 3:
        skew = (m3 / m2 ** 1.5) * (n * (n - 1)) ** 0.5 / (n - 2)
    else:
        skew = m3 / m2 ** 1.5            # biased (n == 2)
    if n >= 4:
        g2 = m4 / (m2 * m2) - 3.0
        kurt = ((n + 1) * g2 + 6.0) * (n - 1) / ((n - 2) * (n - 3))
    else:
        kurt = m4 / (m2 * m2) - 3.0      # biased (n in {2, 3})
    return sd, skew, kurt


def _sortrows_col1(a, pct=None):
    """Return ``(rows, n_nonmissing)`` where ``rows`` is the non-missing rows
    (col 0 < DPMISSING) gathered in ascending col-0 rank order. Missing rows
    are dropped, not appended: every call site only ever reads rows
    ``[0:n_nonmissing)``, so the old vstack of missing rows was pure overhead.
    Rows are gathered in a single pass via ``a[valid_idx[order]]`` (one copy,
    not two).

    The per-bin moments computed downstream are order-independent, so we don't
    need a full sort -- only the rows partitioned at the percentile *rank*
    cut-points. If ``pct`` (the percentile breakpoint array this block is binned
    by, e.g. VASEINCPCT) is given, we use ``np.argpartition`` at those cut
    indices (~O(N)) instead of a full ``np.argsort`` (O(N log N)). Bin
    membership is identical to the full-sort version for continuous keys (ties
    are measure-zero in the simulated data); the order of the valid rows fed to
    the sort is unchanged, so tie-breaking is bit-identical to before."""
    valid_idx = np.nonzero(a[:, 0] < _MISS)[0]
    nonmiss = valid_idx.size
    col0 = a[valid_idx, 0]

    if pct is not None and nonmiss > 2:
        # rank cut indices used downstream: floor(nonmiss*(pct-1)/100)
        kths = np.floor(nonmiss * (np.asarray(pct) - 1) / 100).astype(np.intp)
        kths = np.unique(kths[(kths > 0) & (kths < nonmiss)])
        order = (np.argpartition(col0, kths) if kths.size
                 else np.argsort(col0))
    else:
        order = np.argsort(col0)

    return a[valid_idx[order]], nonmiss


@njit(cache=True)
def _build_longdata_ab(ysim_in, df1, df2):
    """Sections A + B of MOMENTS, as one numba kernel: the variance of log
    income by age, and the `longdata` panel of average past income +
    arc-percent income changes (the impulse columns demeaned). Returns
    (var_lny, longdata). Bit-identical to the original numpy version."""
    nsim, hmax = ysim_in.shape
    varlny = np.zeros(hmax)
    agedum = np.zeros(hmax)

    # A. mean of log income (the age dummy) and variance of log income
    for h in range(hmax):
        n = 0
        sm = 0.0
        for i in range(nsim):
            v = ysim_in[i, h]
            if v >= RMINWAGE:
                n += 1
                sm += np.log(v)
        if n < 2:
            agedum[h] = 0.0
            varlny[h] = 0.0
        else:
            mean = sm / n
            ss = 0.0
            for i in range(nsim):
                v = ysim_in[i, h]
                if v >= RMINWAGE:
                    d = np.log(v) - mean
                    ss += d * d
            agedum[h] = mean
            varlny[h] = ss / (n - 1)
    for h in range(hmax):
        agedum[h] = np.exp(agedum[h])

    # 5-year trailing average of the age dummy
    avgagedum = np.zeros(hmax)
    for h in range(hmax):
        lo = h - 4 if h - 4 > 0 else 0
        sm = 0.0
        cnt = 0
        for hh in range(lo, h + 1):
            sm += agedum[hh]
            cnt += 1
        avgagedum[h] = sm / cnt

    # B. longdata
    NLONG = 28 if (hmax - 2) > 28 else (hmax - 2)
    longdata = np.full((nsim * NLONG, 9), DPMISSING)
    hmax_b = 30 if hmax > 30 else hmax

    for h in range(2, hmax_b):
        lb = (h - 2) * nsim
        kk = h + 1 if (h + 1) < 5 else 5      # min(h+1, 5)

        # col 0: average past income (over the last kk years), normalized
        for i in range(nsim):
            numobs = -5 if ysim_in[i, h] < RMINWAGE else 0
            api = 0.0
            for j in range(kk):
                vv = ysim_in[i, h - j]
                api += vv if vv > RMINWAGE else RMINWAGE
                if vv >= RMINWAGE:
                    numobs += 1
            if numobs >= MINOBS:
                longdata[lb + i, 0] = api / (kk * avgagedum[h])
            # else: stays DPMISSING

        # cols 1..8: arc-percent income changes at the 8 (base, future) pairs
        for j in range(8):
            h_fut = h + df1[j] + 1
            h_base = h + df2[j] + 1
            if h_fut < hmax:
                ad_b = agedum[h_base]
                ad_f = agedum[h_fut]
                for i in range(nsim):
                    yb_raw = ysim_in[i, h_base]
                    yf_raw = ysim_in[i, h_fut]
                    if yb_raw >= RMINWAGE or yf_raw >= RMINWAGE:
                        yb = yb_raw / ad_b
                        yf = yf_raw / ad_f
                        longdata[lb + i, 1 + j] = 2.0 * (yf - yb) / (yf + yb)
                    # else: stays DPMISSING

        # demean the impulse columns (3..3+NLAG) that were actually filled
        for l in range(NLAG + 1):
            if h + df1[2 + l] + 1 < hmax:
                col = 3 + l
                s = 0.0
                n = 0
                for i in range(nsim):
                    v = longdata[lb + i, col]
                    if v < _MISS:
                        s += v
                        n += 1
                if n > 0:
                    m = s / n
                    for i in range(nsim):
                        if longdata[lb + i, col] < _MISS:
                            longdata[lb + i, col] -= m

    return varlny, longdata


def calculate_moments(ysim_in):
    """
    Compute all moments from a simulated income panel.
    Faithful translation of MOMENTS in OBJECTIVE.f90.

    HOT PATH: runs on every objective evaluation.

    Returns:
        dict with keys: SdSkewKurt_L1, SdSkewKurt_L5, irmoments,
                        incgrwth, var_lny, EmpCDF
    """
    nsim, hmax = ysim_in.shape
    EMPCDF_NUM = hmax + 1

    SSK_L1 = np.zeros((3, NVASEINC, NVASEMNT))
    SSK_L5 = np.zeros((3, NVASEINC, NVASEMNT))
    irm = np.zeros((2, NIRINC, NIRCHG, NLAG + 1))
    incg = np.zeros((NLTINCPCT, LTH))
    ecdf = np.zeros(EMPCDF_NUM)

    # A + B. Variance of log income and the longdata panel (numba kernel).
    varlny, longdata = _build_longdata_ab(ysim_in, _DF1_I64, _DF2_I64)

    # C. Cross-sectional moments
    for i in range(3):
        for nh in range(NAGEBIN[i]):
            if i == 0:
                if nh == 0:
                    lb, ub = 0, 3 * nsim
                else:
                    lb, ub = 3 * nsim, 8 * nsim
            else:
                hstart = AGEBINL[i] + 5 * nh
                lb = hstart * nsim
                ub = lb + 5 * nsim

            if ub > len(longdata):
                continue

            temp = longdata[lb:ub, 0:3].copy()
            temp, nonmiss = _sortrows_col1(temp, VASEINCPCT)

            for j in range(NVASEINC):
                lb2 = int(np.floor(nonmiss * (VASEINCPCT[j] - 1) / 100))
                ub2 = min(int(np.floor(nonmiss * (VASEINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
                if ub2 > lb2:
                    ssk = _sdskewkurt_miss(temp[lb2:ub2 + 1, 1])
                    ssk5 = _sdskewkurt_miss(temp[lb2:ub2 + 1, 2])
                    SSK_L1[i, j, :] += np.array(ssk) / NAGEBIN[i]
                    SSK_L5[i, j, :] += np.array(ssk5) / NAGEBIN[i]

    # D. Impulse response moments
    for i in range(2):
        if i == 0:
            lb, ub = 0, 8 * nsim
        else:
            lb = 8 * nsim
            ub = min(23 * nsim, len(longdata))
        if ub <= lb:
            continue

        # Section D feeds its rows into the inner shock sort (which has tied
        # zeros), so the outer order must be a full sort too -- otherwise the
        # inner tie-breaking changes. argpartition is reserved for the
        # single-level continuous-key sorts (sections C and E).
        temp = np.column_stack([longdata[lb:ub, 0], longdata[lb:ub, 3:9]])
        temp, nonmiss = _sortrows_col1(temp)

        for j in range(NIRINC):
            lb2 = int(np.floor(nonmiss * (IRAVGINCPCT[j] - 1) / 100))
            ub2 = min(int(np.floor(nonmiss * (IRAVGINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
            if ub2 <= lb2:
                continue

            # NB: the shock key (temp2 col 0) has a point-mass at zero (no
            # income change), so its ties must be resolved by a full sort to
            # match the reference -- argpartition would split the zero-mass
            # arbitrarily across the shock bins. Hence no `pct` here.
            temp2 = temp[lb2:ub2 + 1, 1:7].copy()
            temp2, nonmiss2 = _sortrows_col1(temp2)

            for k in range(NIRCHG):
                lb3 = int(np.floor(nonmiss2 * (IRCHGPCT[k] - 1) / 100))
                ub3 = min(int(np.floor(nonmiss2 * (IRCHGPCT[k + 1] - 1) / 100)), nonmiss2 - 1)
                if ub3 > lb3:
                    for l in range(NLAG + 1):
                        irm[i, j, k, l] = _mean_miss(temp2[lb3:ub3 + 1, l])

    # E. Lifetime income growth + employment CDF
    emp = np.zeros(nsim, dtype=int)
    LTinc = np.zeros((nsim, LTH + 1))
    jj = 0

    for h in range(hmax):
        LTinc[:, 0] += np.maximum(ysim_in[:, h], RMINWAGE)
        emp[ysim_in[:, h] >= RMINWAGE] += 1
        if (h % 5 == 0) and (jj < LTH):
            LTinc[:, 1 + jj] = np.maximum(ysim_in[:, h], RMINWAGE)
            jj += 1

    LTinc[:, 0] = LTinc[:, 0] / hmax
    LTinc[emp < MINEMP, 0] = DPMISSING

    for i in range(EMPCDF_NUM - 1):
        ecdf[i] = 100.0 * np.sum(emp <= i) / nsim
    ecdf[-1] = 100.0

    temp_lt = LTinc.copy()
    temp_lt, nonmiss = _sortrows_col1(temp_lt, LTINCPCT)

    for j in range(NLTINCPCT):
        lb = int(np.floor(nonmiss * (LTINCPCT[j] - 1) / 100))
        ub = min(int(np.floor(nonmiss * (LTINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
        for h in range(LTH):
            if ub > lb:
                incg[j, h] = _mean_miss(temp_lt[lb:ub + 1, h + 1])

    return {
        'SdSkewKurt_L1': SSK_L1,
        'SdSkewKurt_L5': SSK_L5,
        'irmoments': irm,
        'incgrwth': incg,
        'var_lny': varlny,
        'EmpCDF': ecdf,
    }


# ============================================================================
# SECTION 4: FLATTEN MOMENTS
# ============================================================================

def flatten_moments(mom_dict):
    """
    Flatten all moment arrays into a single 1-D vector.
    Order: SSK_L1, SSK_L5, irmoments, incgrwth, var_lny, EmpCDF

    Returns:
        vec: 1-D array
        slices: dict mapping moment name -> (start_idx, end_idx)
    """
    arrays = [
        ('SdSkewKurt_L1', mom_dict['SdSkewKurt_L1'].ravel()),
        ('SdSkewKurt_L5', mom_dict['SdSkewKurt_L5'].ravel()),
        ('irmoments', mom_dict['irmoments'].ravel()),
        ('incgrwth', mom_dict['incgrwth'].ravel()),
        ('var_lny', mom_dict['var_lny'].ravel()),
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


# ============================================================================
# SECTION 5: LOAD TARGET MOMENTS (optional real-data path)
# ============================================================================

def load_ssk_dat(path):
    """Load SdSkewKurt .dat -> (3, 13, 3) array."""
    raw = np.loadtxt(path)  # (39, 3)
    arr = np.zeros((3, 13, 3))
    for i in range(3):
        arr[i] = raw[i * 13:(i + 1) * 13, :]
    return arr


def load_ir_dat(path):
    """
    Load ImpulseA_mean.dat -> (2, 8, 10, 6) array.
    Fortran layout: (2*8*23) rows x 6 cols. Keep the 10 shock bins that match
    the simulation grid.
    """
    raw = np.loadtxt(path)  # (368, 6)
    full = raw.reshape(2, 8, 23, 6)
    shock_map = [0, 1, 2, 4, 8, 14, 18, 20, 21, 22]
    return full[:, :, shock_map, :]


def load_target_moments(data_path):
    """
    Load all target .dat files from ``<data_path>/intermediate`` and flatten.

    Returns:
        m: 1-D target moment vector
        slices: dict with index ranges for each moment group
    """
    intermediate = os.path.join(data_path, 'intermediate')

    ssk_l1 = load_ssk_dat(os.path.join(intermediate, 'SdSkewKurt_L1.dat'))
    ssk_l5 = load_ssk_dat(os.path.join(intermediate, 'SdSkewKurt_L5.dat'))
    ir_dat = load_ir_dat(os.path.join(intermediate, 'ImpulseA_mean.dat'))
    incg = np.loadtxt(os.path.join(intermediate, 'meanLTinc_level.dat'))   # (15, 8)
    varlny = np.loadtxt(os.path.join(intermediate, 'var_lny.dat'))         # (36,)
    ecdf = np.loadtxt(os.path.join(intermediate, 'EmpCDF.dat'))            # (37,)

    mom_dict = {
        'SdSkewKurt_L1': ssk_l1,
        'SdSkewKurt_L5': ssk_l5,
        'irmoments': ir_dat,
        'incgrwth': incg,
        'var_lny': varlny,
        'EmpCDF': ecdf,
    }
    return flatten_moments(mom_dict)


def synthetic_target_moments(cfg, theta=None):
    """Generate a target moment vector by simulating at ``theta`` (default
    THETA_TRUE). Used for the performance/recovery test where ground truth is
    known."""
    if theta is None:
        theta = THETA_TRUE
    shocks = get_shocks(cfg.n_sim, cfg.hmax, cfg.seed)
    ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed, shocks=shocks)
    mom = calculate_moments(ysim)
    return flatten_moments(mom)


# ============================================================================
# SECTION 6: MSM OBJECTIVE  (Fortran: dfovec / OBJ_FUNC)
# ============================================================================

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
