"""
Unit tests for the simulation-side representative-agent impulse construction
(impulse_repagent.py), which mirrors impulse_LABOR_repagent_DIB.do.
"""
import numpy as np
import pytest

from impulse_repagent import (repagent_impulse, _quantile_groups, _re_group,
                              NRE, NSHK, NHOR, HORIZONS)
from moments import RMINWAGE

HMAX = 36


def test_quantile_groups_equal_counts():
    rng = np.random.default_rng(0)
    key = rng.normal(size=1000)
    for ng in (20, 100):
        g = _quantile_groups(key, ng)
        counts = np.bincount(g, minlength=ng)
        assert g.min() == 0 and g.max() == ng - 1
        assert counts.max() - counts.min() <= 1
        # groups ordered by key
        order = np.argsort(key)
        assert (np.diff(g[order]) >= 0).all()


def test_re_group_mapping():
    p = np.arange(100)
    g = _re_group(p)
    assert g[0] == 0 and g[4] == 0 and g[5] == 1          # 5-percentile bins
    assert g[90] == 18 and g[94] == 18
    assert (g[95:99] == 19).all() and g[99] == 20         # 96-99 and top 1
    assert np.bincount(g, minlength=NRE).tolist() == [5] * 19 + [4, 1]


def test_output_shape_and_finiteness():
    rng = np.random.default_rng(1)
    ysim = np.exp(rng.normal(3.0, 0.7, size=(20_000, HMAX)))
    out = repagent_impulse(ysim)
    assert out.shape == (2, NRE, NSHK, 2 * NHOR)
    assert np.isfinite(out).all()
    # sim shock is horizon-invariant: the 5 shock columns are duplicates
    for k in range(1, NHOR):
        assert np.array_equal(out[..., 0], out[..., k])


def test_constant_panel_gives_zero_moments():
    """Constant income (above the threshold): every shock and response is 0."""
    ysim = np.full((5_000, HMAX), 10.0)
    out = repagent_impulse(ysim)
    assert np.allclose(out, 0.0)


def test_common_growth_gives_zero_moments():
    """A deterministic common age profile is fully absorbed by the age
    normalizations: shocks and responses are 0."""
    prof = np.exp(0.03 * np.arange(HMAX))
    ysim = np.tile(10.0 * prof, (5_000, 1))
    out = repagent_impulse(ysim)
    assert np.allclose(out, 0.0, atol=1e-12)


def test_iid_panel_mean_reverts():
    """With i.i.d. income, big drops fully mean-revert: the t+1 response is
    positive for the lowest shock ranks and negative for the highest, and
    shocks increase across ranks."""
    rng = np.random.default_rng(2)
    ysim = np.exp(rng.normal(3.0, 0.5, size=(200_000, HMAX)))
    out = repagent_impulse(ysim)
    shock = out[..., 0]
    resp1 = out[..., NHOR]
    assert (np.diff(shock, axis=-1) >= -1e-12).all()      # ranks ordered
    assert (resp1[:, :, 0] > 0).all()                     # big drop -> recovery
    assert (resp1[:, :, -1] < 0).all()                    # big gain -> reversion
    # for iid income resp_k = -ln(mean res_t | cell) for every horizon k, so
    # the 5 response columns must coincide up to sampling noise
    resp = out[..., NHOR:]
    spread = np.abs(resp - resp[..., :1])
    # sampling noise dominates in the smallest cells (top-1% RE x extreme
    # shock rank), so bound the bulk, not the max
    assert np.quantile(spread, 0.95) < 0.03
    # and the recovery is bounded by the (negative) cell shock: part of the
    # shock reflects selection on t-1 income, not reversion
    mid = NRE // 2
    assert 0.0 < resp1[0, mid, 0] < -shock[0, mid, 0]


def test_zero_income_rows_are_excluded_but_future_zeros_count():
    """Nonemployed-at-t workers (income 0) are dropped from the selection (log
    construction) without breaking anything; zeros at t+k enter the cell means."""
    rng = np.random.default_rng(3)
    ysim = np.exp(rng.normal(3.0, 0.5, size=(50_000, HMAX)))
    drop = rng.random(ysim.shape) < 0.10
    ysim[drop] = 0.0
    out = repagent_impulse(ysim)
    assert np.isfinite(out).all()
    assert (np.abs(out) > 0).any()


def test_short_panel_returns_zeros():
    """A panel too short for any benchmark age yields an all-zero block rather
    than an error."""
    ysim = np.full((100, HORIZONS[-1] + 2), 10.0)   # hmax=12 < needed
    out = repagent_impulse(ysim)
    assert out.shape == (2, NRE, NSHK, 2 * NHOR)
    assert np.allclose(out, 0.0)
