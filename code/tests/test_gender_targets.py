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
# The gap-adjusted women EmpCDF .dat is a local, git-ignored artifact (the
# committed source of truth is the baked-in women.npz cache).
HAVE_WOMEN_EMPCDF_DAT = os.path.exists(
    os.path.join(DATA, "gender_targets", "EmpCDF_women_pufadj.dat"))
# The raw SSA 2004 PUF text is large and git-ignored; the reproducibility test
# only runs where it is present.
PUF_EARN_TXT = os.path.join(DATA, "SSA_PUF_2004", "earnings04text",
                            "OASDI Earnings PUF December 2004.txt")
HAVE_PUF = os.path.exists(PUF_EARN_TXT)

# Weighted moments: SSK_L1+L5 (234) + repagent impulse responses
# (2*21*20*5 = 4200, minus the 42 all-zero rank-10 anchor cells * 5 = 210)
# + incgrwth (120) + EmpCDF (36; the forced-100 endpoint is unweighted).
N_TARGETED = 234 + 3990 + 120 + 36


@pytest.mark.parametrize("sex", ["men", "women"])
def test_cache_build_shape_and_weights(sex):
    """The committed npz cache yields the gender-layout vector with exactly the
    targeted moments weighted, block shares renormalized to Guvenen's sevenths
    (minus var_lny), and the Guvenen psi floors."""
    m, slices, w, psi = gt.build_gender_target(sex, DATA)
    assert m.shape == w.shape == psi.shape
    assert m.size == 234 + 8400 + 120 + 37
    assert int((w > 0).sum()) == N_TARGETED
    assert w.sum() == pytest.approx(1.0)                  # reweighted shares sum to 1

    ssk = np.concatenate([np.arange(*slices[k])
                          for k in ("SdSkewKurt_L1", "SdSkewKurt_L5")])
    ir = np.arange(*slices["ir_repagent"])
    incg = np.arange(*slices["incgrwth"])
    emp = np.arange(*slices["EmpCDF"])
    assert w[ssk].sum() == pytest.approx(1.0 / 3.0)
    assert w[ir].sum() == pytest.approx(1.0 / 3.0)        # short 1/6 + long 1/6
    assert w[incg].sum() == pytest.approx(1.0 / 6.0)
    assert w[emp].sum() == pytest.approx(1.0 / 6.0)
    assert np.allclose(psi[ssk], 0.05)                    # GUV_SCALE for SSK
    assert set(np.round(psi[ir][w[ir] > 0], 4)) == {0.0403}

    # impulse shock columns (0-4 of each cell) are unweighted diagnostics
    ir4 = w[ir].reshape(2, gt.NRE, gt.NSHK, 2 * gt.NHOR)
    assert ir4[..., :gt.NHOR].sum() == 0.0
    # the all-zero anchor cells (shock rank 10) are unweighted
    m4 = m[ir].reshape(ir4.shape)
    anchor = np.all(m4 == 0.0, axis=-1)
    assert anchor.sum() >= 42 and ir4[anchor].sum() == 0.0
    # the forced-100 EmpCDF endpoint is unweighted
    assert w[emp[-1]] == 0.0 and m[emp[-1]] == pytest.approx(100.0)


def test_empcdf_targets():
    """Men's EmpCDF equals the Guvenen .dat; women's PUF gap-adjusted CDF is a
    valid monotone CDF ending at 100."""
    m_m, sl, _, _ = gt.build_gender_target("men", DATA)
    ref = np.loadtxt(os.path.join(DATA, "intermediate", "EmpCDF.dat"))
    e = np.arange(*sl["EmpCDF"])
    assert np.allclose(m_m[e], ref)

    m_w, _, _, _ = gt.build_gender_target("women", DATA)
    cdf_w = m_w[e]
    assert np.all(np.diff(cdf_w) >= 0)
    assert cdf_w[0] >= 0.0 and cdf_w[-1] == pytest.approx(100.0)
    # women's low-attachment left tail must exceed men's
    assert cdf_w[10] > m_m[e][10]


def test_flatten_matches_target_layout():
    """The simulation-side flatten must produce the same length/slices as the
    frozen target (this is the alignment the objective relies on)."""
    from moments import NVASEINC, NVASEMNT, NLTINCPCT, LTH
    zero = {
        "SdSkewKurt_L1": np.zeros((3, NVASEINC, NVASEMNT)),
        "SdSkewKurt_L5": np.zeros((3, NVASEINC, NVASEMNT)),
        "ir_repagent": np.zeros(gt.IR_SHAPE),
        "incgrwth": np.zeros((NLTINCPCT, LTH)),
        "EmpCDF": np.zeros(37),
    }
    vec, slices = gt.flatten_gender_moments(zero)
    m, sl, _, _ = gt.build_gender_target("men", DATA)
    assert vec.size == m.size and slices == sl


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
def test_impulse_sheet_loads():
    """The impulse log sheets are complete (840 cells each) and the shock
    columns are ordered across shock ranks within each cell."""
    for sex in ("men", "women"):
        ir = gt.load_impulse_xlsx(
            os.path.join(DATA, f"GKOS_2016_moments_{sex}.xlsx"))
        assert ir.shape == gt.IR_SHAPE
        assert not np.isnan(ir).any()
        anchor = np.all(ir == 0.0, axis=-1)
        assert anchor.sum() == 42 and set(np.where(anchor)[2]) == {9}
        # shocks weakly increase with shock rank (t+1 shock column), ignoring
        # the zero anchor row
        shk = ir[..., 0].copy()
        d = np.diff(shk, axis=-1)
        assert (d[:, :, [i for i in range(19) if i not in (8, 9)]] > -1e-9).all()


@pytest.mark.skipif(not HAVE_XLSX, reason="GKOS workbooks not present (Dropbox-synced)")
@pytest.mark.parametrize("sex", ["men", "women"])
def test_cache_matches_xlsx(sex):
    """The frozen cache must be byte-identical to building from the workbook."""
    mc, _, wc, pc = gt.build_gender_target(sex, DATA)        # via cache
    mx, _, wx, px = gt._build_from_xlsx(sex, DATA)           # via xlsx
    assert np.array_equal(mc, mx) and np.array_equal(wc, wx) and np.array_equal(pc, px)


# ---- women-side validation -------------------------------------------------
# The men collapse is anchored to the committed .dat by test_collapse_*; women
# have no reference .dat, so these guard the women blocks structurally (from the
# committed cache, so they run in CI) plus a PUF reproducibility check.

@pytest.mark.parametrize("sex", ["men", "women"])
def test_collapse_sanity(sex):
    """The collapsed SSK/incgrwth blocks (from the committed cache) must be
    economically well-formed: positive finite dispersion, finite higher moments,
    leptokurtic changes, and lifetime earnings monotone in the LE-percentile
    bin. Catches a transposed/mis-indexed sheet read that structural shape/weight
    tests would miss (women have no reference .dat to diff against)."""
    from moments import NVASEINC, NVASEMNT, NLTINCPCT, LTH
    m, sl, _, _ = gt.build_gender_target(sex, DATA)
    for blk in ("SdSkewKurt_L1", "SdSkewKurt_L5"):
        sd, skew, kurt = np.moveaxis(
            m[slice(*sl[blk])].reshape(3, NVASEINC, NVASEMNT), -1, 0)
        assert np.isfinite(sd).all() and (sd > 0).all()      # dispersion positive
        assert np.isfinite(skew).all() and np.isfinite(kurt).all()
        assert (kurt > 1.0).all()                            # leptokurtic changes
    inc = m[slice(*sl["incgrwth"])].reshape(NLTINCPCT, LTH)
    assert (inc > 0).all()
    # mean earnings (over ages) strictly increase across the 15 lifetime-earnings
    # percentile bins.
    assert (np.diff(inc.mean(axis=1)) > 0).all()


@pytest.mark.skipif(not HAVE_WOMEN_EMPCDF_DAT,
                    reason="women EmpCDF .dat is a local (git-ignored) artifact")
def test_women_empcdf_cache_matches_dat():
    """The EmpCDF baked into the committed women.npz cache must equal the local
    gap-adjusted PUF .dat — a stale-cache guard (the two are frozen separately:
    build_puf_empcdf.py writes the .dat, freeze_gender_targets.py bakes it in)."""
    m_w, sl, _, _ = gt.build_gender_target("women", DATA)
    e = np.arange(*sl["EmpCDF"])
    dat = np.loadtxt(os.path.join(DATA, "gender_targets", "EmpCDF_women_pufadj.dat"))
    assert np.allclose(m_w[e], dat, atol=1e-3)               # .dat is 4-dp rounded


@pytest.mark.slow
@pytest.mark.skipif(not HAVE_PUF, reason="raw SSA 2004 PUF text not present")
def test_puf_empcdf_reproducible():
    """Re-running the build_puf_empcdf kernels on the raw PUF reproduces the
    committed EmpCDF_{men,women}_puf.dat and the gap-adjusted women target, and
    the raw men-PUF CDF differs materially from Guvenen's MEF target — the bias
    the men-bridge gap adjustment is there to correct."""
    import build_puf_empcdf as bp
    puf = os.path.join(DATA, "SSA_PUF_2004")
    eids, earn = bp.parse_earnings(
        PUF_EARN_TXT, os.path.join(puf, "earn_cache.npz"))
    bids, yob, sex = bp.parse_benefits(
        os.path.join(puf, "benefits04text", "OASDI Benefits PUF December 2004.txt"))
    id2row = {int(i): k for k, i in enumerate(eids)}
    linked = np.array([int(i) in id2row for i in bids])
    coh = linked & (yob >= bp.YOB_LO) & (yob <= bp.YOB_HI)
    target = np.loadtxt(os.path.join(DATA, "intermediate", "EmpCDF.dat"))

    cdfs = {}
    for label, code in (("men", "M"), ("women", "F")):
        sel = coh & (sex == code)
        rows = np.array([id2row[int(i)] for i in bids[sel]])
        cdfs[label] = bp.empcdf(bp.emp_years(earn[rows], yob[sel]))
    women_adj = np.clip(cdfs["women"] + (target - cdfs["men"]), 0.0, 100.0)
    women_adj = np.maximum.accumulate(women_adj)
    women_adj[36] = 100.0

    gt_dir = os.path.join(DATA, "gender_targets")
    for label, cdf in (("men", cdfs["men"]), ("women", cdfs["women"])):
        ref = np.loadtxt(os.path.join(gt_dir, f"EmpCDF_{label}_puf.dat"))
        assert np.allclose(cdf, ref, atol=1e-3)              # .dat is 4-dp rounded
    ref_adj = np.loadtxt(os.path.join(gt_dir, "EmpCDF_women_pufadj.dat"))
    assert np.allclose(women_adj, ref_adj, atol=1e-3)
    # the raw PUF men CDF is materially off Guvenen's MEF target (>1pp somewhere),
    # and women have a heavier low-attachment left tail than men.
    assert np.abs(cdfs["men"] - target).max() > 1.0
    assert cdfs["women"][10] > cdfs["men"][10]
