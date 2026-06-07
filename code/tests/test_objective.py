"""
Tests that the MSM objective faithfully reproduces Guvenen et al.'s scheme
(OBJECTIVE.f90: dfovec / OBJ_FUNC): the symmetric percentage deviation with
fixed per-block scale floors, the block weights (seven equal shares, Sd/Skew/
Kurt and impulse responses each 2/7), the non-targeted entries zeroed, and the
sqrt-of-weighted-SSQ aggregation.
"""

import numpy as np

from objective import build_weight_and_psi, deviation_F, GUV_SCALE


def _toy_slices():
    """Minimal contiguous block layout (irmoments must be a multiple of
    NLAG+1=6 so the change/short/long lag split is well defined)."""
    spec = [("SdSkewKurt_L1", 4), ("SdSkewKurt_L5", 4), ("irmoments", 12),
            ("incgrwth", 3), ("var_lny", 2), ("EmpCDF", 3)]
    slices, i = {}, 0
    for name, n in spec:
        slices[name] = (i, i + n)
        i += n
    return slices, i


def _share(w, slices, name):
    s, e = slices[name]
    return w[s:e].sum()


def test_block_shares_are_the_seven_sevenths():
    slices, total = _toy_slices()
    w, _, _, _ = build_weight_and_psi(np.ones(total), slices)
    assert abs(w.sum() - 1.0) < 1e-12
    # Sd/Skew/Kurt (L1+L5 together) and impulse responses each get 2/7.
    assert abs(_share(w, slices, "SdSkewKurt_L1")
               + _share(w, slices, "SdSkewKurt_L5") - 2.0 / 7.0) < 1e-12
    assert abs(_share(w, slices, "irmoments") - 2.0 / 7.0) < 1e-12
    # The remaining three blocks get 1/7 each.
    for name in ("incgrwth", "var_lny", "EmpCDF"):
        assert abs(_share(w, slices, name) - 1.0 / 7.0) < 1e-12


def test_impulse_short_and_long_lags_each_one_seventh():
    slices, total = _toy_slices()
    w, _, _, _ = build_weight_and_psi(np.ones(total), slices)
    s, e = slices["irmoments"]
    lag = np.arange(e - s) % 6
    assert np.all(w[s:e][lag == 0] == 0.0)                 # change columns
    assert abs(w[s:e][np.isin(lag, [1, 2, 3])].sum() - 1.0 / 7.0) < 1e-12
    assert abs(w[s:e][np.isin(lag, [4, 5])].sum() - 1.0 / 7.0) < 1e-12


def test_non_targeted_entries_are_zeroed():
    slices, total = _toy_slices()
    w, _, _, _ = build_weight_and_psi(np.ones(total), slices)
    # last EmpCDF point (the forced 100) is not targeted
    assert w[slices["EmpCDF"][1] - 1] == 0.0
    assert np.all(w[slices["EmpCDF"][0]:slices["EmpCDF"][1] - 1] > 0.0)


def test_scale_floors_match_guvenen_constants():
    slices, total = _toy_slices()
    _, psi, _, _ = build_weight_and_psi(np.ones(total), slices)
    for name, (s, e) in slices.items():
        assert np.allclose(psi[s:e], GUV_SCALE[name])


def test_deviation_is_symmetric_percentage_with_zero_guard():
    d = np.array([2.0, 0.0])
    m = np.array([1.0, 0.0])
    psi = np.array([0.0, 0.0])
    F = deviation_F(d, m, psi)
    assert abs(F[0] - (1.0 / 1.5)) < 1e-12     # (2-1)/(0.5*(2+1)+0)
    assert np.isfinite(F[1]) and F[1] == 0.0   # 0/0 floored, not NaN


def test_objective_is_zero_at_truth_under_crn(cfg_small):
    """Synthetic target simulated at THETA_TRUE with the same frozen shocks ->
    simulated moments equal the target -> every deviation is 0 -> Q = 0."""
    from problem import Problem
    prob = Problem(["a1", "rho1"])
    objective = prob.make_objective(cfg_small)   # synthetic target at THETA_TRUE
    assert objective(prob.FREE_TRUE) < 1e-10
