"""
Tests for the single-sex (men/women) target construction in gender_targets.py.

Two layers:
  * Cache + shape/weight invariants — always run (use the committed
    data/gender_targets/<sex>.npz caches and data/intermediate/*.dat).
  * Workbook collapse vs. the known men .dat — skipped when the heavy .xlsx
    workbooks aren't present (they are git-ignored / Dropbox-synced).
"""
import os

import numpy as np
import pytest

import gender_targets as gt
from targets import load_ssk_dat

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(REPO, "data")
HAVE_XLSX = os.path.exists(os.path.join(DATA, "GKOS_2016_moments_men.xlsx"))


@pytest.mark.parametrize("sex", ["men", "women"])
def test_cache_build_shape_and_weights(sex):
    """The committed npz cache yields a full-length vector with exactly the 354
    SSK+incgrwth moments weighted, weights summing to 1, and Guvenen psi floors."""
    m, slices, w, psi = gt.build_gender_target(sex, DATA)
    assert m.shape == w.shape == psi.shape
    assert int((w > 0).sum()) == 354                      # SSK_L1+L5 (234) + incgrwth (120)
    assert w.sum() == pytest.approx(1.0)                  # reweighted shares sum to 1

    ssk = np.concatenate([np.arange(*slices[k])
                          for k in ("SdSkewKurt_L1", "SdSkewKurt_L5")])
    incg = np.arange(*slices["incgrwth"])
    assert w[ssk].sum() == pytest.approx(2.0 / 3.0)
    assert w[incg].sum() == pytest.approx(1.0 / 3.0)
    assert np.allclose(psi[ssk], 0.05)                    # GUV_SCALE for SSK
    # dropped blocks carry no weight
    for name in ("irmoments", "var_lny", "EmpCDF"):
        assert w[np.arange(*slices[name])].sum() == 0.0


@pytest.mark.skipif(not HAVE_XLSX, reason="GKOS workbooks not present (Dropbox-synced)")
def test_collapse_reproduces_men_dat():
    """The workbook->grid collapse must reproduce the known men .dat targets."""
    for sheet, dat in [("L1_arc_age_re", "SdSkewKurt_L1.dat"),
                       ("L5_arc_age_re", "SdSkewKurt_L5.dat")]:
        col = gt.collapse_ssk(gt.load_ssk_xlsx(
            os.path.join(DATA, "GKOS_2016_moments_men.xlsx"), sheet))
        ref = load_ssk_dat(os.path.join(DATA, "intermediate", dat))
        assert np.abs(col - ref).max() < 1e-4

    inc = gt.collapse_incgrowth(gt.load_incgrowth_xlsx(
        os.path.join(DATA, "GKOS_2016_moments_men.xlsx")))
    ref = np.loadtxt(os.path.join(DATA, "intermediate", "meanLTinc_level.dat"))
    assert (np.abs(inc - ref) / np.abs(ref)).max() < 2e-3   # .dat rounding only


@pytest.mark.skipif(not HAVE_XLSX, reason="GKOS workbooks not present (Dropbox-synced)")
@pytest.mark.parametrize("sex", ["men", "women"])
def test_cache_matches_xlsx(sex):
    """The frozen cache must be byte-identical to building from the workbook."""
    mc, _, wc, pc = gt.build_gender_target(sex, DATA)        # via cache
    mx, _, wx, px = gt._build_from_xlsx(sex, DATA)           # via xlsx
    assert np.array_equal(mc, mx) and np.array_equal(wc, wx) and np.array_equal(pc, px)
