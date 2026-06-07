"""
msm_model.py
============
Backward-compatibility shim. The economics core was split into focused modules
(params, config, dgp, moments, objective, targets); this module re-exports their
public API so existing imports — ``from msm_model import simulate_income, ...``
— and notebooks keep working unchanged. New code can import the specific module
instead (e.g. ``from moments import calculate_moments``).
"""

from params import PARAM_NAMES, THETA_TRUE, PARAM_BOUNDS
from config import MSMConfig
from dgp import (
    Shocks, draw_shocks, get_shocks, simulate_income,
)
from moments import (
    calculate_moments, flatten_moments,
    NVASEINC, NVASEMNT, NIRINC, NIRCHG, NLAG, NLTINCPCT, LTH,
    MINOBS, MINEMP, RMINWAGE, DPMISSING,
    VASEINCPCT, IRAVGINCPCT, IRCHGPCT, LTINCPCT, NAGEBIN, AGEBINL, DF1, DF2,
)
from objective import (
    project_to_bounds, make_diagonal_weights, compute_psi, deviation_F,
    build_weight_and_psi, msm_objective, GUV_SCALE,
    interp_impulse_targets, impulse_response_F,
)
from targets import (
    load_ssk_dat, load_ir_dat, load_ir_data_full, load_target_moments,
    synthetic_target_moments,
)

__all__ = [
    "PARAM_NAMES", "THETA_TRUE", "PARAM_BOUNDS", "MSMConfig",
    "Shocks", "draw_shocks", "get_shocks", "simulate_income",
    "calculate_moments", "flatten_moments",
    "NVASEINC", "NVASEMNT", "NIRINC", "NIRCHG", "NLAG", "NLTINCPCT", "LTH",
    "MINOBS", "MINEMP", "RMINWAGE", "DPMISSING",
    "VASEINCPCT", "IRAVGINCPCT", "IRCHGPCT", "LTINCPCT", "NAGEBIN", "AGEBINL",
    "DF1", "DF2",
    "project_to_bounds", "make_diagonal_weights", "compute_psi", "deviation_F",
    "build_weight_and_psi", "msm_objective", "GUV_SCALE",
    "interp_impulse_targets", "impulse_response_F",
    "load_ssk_dat", "load_ir_dat", "load_ir_data_full", "load_target_moments",
    "synthetic_target_moments",
]
