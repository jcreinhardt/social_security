"""
msm_optimizer.py
================
Fully integrated Method of Simulated Moments (MSM) optimizer.

Combines:
  - DGP from data_generating_sim.ipynb  (parameterized by theta)
  - Toolbox from toolbox_final.ipynb    (moment computation)
  - Target loading from compare_moments.ipynb (reads .dat files)
  - TikTak optimizer from Parallelization file (Guvenen Appendix-D style)

Usage:
  1. Set fp_data to your Dropbox data folder (where .dat files live)
  2. Run:  python msm_optimizer.py
  3. Or import and call fit_msm() from your own notebook

Author: Integrated from Alex Vu / Jackson Howell / team code
"""

import numpy as np
import pandas as pd
from scipy import stats
from scipy.optimize import minimize
from scipy.stats import qmc
from dataclasses import dataclass
import os
import time

# ============================================================================
# SECTION 0: CONFIGURATION
# ============================================================================

# >>> SET THIS to your Dropbox data folder <<<
fp_data = r'C:\Users\adv23\Dropbox\John-Jackson-Steve 2023\earning_dynamics\data'

@dataclass
class MSMConfig:
    """All tuning knobs for the estimation."""
    n_sim: int = 50_000          # Number of simulated individuals
    hmax: int = 36               # Ages 25-60
    seed: int = 42               # CRN seed for simulation

    # Stage A: Sobol screening
    sobol_draws: int = 250_000   # Appendix D: 250K
    keep_best: int = 1_000       # Keep top-K for local stage

    # Stage B: local optimization
    local_methods: tuple = ("Powell", "Nelder-Mead")
    maxiter_local: int = 1_000

    # TikTak blending
    theta_min: float = 0.1
    theta_max: float = 0.995

    # Filtering
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

# True parameter values (from data_generating_sim.ipynb)
THETA_TRUE = np.array([
    2.580861694,    # a0
    0.811530031,    # a1
   -0.185093302,    # a2
    0.299819619,    # sigma_alpha
    0.196328895,    # sigma_beta
    0.767749193,    # corr_ab
    0.959229453,    # rho1
    0.713648178,    # sd_z0
    0.406559194,    # pdf_ar
   -0.085236482,    # mu_eta1
    0.363928061,    # sd_eta1
    0.06891405,     # sd_eta2
    0.129904327,    # pr_eps
    0.271112226,    # mu_eps1
    0.284541004,    # sd_eps1
    0.036545913,    # sd_eps2
   -3.352949544,    # nu_const
   -0.859498283,    # nu_age
   -5.034075647,    # nu_z
   -2.895204912,    # nu_inter
    0.000265509,    # nu_lam
])

# Bounds: (lower, upper) for each parameter
# Adjust these based on economic priors and prior estimation experience
PARAM_BOUNDS = np.array([
    [ 0.0,    5.0],    # a0
    [-2.0,    3.0],    # a1
    [-1.0,    1.0],    # a2
    [ 0.01,   1.0],    # sigma_alpha  (>0)
    [ 0.01,   1.0],    # sigma_beta   (>0)
    [-0.99,   0.99],   # corr_ab
    [ 0.5,    0.999],  # rho1
    [ 0.05,   2.0],    # sd_z0        (>0)
    [ 0.01,   0.99],   # pdf_ar       (probability)
    [-1.0,    1.0],    # mu_eta1
    [ 0.01,   1.0],    # sd_eta1      (>0)
    [ 0.001,  0.5],    # sd_eta2      (>0)
    [ 0.01,   0.5],    # pr_eps       (probability)
    [-1.0,    1.0],    # mu_eps1
    [ 0.01,   1.0],    # sd_eps1      (>0)
    [ 0.001,  0.3],    # sd_eps2      (>0)
    [-10.0,   0.0],    # nu_const
    [-5.0,    5.0],    # nu_age
    [-15.0,   0.0],    # nu_z
    [-10.0,   5.0],    # nu_inter
    [ 1e-6,   0.01],   # nu_lam       (>0)
])


# ============================================================================
# SECTION 2: DATA GENERATING PROCESS (from data_generating_sim.ipynb)
# ============================================================================

def simulate_income(theta, n_sim, hmax, seed):
    """
    Simulate income panel data given parameters theta.
    Matches the Fortran DGP exactly.

    Args:
        theta: length-21 parameter vector (see PARAM_NAMES)
        n_sim: number of individuals
        hmax:  number of age periods (36 = ages 25..60)
        seed:  RNG seed (for CRN)

    Returns:
        ysim: (n_sim, hmax) array of income levels
    """
    (a0, a1, a2,
     sigma_alpha, sigma_beta, corr_ab,
     rho1, sd_z0,
     pdf_ar, mu_eta1, sd_eta1, sd_eta2,
     pr_eps, mu_eps1, sd_eps1, sd_eps2,
     nu_const, nu_age, nu_z, nu_inter, nu_lam) = theta

    # Derived quantities
    mu_eta2 = -mu_eta1 * pdf_ar / (1.0 - pdf_ar)
    mu_eps2 = -mu_eps1 * pr_eps / (1.0 - pr_eps)

    # Cholesky of HIP covariance
    cov_ab = corr_ab * sigma_alpha * sigma_beta
    L11 = sigma_alpha
    L21 = cov_ab / sigma_alpha if sigma_alpha > 0 else 0.0
    L22 = np.sqrt(max(sigma_beta**2 - L21**2, 1e-15))

    # RNG
    rng = np.random.default_rng(seed)

    # HIP draws
    rn_hip1 = rng.standard_normal(n_sim)
    rn_hip2 = rng.standard_normal(n_sim)
    alpha = L11 * rn_hip1
    beta  = L21 * rn_hip1 + L22 * rn_hip2

    # Initialize AR(1)
    rn_z0 = rng.standard_normal(n_sim)
    ar_z1 = sd_z0 * rn_z0

    # Main loop
    ysim = np.zeros((n_sim, hmax))

    for h in range(1, hmax + 1):
        age_s = h / 10.0

        # Draws
        rn_p_ar  = rng.uniform(size=n_sim)
        rn_eta   = rng.standard_normal(n_sim)
        rn_unemp = rng.uniform(size=n_sim)
        rn_nu    = rng.uniform(size=n_sim)
        rn_p_eps = rng.uniform(size=n_sim)
        rn_eps   = rng.standard_normal(n_sim)

        # Advance AR(1)
        mask_ar = rn_p_ar <= pdf_ar
        ar_z1 = np.where(
            mask_ar,
            rho1 * ar_z1 + mu_eta1 + sd_eta1 * rn_eta,
            rho1 * ar_z1 + mu_eta2 + sd_eta2 * rn_eta
        )

        # Nonemployment (use sigmoid with clipping to avoid overflow)
        xi  = nu_const + nu_age * age_s + nu_z * ar_z1 + nu_inter * age_s * ar_z1
        xi  = np.clip(xi, -500, 500)
        pnu = 1.0 / (1.0 + np.exp(-xi))
        nu  = np.where(
            rn_unemp <= pnu,
            np.minimum(-np.log(np.maximum(rn_nu, 1e-15)) / max(nu_lam, 1e-15), 1.0),
            0.0
        )

        # Transitory shock
        eps = np.where(
            rn_p_eps <= pr_eps,
            mu_eps1 + sd_eps1 * rn_eps,
            mu_eps2 + sd_eps2 * rn_eps
        )

        # Income
        log_y = (a0 + a1 * age_s + a2 * age_s**2
                 + alpha + beta * age_s
                 + ar_z1 + eps)
        ysim[:, h - 1] = np.maximum(0.0, (1.0 - nu) * np.exp(log_y))

    return ysim


# ============================================================================
# SECTION 3: TOOLBOX — Moment computation (from toolbox_final.ipynb)
# ============================================================================

# Constants (matching Fortran)
NVASEINC = 13
NVASEMNT = 3
NIRINC   = 8
NIRCHG   = 10
NLAG     = 5
NLTINCPCT= 15
LTH      = 8
MINOBS  = 3
MINEMP  = 15
RMINWAGE = 1.5
DPMISSING = 1.0e15

VASEINCPCT  = np.array([1,2,11,21,31,41,51,61,71,81,91,96,100,101])
IRAVGINCPCT = np.array([1,6,11,31,51,71,91,96,101])
IRCHGPCT    = np.array([1,3,6,11,31,51,71,91,96,99,101])
LTINCPCT    = np.array([1,2,6,11,21,31,41,51,61,71,81,91,96,98,100,101])
NAGEBIN     = np.array([2,2,2])
AGEBINL     = np.array([1,9,19]) - 1
DF1         = np.array([2,6,1,2,3,4,6,11]) - 1
DF2         = np.array([1,1,0,0,0,0,0,0]) - 1


def _mean_var_miss(income):
    valid = income >= RMINWAGE
    if np.sum(valid) < 2:
        return 0.0, 0.0
    log_income = np.log(income[valid])
    return np.mean(log_income), np.var(log_income, ddof=1)

def _mean_miss(x):
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) == 0:
        return 0.0
    return np.mean(x[valid])

def _demean_col(x):
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) > 0:
        x[valid] = x[valid] - np.mean(x[valid])

def _sdskewkurt_miss(x):
    valid = x < (DPMISSING - 1.0)
    if np.sum(valid) < 2:
        return 0.0, 0.0, 0.0
    x_valid = x[valid]
    sd = np.std(x_valid, ddof=1)
    if sd == 0:
        return sd, 0.0, 0.0
    skew = stats.skew(x_valid, bias=False)
    kurt = stats.kurtosis(x_valid, bias=False)
    return sd, skew, kurt

def _sortrows_col1(a):
    valid_mask = a[:, 0] < (DPMISSING - 1.0)
    nonmiss = np.sum(valid_mask)
    valid_rows = a[valid_mask]
    invalid_rows = a[~valid_mask]
    sort_idx = np.argsort(valid_rows[:, 0])
    sorted_valid = valid_rows[sort_idx]
    if len(invalid_rows) > 0:
        result = np.vstack([sorted_valid, invalid_rows])
    else:
        result = sorted_valid
    return result, nonmiss


def calculate_moments(ysim_in):
    """
    Compute all moments from simulated income panel.
    Faithful translation of moments_from_data.f90.

    Args:
        ysim_in: (nsim, hmax) array of income in levels

    Returns:
        dict with keys: SdSkewKurt_L1, SdSkewKurt_L5, irmoments,
                        incgrwth, var_lny, EmpCDF
    """
    nsim, hmax = ysim_in.shape
    EMPCDF_NUM = hmax + 1

    SSK_L1 = np.zeros((3, NVASEINC, NVASEMNT))
    SSK_L5 = np.zeros((3, NVASEINC, NVASEMNT))
    irm    = np.zeros((2, NIRINC, NIRCHG, NLAG + 1))
    incg   = np.zeros((NLTINCPCT, LTH))
    varlny = np.zeros(hmax)
    ecdf   = np.zeros(EMPCDF_NUM)

    # A. Age dummies and variance of log income
    agedum    = np.zeros(hmax)
    avgagedum = np.zeros(hmax)

    for h in range(hmax):
        agedum[h], varlny[h] = _mean_var_miss(ysim_in[:, h])
    agedum = np.exp(agedum)

    for h in range(hmax):
        avgagedum[h] = np.mean(agedum[max(0, h - 4):h + 1])

    # B. Build longdata
    NLONG = min(28, hmax - 2)
    longdata = np.full((nsim * NLONG, 9), DPMISSING)

    for h in range(2, min(30, hmax)):
        lb = (h - 2) * nsim
        ub = (h - 1) * nsim

        numobs = np.zeros(nsim, dtype=int)
        avgpastinc = np.zeros(nsim)
        numobs[ysim_in[:, h] < RMINWAGE] = -5

        for j in range(min(h + 1, 5)):
            avgpastinc += np.maximum(ysim_in[:, h - j], RMINWAGE)
            numobs[ysim_in[:, h - j] >= RMINWAGE] += 1

        valid = numobs >= MINOBS
        avgpastinc[valid] = avgpastinc[valid] / (min(h + 1, 5) * avgagedum[h])
        avgpastinc[~valid] = DPMISSING
        longdata[lb:ub, 0] = avgpastinc

        for j in range(8):
            h_fut  = h + DF1[j] + 1
            h_base = h + DF2[j] + 1

            if h_fut < hmax:
                y_base = ysim_in[:, h_base] / agedum[h_base]
                y_fut  = ysim_in[:, h_fut]  / agedum[h_fut]

                valid_both = (ysim_in[:, h_base] >= RMINWAGE) | (ysim_in[:, h_fut] >= RMINWAGE)

                arc_chg = np.full(nsim, DPMISSING)
                arc_chg[valid_both] = (
                    2.0 * (y_fut[valid_both] - y_base[valid_both]) /
                    (y_fut[valid_both] + y_base[valid_both])
                )
                longdata[lb:ub, 1 + j] = arc_chg

        for l in range(NLAG + 1):
            if h + DF1[2 + l] + 1 < hmax:
                _demean_col(longdata[lb:ub, 3 + l])

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
            temp, nonmiss = _sortrows_col1(temp)

            for j in range(NVASEINC):
                lb2 = int(np.floor(nonmiss * (VASEINCPCT[j] - 1) / 100))
                ub2 = min(int(np.floor(nonmiss * (VASEINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
                if ub2 > lb2:
                    ssk  = _sdskewkurt_miss(temp[lb2:ub2 + 1, 1])
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

        temp = np.column_stack([longdata[lb:ub, 0], longdata[lb:ub, 3:9]])
        temp, nonmiss = _sortrows_col1(temp)

        for j in range(NIRINC):
            lb2 = int(np.floor(nonmiss * (IRAVGINCPCT[j] - 1) / 100))
            ub2 = min(int(np.floor(nonmiss * (IRAVGINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
            if ub2 <= lb2:
                continue

            temp2 = temp[lb2:ub2 + 1, 1:7].copy()
            temp2, nonmiss2 = _sortrows_col1(temp2)

            for k in range(NIRCHG):
                lb3 = int(np.floor(nonmiss2 * (IRCHGPCT[k] - 1) / 100))
                ub3 = min(int(np.floor(nonmiss2 * (IRCHGPCT[k + 1] - 1) / 100)), nonmiss2 - 1)
                if ub3 > lb3:
                    for l in range(NLAG + 1):
                        irm[i, j, k, l] = _mean_miss(temp2[lb3:ub3 + 1, l])

    # E. Lifetime income growth
    emp   = np.zeros(nsim, dtype=int)
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
    temp_lt, nonmiss = _sortrows_col1(temp_lt)

    for j in range(NLTINCPCT):
        lb = int(np.floor(nonmiss * (LTINCPCT[j] - 1) / 100))
        ub = min(int(np.floor(nonmiss * (LTINCPCT[j + 1] - 1) / 100)), nonmiss - 1)
        for h in range(LTH):
            if ub > lb:
                incg[j, h] = _mean_miss(temp_lt[lb:ub + 1, h + 1])

    return {
        'SdSkewKurt_L1': SSK_L1,
        'SdSkewKurt_L5': SSK_L5,
        'irmoments':     irm,
        'incgrwth':      incg,
        'var_lny':       varlny,
        'EmpCDF':        ecdf,
    }


# ============================================================================
# SECTION 4: FLATTEN / UNFLATTEN MOMENTS
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
        ('irmoments',     mom_dict['irmoments'].ravel()),
        ('incgrwth',      mom_dict['incgrwth'].ravel()),
        ('var_lny',       mom_dict['var_lny'].ravel()),
        ('EmpCDF',        mom_dict['EmpCDF'].ravel()),
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
# SECTION 5: LOAD TARGET MOMENTS (from .dat files)
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
    Fortran layout: (2*8*23) rows x 6 cols.
    We only keep 10 of the 23 shock bins that match the sim grid.
    """
    raw = np.loadtxt(path)  # (2*8*23, 6) = (368, 6)
    full = raw.reshape(2, 8, 23, 6)
    # The 10 shock bins used in simulation correspond to these indices
    # in the 23-bin Fortran grid (approximate mapping):
    shock_map = [0, 1, 2, 4, 8, 14, 18, 20, 21, 22]
    return full[:, :, shock_map, :]

def load_target_moments(data_path):
    """
    Load all target .dat files and flatten into a single vector.

    Returns:
        m: 1-D target moment vector
        slices: dict with index ranges for each moment group
    """
    intermediate = os.path.join(data_path, 'intermediate')

    ssk_l1 = load_ssk_dat(os.path.join(intermediate, 'SdSkewKurt_L1.dat'))
    ssk_l5 = load_ssk_dat(os.path.join(intermediate, 'SdSkewKurt_L5.dat'))
    ir_dat = load_ir_dat(os.path.join(intermediate, 'ImpulseA_mean.dat'))
    incg   = np.loadtxt(os.path.join(intermediate, 'meanLTinc_level.dat'))  # (15, 8)
    varlny = np.loadtxt(os.path.join(intermediate, 'var_lny.dat'))          # (36,)
    ecdf   = np.loadtxt(os.path.join(intermediate, 'EmpCDF.dat'))           # (37,)

    mom_dict = {
        'SdSkewKurt_L1': ssk_l1,
        'SdSkewKurt_L5': ssk_l5,
        'irmoments':     ir_dat,
        'incgrwth':      incg,
        'var_lny':       varlny,
        'EmpCDF':        ecdf,
    }
    return flatten_moments(mom_dict)


def generate_synthetic_targets(cfg):
    """
    If .dat files are not available, generate targets by simulating
    at the true parameter values. Useful for testing the optimizer.
    """
    print("[INFO] Generating synthetic target moments from THETA_TRUE ...")
    ysim = simulate_income(THETA_TRUE, cfg.n_sim, cfg.hmax, seed=42)
    mom  = calculate_moments(ysim)
    return flatten_moments(mom)


# ============================================================================
# SECTION 6: MSM OBJECTIVE FUNCTION
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
    """psi_n = 10th percentile of |m_n| within each moment set."""
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
    """F_n(θ) = (d_n - m_n) / (0.5(|d_n| + |m_n|) + ψ_n)"""
    denom = 0.5 * (np.abs(d) + np.abs(m)) + psi
    return (d - m) / denom


def build_weight_and_psi(m_target, slices):
    """
    Build the weight vector and psi vector from the target moments.

    Assigns relative importance:
      - var_lny, EmpCDF: high weight (tightly identified)
      - SdSkewKurt: medium weight
      - impulse responses: lower weight (noisier)
      - income growth: lower weight

    You can (and should) adjust these weights.
    """
    n_mom = len(m_target)

    # Group definitions: (index_array, total_weight_for_group)
    weight_groups = {}
    moment_sets   = {}

    for name, (s, e) in slices.items():
        idxs = np.arange(s, e)
        moment_sets[name] = idxs

        # Assign group weights (these control relative importance)
        if name == 'var_lny':
            weight_groups[name] = (idxs, 5.0)
        elif name == 'EmpCDF':
            weight_groups[name] = (idxs, 5.0)
        elif name.startswith('SdSkewKurt'):
            weight_groups[name] = (idxs, 3.0)
        elif name == 'irmoments':
            weight_groups[name] = (idxs, 1.0)
        elif name == 'incgrwth':
            weight_groups[name] = (idxs, 1.0)
        else:
            weight_groups[name] = (idxs, 1.0)

    w_diag = make_diagonal_weights(n_mom, weight_groups)
    psi    = compute_psi(m_target, moment_sets)

    return w_diag, psi, weight_groups, moment_sets


def msm_objective(theta, m_target, w_diag, psi, cfg):
    """
    The MSM objective: F(θ)' W F(θ).
    Uses Common Random Numbers (CRN) via fixed seed.
    """
    try:
        theta = project_to_bounds(theta, PARAM_BOUNDS)
        ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed)
        mom  = calculate_moments(ysim)
        d, _ = flatten_moments(mom)

        if d.shape != m_target.shape:
            return 1e20

        F = deviation_F(d, m_target, psi)
        return float(np.sum(w_diag * (F ** 2)))

    except Exception as e:
        # Return a large penalty for any numerical errors
        return 1e20


# ============================================================================
# SECTION 7: TIKTAK OPTIMIZER (Guvenen Appendix-D style)
# ============================================================================

def compute_bound_penalty(x, bounds, penalty_weight=1e6):
    lows, highs = bounds[:, 0], bounds[:, 1]
    below = np.maximum(lows - x, 0.0)
    above = np.maximum(x - highs, 0.0)
    return penalty_weight * float(np.sum(below**2 + above**2))


def tiktak_optimize(objective_fn, bounds, cfg, sobol_seed=999):
    """
    TikTak algorithm (Arnoud, Guvenen, Kleineberg 2019):
      Stage A: Evaluate objective on Sobol quasi-random points
      Stage B: Sequential local optimization with blending toward best

    Args:
        objective_fn: callable(theta) -> scalar objective value
        bounds: (K, 2) array of parameter bounds
        cfg: MSMConfig
        sobol_seed: seed for Sobol sequence

    Returns:
        best_result: scipy OptimizeResult for the best solution
        all_results: list of all local optimization results
    """
    bounds = np.asarray(bounds, float)
    K = bounds.shape[0]
    lows, highs = bounds[:, 0], bounds[:, 1]

    # ── Stage A: Sobol screening ──
    print(f"\n{'='*60}")
    print(f"STAGE A: Sobol screening ({cfg.sobol_draws} points)")
    print(f"{'='*60}")

    sampler = qmc.Sobol(d=K, scramble=True, seed=sobol_seed)
    m_pow2 = int(np.ceil(np.log2(cfg.sobol_draws)))
    u = sampler.random_base2(m=m_pow2)[:cfg.sobol_draws]
    starts = qmc.scale(u, lows, highs)

    t0 = time.time()
    vals = np.full(cfg.sobol_draws, np.inf)
    for i in range(cfg.sobol_draws):
        v = objective_fn(starts[i])
        vals[i] = v if np.isfinite(v) else np.inf
        if (i + 1) % 10000 == 0:
            elapsed = time.time() - t0
            rate = (i + 1) / elapsed
            print(f"  [{i+1}/{cfg.sobol_draws}] "
                  f"best so far = {np.min(vals[:i+1]):.6e}, "
                  f"{rate:.0f} evals/sec")

    # Filter legitimate points
    legit = np.isfinite(vals) & (vals < cfg.max_legit_obj_val)
    n_legit = int(legit.sum())
    vals[~legit] = np.inf
    print(f"\n  Legitimate points: {n_legit}/{cfg.sobol_draws}")

    if n_legit == 0:
        raise ValueError("No legitimate Sobol points found. Widen bounds or increase max_legit_obj_val.")

    # Sort and keep best
    order = np.argsort(vals)
    starts = starts[order]
    vals   = vals[order]
    actual_keep = min(cfg.keep_best, n_legit)

    print(f"  Best Sobol objective: {vals[0]:.6e}")
    print(f"  Keeping top {actual_keep} for local stage")

    # ── Stage B: Local refinement with TikTak blending ──
    print(f"\n{'='*60}")
    print(f"STAGE B: Local refinement ({actual_keep} restarts)")
    print(f"{'='*60}")

    z_star = starts[0].copy()
    f_star = vals[0]
    results = []

    def penalized_obj(x):
        x = np.asarray(x, float)
        pen = compute_bound_penalty(x, bounds, cfg.penalty_weight)
        x_clip = project_to_bounds(x, bounds)
        return objective_fn(x_clip) + pen

    for k in range(actual_keep):
        # Blending: early = explore, late = exploit
        frac    = (k + 1) / actual_keep
        theta_k = cfg.theta_min + (cfg.theta_max - cfg.theta_min) * frac
        x_start = theta_k * z_star + (1.0 - theta_k) * starts[k]
        x_start = project_to_bounds(x_start, bounds)

        # Run local methods
        best_res = None
        x_curr = x_start.copy()

        for method in cfg.local_methods:
            try:
                if method == "Powell":
                    try:
                        res = minimize(objective_fn, x0=x_curr, method="Powell",
                                       bounds=[tuple(b) for b in bounds],
                                       options={"maxiter": cfg.maxiter_local, "disp": False})
                    except TypeError:
                        res = minimize(penalized_obj, x0=x_curr, method="Powell",
                                       options={"maxiter": cfg.maxiter_local, "disp": False})
                        res.x = project_to_bounds(res.x, bounds)
                        res.fun = objective_fn(res.x)
                else:
                    res = minimize(penalized_obj, x0=x_curr, method=method,
                                   options={"maxiter": cfg.maxiter_local, "disp": False})
                    res.x = project_to_bounds(res.x, bounds)
                    res.fun = objective_fn(res.x)

                if best_res is None or (np.isfinite(res.fun) and res.fun < best_res.fun):
                    best_res = res
                x_curr = best_res.x.copy()
            except Exception:
                pass

        if best_res is not None and np.isfinite(best_res.fun):
            results.append(best_res)
            if best_res.fun < f_star:
                z_star = best_res.x.copy()
                f_star = best_res.fun
                print(f"  [Restart {k+1}/{actual_keep}] ★ New best: {f_star:.6e}")

        if (k + 1) % max(1, actual_keep // 10) == 0:
            print(f"  [Progress] {k+1}/{actual_keep} done, best = {f_star:.6e}")

    results.sort(key=lambda r: r.fun if np.isfinite(r.fun) else np.inf)
    print(f"\n  Final best objective: {results[0].fun:.6e}")

    return results[0], results


# ============================================================================
# SECTION 8: MAIN ENTRY POINT
# ============================================================================

def fit_msm(cfg=None, use_synthetic_targets=False):
    """
    Run the full MSM estimation.

    Args:
        cfg: MSMConfig (uses defaults if None)
        use_synthetic_targets: if True, generate targets from THETA_TRUE
                               if False, load from .dat files

    Returns:
        best: scipy OptimizeResult
        theta_hat: estimated parameter vector
        results: all local optimization results
    """
    if cfg is None:
        cfg = MSMConfig()

    # 1. Load or generate target moments
    if use_synthetic_targets:
        m_target, slices = generate_synthetic_targets(cfg)
    else:
        m_target, slices = load_target_moments(fp_data)

    n_mom = len(m_target)
    print(f"\nTotal moments: {n_mom}")
    for name, (s, e) in slices.items():
        print(f"  {name:20s}: indices [{s:5d}, {e:5d})  ({e-s} moments)")

    # 2. Build weights and psi
    w_diag, psi, _, _ = build_weight_and_psi(m_target, slices)

    # 3. Define objective
    def obj(theta):
        return msm_objective(theta, m_target, w_diag, psi, cfg)

    # 4. Run TikTak
    best, results = tiktak_optimize(obj, PARAM_BOUNDS, cfg)

    theta_hat = best.x
    print(f"\n{'='*60}")
    print(f"ESTIMATION COMPLETE")
    print(f"{'='*60}")
    print(f"Objective value: {best.fun:.6e}")
    print(f"\nEstimated parameters:")
    print(f"{'Parameter':20s} {'Estimate':>14s} {'True':>14s} {'Diff':>14s}")
    print(f"{'-'*62}")
    for i, name in enumerate(PARAM_NAMES):
        diff = theta_hat[i] - THETA_TRUE[i]
        print(f"{name:20s} {theta_hat[i]:14.6f} {THETA_TRUE[i]:14.6f} {diff:14.6f}")

    return best, theta_hat, results


# ============================================================================
# RUN
# ============================================================================

if __name__ == '__main__':
    # For testing: use small config + synthetic targets
    # For production: increase n_sim, sobol_draws, keep_best and set use_synthetic_targets=False
    cfg = MSMConfig(
        n_sim=10_000,          # reduce for testing (use 50_000+ for production)
        sobol_draws=2048,      # reduce for testing (use 250_000 for production)
        keep_best=50,          # reduce for testing (use 1_000 for production)
        maxiter_local=500,     # reduce for testing (use 1_000 for production)
    )

    best, theta_hat, results = fit_msm(cfg=cfg, use_synthetic_targets=True)
