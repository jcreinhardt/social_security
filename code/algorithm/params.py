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
