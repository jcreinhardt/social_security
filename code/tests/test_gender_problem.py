"""
Smoke test for the per-gender estimation path (Problem(gender=...)).

Proves the full single-sex objective runs end-to-end — target built from the
GKOS workbook cache + PUF EmpCDF, simulated moments computed with the
gender-specific kernels (repagent impulse, no var_lny), flattened, and scored —
without launching TikTak. Guards the alignment the optimizer relies on: the
simulated moment vector must match the target length (a mismatch makes the
objective return its 1e20 sentinel), and the block weights must sum to 1.
"""
import numpy as np
import pytest

from problem import Problem


@pytest.mark.parametrize("sex", ["men", "women"])
def test_gender_objective_runs(sex, cfg_small):
    prob = Problem(free="all", gender=sex, gender_data="../data")

    # Target/weights/psi wired straight from gender_targets.
    m_target, slices, w, psi, ir_data = prob.build_target(cfg_small)
    assert m_target.size == 8791
    assert ir_data is None                     # repagent impulse is matched rank-to-rank
    assert int((w > 0).sum()) == 4380
    assert w.sum() == pytest.approx(1.0)

    obj = prob.make_objective(cfg_small)
    q = obj(prob.FREE_TRUE)                     # evaluate at Guvenen's THETA_TRUE
    # A finite value below the 1e20 sentinel proves the simulated moment vector
    # matched the target length and every block scored.
    assert np.isfinite(q) and 0.0 < q < 1e19
    assert obj.m_target.size == 8791
