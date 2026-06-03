"""
targets.py
==========
Target moment vectors: load the empirical PSID moments from the Fortran ``.dat``
files, or generate synthetic targets by simulating at the Guvenen values
(used for the recovery/performance tests, where the ground truth is known).
"""

import os

import numpy as np

from params import THETA_TRUE
from dgp import simulate_income, get_shocks
from moments import calculate_moments, flatten_moments


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
