"""
params.py
=========
The 21 income-process parameters: their names (in order), the Guvenen-2021
values used as ground truth, and the estimation bounds. No dependencies beyond
numpy, so every other module can import these freely.

Faithful to ``guvenen_2021_replication/.../Estimation/OBJECTIVE.f90``.
"""

import numpy as np

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
# Two boxes, mirroring Guvenen's ESTIMATE/OBJECTIVE.f90:
#  * PARAM_BOUNDS = `param_bound` -- the HARD feasibility box. Used to clip the
#    objective and to bound the local search; the final estimate must lie here.
#  * PARAM_RANGE  = `param_range` -- the tighter, economically-informed SEARCH
#    box the Sobol screen samples within (ESTIMATE.f90:606 scales the [0,1]
#    Sobol draw by param_range, NOT param_bound). It seeds the global search in
#    a sensible region so the optimizer is not free to wander into degenerate
#    corners (e.g. the rare-big-jump persistent mixture); the local search can
#    still refine *out* of PARAM_RANGE within PARAM_BOUNDS, which is why a few
#    published values (e.g. pdf_ar=0.41 > the 0.35 screen ceiling) sit outside
#    it. Values transcribed from OBJECTIVE.f90:100-144 into our param order.
PARAM_BOUNDS = np.array([
    [-1.0,   5.0],     # a0
    [-1.0,   2.0],     # a1
    [-1.0,   0.5],     # a2
    [0.0,    2.0],     # sigma_alpha  (>0)
    [0.0,    0.5],     # sigma_beta   (>0)
    [-1.0,   1.0],     # corr_ab
    [-1.0,   1.02],    # rho1
    [0.0,    1.5],     # sd_z0        (>0)
    [0.0,    0.49],    # pdf_ar       (probability)
    [-1.0,   1.0],     # mu_eta1
    [0.0,    2.0],     # sd_eta1      (>0)
    [0.0,    2.0],     # sd_eta2      (>0)
    [0.01,   0.49],    # pr_eps       (probability)
    [-2.0,   2.0],     # mu_eps1
    [0.02,   2.0],     # sd_eps1      (>0)
    [0.02,   2.0],     # sd_eps2      (>0)
    [-10.0,  1.0],     # nu_const
    [-6.0,   2.0],     # nu_age
    [-6.0,   2.0],     # nu_z
    [-6.0,   2.0],     # nu_inter
    [0.0,    4.0],     # nu_lam       (>0)
])

PARAM_RANGE = np.array([
    [2.25,   3.5],     # a0
    [0.30,   1.0],     # a1
    [-0.30,  0.0],     # a2
    [0.2,    0.6],     # sigma_alpha
    [0.0,    0.35],    # sigma_beta
    [-0.1,   0.95],    # corr_ab
    [0.60,   0.99],    # rho1
    [0.20,   0.8],     # sd_z0
    [0.10,   0.35],    # pdf_ar
    [-0.5,   0.25],    # mu_eta1
    [0.20,   0.75],    # sd_eta1
    [0.0,    0.30],    # sd_eta2
    [0.05,   0.40],    # pr_eps
    [-0.75,  0.75],    # mu_eps1
    [0.05,   0.75],    # sd_eps1
    [0.01,   0.30],    # sd_eps2
    [-7.0,  -2.0],     # nu_const
    [-2.0,   0.0],     # nu_age
    [-6.0,   0.0],     # nu_z
    [-4.0,   0.0],     # nu_inter
    [0.01,   1.0],     # nu_lam
])
