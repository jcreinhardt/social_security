"""
Regression test: the moment vector at THETA_TRUE must match a committed
reference. This locks the hot-path invariant (simulate_income + the numba
moment kernels + argpartition binning) we validated by hand throughout
development -- any silent change to the moments breaks this.

rtol=1e-6 catches real changes (the bugs we hit moved moments by ~0.1-0.4)
while tolerating last-bit float drift across platforms/BLAS/numba builds.
Regenerate the reference deliberately if you intend to change a moment
definition:  python -c "import numpy as np; from msm_model import *; \
  np.save('tests/data/ref_moments_2000.npy', \
  flatten_moments(calculate_moments(simulate_income(THETA_TRUE,2000,36,42)))[0])"
"""

import os

import numpy as np
import pytest

from msm_model import simulate_income, calculate_moments, flatten_moments, THETA_TRUE

REF_DIR = os.path.join(os.path.dirname(__file__), "data")


@pytest.mark.parametrize("n_sim", [2000, 10000])
def test_moment_regression(n_sim):
    ref = np.load(os.path.join(REF_DIR, f"ref_moments_{n_sim}.npy"))
    v, _ = flatten_moments(calculate_moments(simulate_income(THETA_TRUE, n_sim, 36, 42)))
    assert v.shape == ref.shape
    np.testing.assert_allclose(v, ref, rtol=1e-6, atol=1e-9)


def test_flatten_slices_cover_vector():
    """flatten_moments slices partition the vector contiguously."""
    v, slices = flatten_moments(calculate_moments(simulate_income(THETA_TRUE, 2000, 36, 42)))
    covered = sorted(slices.values())
    assert covered[0][0] == 0
    assert covered[-1][1] == len(v)
    for (s0, e0), (s1, e1) in zip(covered, covered[1:]):
        assert e0 == s1            # no gaps / overlaps
