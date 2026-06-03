"""
End-to-end recovery smoke test: a single worker runs the full TikTak pipeline
(Sobol screen -> select -> local search -> polish) on the 2-parameter problem
with synthetic targets, and must recover the Guvenen values for a1 and rho1.
Exercises the integration of problem -> objective -> engine -> file coordination
-> final aggregation. Marked slow (it actually optimizes).
"""

import numpy as np
import pytest

from problem import Problem
from tiktak import FileCoordinator, run_worker, read_final


@pytest.mark.slow
def test_2param_synthetic_recovery(tmp_path, cfg_small):
    prob = Problem(["a1", "rho1"])
    objective = prob.make_objective(cfg_small)          # synthetic targets at THETA_TRUE
    coord = FileCoordinator(str(tmp_path / "run"))

    run_worker(coord, objective, prob.FREE_BOUNDS, cfg_small, wid=0)

    final = read_final(coord)
    assert final is not None, "polish did not write a final result"
    x = np.asarray(final["x"], float)

    # loose tolerances; observed recovery is far tighter (a1 ~1e-4, rho1 ~0)
    assert abs(x[0] - prob.FREE_TRUE[0]) < 0.05, f"a1 not recovered: {x[0]}"
    assert abs(x[1] - prob.FREE_TRUE[1]) < 0.02, f"rho1 not recovered: {x[1]}"
    assert final["f"] < 1e-2, f"objective too large: {final['f']}"
