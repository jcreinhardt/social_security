"""Shared pytest fixtures."""

import pytest

from config import MSMConfig


@pytest.fixture
def cfg_small():
    """A tiny config for fast end-to-end tests."""
    return MSMConfig(
        n_sim=2000, hmax=36, seed=42,
        sobol_draws=256, sobol_seed=999, keep_best=8,
        maxiter_local=150,
    )
