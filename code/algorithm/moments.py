"""
moments.py
==========
Moment computation (Fortran ``MOMENTS``): from a simulated income panel, build
the ~670 targeted moments. This is the per-evaluation hot path, so the heavy
inner work (the per-bin statistics and the longdata construction) is in numba
``@njit`` kernels, and percentile bins are formed by rank via ``argpartition``
where ties allow. Self-contained: depends only on numpy and (optionally) numba.
"""

import numpy as np

# Optional numba JIT for the moment kernels. Falls back to a no-op decorator
# (pure-Python loops) if numba is unavailable, so the module always imports.
try:
    from numba import njit
    _HAVE_NUMBA = True
except Exception:  # pragma: no cover
    _HAVE_NUMBA = False

    def njit(*args, **kwargs):
        if len(args) == 1 and callable(args[0]) and not kwargs:
            return args[0]

        def deco(f):
            return f
        return deco


# ---- constants -------------------------------------------------------------
NVASEINC = 13
NVASEMNT = 3
NIRINC = 8
NIRCHG = 10
NLAG = 5
NLTINCPCT = 15
LTH = 8
MINOBS = 3
MINEMP = 15
RMINWAGE = 1.5
DPMISSING = 1.0e15
_MISS = DPMISSING - 1.0   # values >= this are treated as missing

VASEINCPCT = np.array([1, 2, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 100, 101])
IRAVGINCPCT = np.array([1, 6, 11, 31, 51, 71, 91, 96, 101])
IRCHGPCT = np.array([1, 3, 6, 11, 31, 51, 71, 91, 96, 99, 101])
LTINCPCT = np.array([1, 2, 6, 11, 21, 31, 41, 51, 61, 71, 81, 91, 96, 98, 100, 101])
NAGEBIN = np.array([2, 2, 2])
AGEBINL = np.array([1, 9, 19]) - 1
# Lag offsets for the 8 (base, future) arc-change pairs.
DF1 = np.array([2, 6, 1, 2, 3, 4, 6, 11]) - 1
DF2 = np.array([1, 1, 0, 0, 0, 0, 0, 0]) - 1
_DF1_I64 = DF1.astype(np.int64)
_DF2_I64 = DF2.astype(np.int64)


# ---- numba leaf kernels ----------------------------------------------------
@njit(cache=True)
def _mean_miss(x):
    """Mean of non-missing entries (single pass; replaces scipy/numpy masks)."""
    n = 0
    s = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            n += 1
            s += v
    if n == 0:
        return 0.0
    return s / n


@njit(cache=True)
def _sdskewkurt_miss(x):
    """Sample sd (ddof=1), skewness, and RAW kurtosis of the non-missing
    entries, matching Guvenen's ``SdSkewKurt`` (utilities.F90) -- the Stata
    convention, NOT scipy's:

        sd   = sqrt(sum((x-mean)^2) / (n-1))          # N-1 sample sd
        skew = sum((x-mean)^3) / (n * sd^3)           # biased, N-1 sd in denom
        kurt = sum((x-mean)^4) / (n * sd^4)           # RAW kurtosis, normal = 3

    Crucially the kurtosis is RAW (no -3): the target .dat moments were produced
    by Guvenen's pipeline in raw units (a Gaussian gives 3), so the simulated
    moment must match. There is no bias correction (the Fortran comment is
    explicit: "!-3.0_DP This is the one used by STATA")."""
    n = 0
    s = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            n += 1
            s += v
    if n < 2:
        return 0.0, 0.0, 0.0
    mean = s / n
    m2 = 0.0
    m3 = 0.0
    m4 = 0.0
    for i in range(x.shape[0]):
        v = x[i]
        if v < _MISS:
            d = v - mean
            d2 = d * d
            m2 += d2
            m3 += d2 * d
            m4 += d2 * d2
    m2 /= n
    m3 /= n
    m4 /= n
    sd = (m2 * n / (n - 1)) ** 0.5      # sample std, ddof=1
    if sd <= 0.0:
        return sd, 0.0, 0.0
    sd3 = sd * sd * sd
    skew = m3 / sd3                      # Stata: biased, N-1 sd in denominator
    kurt = m4 / (sd3 * sd)              # RAW kurtosis (normal = 3, no -3)
    return sd, skew, kurt


def _sortrows_col1(a, pct=None):
    """Return ``(rows, n_nonmissing)`` where ``rows`` is the non-missing rows
    (col 0 < DPMISSING) gathered in ascending col-0 rank order. Missing rows
    are dropped, not appended: every call site only ever reads rows
    ``[0:n_nonmissing)``, so the old vstack of missing rows was pure overhead.
    Rows are gathered in a single pass via ``a[valid_idx[order]]`` (one copy,
    not two).

    The per-bin moments computed downstream are order-independent, so we don't
    need a full sort -- only the rows partitioned at the percentile *rank*
    cut-points. If ``pct`` (the percentile breakpoint array this block is binned
    by, e.g. VASEINCPCT) is given, we use ``np.argpartition`` at those cut
    indices (~O(N)) instead of a full ``np.argsort`` (O(N log N)). Bin
    membership is identical to the full-sort version for continuous keys (ties
    are measure-zero in the simulated data); the order of the valid rows fed to
    the sort is unchanged, so tie-breaking is bit-identical to before."""
    valid_idx = np.nonzero(a[:, 0] < _MISS)[0]
    nonmiss = valid_idx.size
    col0 = a[valid_idx, 0]

    if pct is not None and nonmiss > 2:
        # rank cut indices used downstream: floor(nonmiss*(pct-1)/100)
        kths = np.floor(nonmiss * (np.asarray(pct) - 1) / 100).astype(np.intp)
        kths = np.unique(kths[(kths > 0) & (kths < nonmiss)])
        order = (np.argpartition(col0, kths) if kths.size
                 else np.argsort(col0))
    else:
        order = np.argsort(col0)

    return a[valid_idx[order]], nonmiss


@njit(cache=True)
def _build_longdata_ab(ysim_in, df1, df2):
    """Sections A + B of MOMENTS, as one numba kernel: the variance of log
    income by age, and the `longdata` panel of average past income +
    arc-percent income changes (the impulse columns demeaned). Returns
    (var_lny, longdata). Bit-identical to the original numpy version."""
    nsim, hmax = ysim_in.shape
    varlny = np.zeros(hmax)
    agedum = np.zeros(hmax)

    # A. mean of log income (the age dummy) and variance of log income
    for h in range(hmax):
        n = 0
        sm = 0.0
        for i in range(nsim):
            v = ysim_in[i, h]
            if v >= RMINWAGE:
                n += 1
                sm += np.log(v)
        if n < 2:
            agedum[h] = 0.0
            varlny[h] = 0.0
        else:
            mean = sm / n
            ss = 0.0
            for i in range(nsim):
                v = ysim_in[i, h]
                if v >= RMINWAGE:
                    d = np.log(v) - mean
                    ss += d * d
            agedum[h] = mean
            varlny[h] = ss / (n - 1)
    for h in range(hmax):
        agedum[h] = np.exp(agedum[h])

    # 5-year trailing average of the age dummy
    avgagedum = np.zeros(hmax)
    for h in range(hmax):
        lo = h - 4 if h - 4 > 0 else 0
        sm = 0.0
        cnt = 0
        for hh in range(lo, h + 1):
            sm += agedum[hh]
            cnt += 1
        avgagedum[h] = sm / cnt

    # B. longdata
    NLONG = 28 if (hmax - 2) > 28 else (hmax - 2)
    longdata = np.full((nsim * NLONG, 9), DPMISSING)
    hmax_b = 30 if hmax > 30 else hmax

    for h in range(2, hmax_b):
        lb = (h - 2) * nsim
        kk = h + 1 if (h + 1) < 5 else 5      # min(h+1, 5)

        # col 0: average past income (over the last kk years), normalized
        for i in range(nsim):
            numobs = -5 if ysim_in[i, h] < RMINWAGE else 0
            api = 0.0
            for j in range(kk):
                vv = ysim_in[i, h - j]
                api += vv if vv > RMINWAGE else RMINWAGE
                if vv >= RMINWAGE:
                    numobs += 1
            if numobs >= MINOBS:
                longdata[lb + i, 0] = api / (kk * avgagedum[h])
            # else: stays DPMISSING

        # cols 1..8: arc-percent income changes at the 8 (base, future) pairs
        for j in range(8):
            h_fut = h + df1[j] + 1
            h_base = h + df2[j] + 1
            if h_fut < hmax:
                ad_b = agedum[h_base]
                ad_f = agedum[h_fut]
                for i in range(nsim):
                    yb_raw = ysim_in[i, h_base]
                    yf_raw = ysim_in[i, h_fut]
                    if yb_raw >= RMINWAGE or yf_raw >= RMINWAGE:
                        yb = yb_raw / ad_b
                        yf = yf_raw / ad_f
                        longdata[lb + i, 1 + j] = 2.0 * (yf - yb) / (yf + yb)
                    # else: stays DPMISSING

        # demean the impulse columns (3..3+NLAG) that were actually filled
        for l in range(NLAG + 1):
            if h + df1[2 + l] + 1 < hmax:
                col = 3 + l
                s = 0.0
                n = 0
                for i in range(nsim):
                    v = longdata[lb + i, col]
                    if v < _MISS:
                        s += v
                        n += 1
                if n > 0:
                    m = s / n
                    for i in range(nsim):
                        if longdata[lb + i, col] < _MISS:
                            longdata[lb + i, col] -= m

    return varlny, longdata


def calculate_moments(ysim_in):
    """
    Compute all moments from a simulated income panel.
    Faithful translation of MOMENTS in OBJECTIVE.f90.

    HOT PATH: runs on every objective evaluation.

    Returns:
        dict with keys: SdSkewKurt_L1, SdSkewKurt_L5, irmoments,
                        incgrwth, var_lny, EmpCDF
    """
    nsim, hmax = ysim_in.shape
    EMPCDF_NUM = hmax + 1

    SSK_L1 = np.zeros((3, NVASEINC, NVASEMNT))
    SSK_L5 = np.zeros((3, NVASEINC, NVASEMNT))
    irm = np.zeros((2, NIRINC, NIRCHG, NLAG + 1))
    incg = np.zeros((NLTINCPCT, LTH))
    ecdf = np.zeros(EMPCDF_NUM)

    # A + B. Variance of log income and the longdata panel (numba kernel).
    varlny, longdata = _build_longdata_ab(ysim_in, _DF1_I64, _DF2_I64)

    # C. Cross-sectional moments
    for i in range(3):
        for nh in range(NAGEBIN[i]):
            if i == 0:
                if nh == 0:
                    lb, ub = 0, 3 * nsim
                else:
                    lb, ub = 3 * nsim, 8 * nsim
            else:
                hstart = AGEBINL[i] + 5 * nh
                lb = hstart * nsim
                ub = lb + 5 * nsim

            if ub > len(longdata):
                continue

            temp = longdata[lb:ub, 0:3].copy()
            temp, nonmiss = _sortrows_col1(temp, VASEINCPCT)

            for j in range(NVASEINC):
                lb2 = int(np.floor(nonmiss * (VASEINCPCT[j] - 1) / 100))
                ub2 = min(int(np.floor(nonmiss * (VASEINCPCT[j + 1] - 1) / 100)) - 1, nonmiss - 1)
                if ub2 > lb2:
                    ssk = _sdskewkurt_miss(temp[lb2:ub2 + 1, 1])
                    ssk5 = _sdskewkurt_miss(temp[lb2:ub2 + 1, 2])
                    SSK_L1[i, j, :] += np.array(ssk) / NAGEBIN[i]
                    SSK_L5[i, j, :] += np.array(ssk5) / NAGEBIN[i]

    # D. Impulse response moments
    for i in range(2):
        if i == 0:
            lb, ub = 0, 8 * nsim
        else:
            lb = 8 * nsim
            ub = min(23 * nsim, len(longdata))
        if ub <= lb:
            continue

        # Section D feeds its rows into the inner shock sort (which has tied
        # zeros), so the outer order must be a full sort too -- otherwise the
        # inner tie-breaking changes. argpartition is reserved for the
        # single-level continuous-key sorts (sections C and E).
        temp = np.column_stack([longdata[lb:ub, 0], longdata[lb:ub, 3:9]])
        temp, nonmiss = _sortrows_col1(temp)

        for j in range(NIRINC):
            lb2 = int(np.floor(nonmiss * (IRAVGINCPCT[j] - 1) / 100))
            ub2 = min(int(np.floor(nonmiss * (IRAVGINCPCT[j + 1] - 1) / 100)) - 1, nonmiss - 1)
            if ub2 <= lb2:
                continue

            # NB: the shock key (temp2 col 0) has a point-mass at zero (no
            # income change), so its ties must be resolved by a full sort to
            # match the reference -- argpartition would split the zero-mass
            # arbitrarily across the shock bins. Hence no `pct` here.
            temp2 = temp[lb2:ub2 + 1, 1:7].copy()
            temp2, nonmiss2 = _sortrows_col1(temp2)

            for k in range(NIRCHG):
                lb3 = int(np.floor(nonmiss2 * (IRCHGPCT[k] - 1) / 100))
                ub3 = min(int(np.floor(nonmiss2 * (IRCHGPCT[k + 1] - 1) / 100)) - 1, nonmiss2 - 1)
                if ub3 > lb3:
                    for l in range(NLAG + 1):
                        irm[i, j, k, l] = _mean_miss(temp2[lb3:ub3 + 1, l])

    # E. Lifetime income growth + employment CDF
    emp = np.zeros(nsim, dtype=int)
    LTinc = np.zeros((nsim, LTH + 1))
    jj = 0

    for h in range(hmax):
        LTinc[:, 0] += np.maximum(ysim_in[:, h], RMINWAGE)
        emp[ysim_in[:, h] >= RMINWAGE] += 1
        if (h % 5 == 0) and (jj < LTH):
            LTinc[:, 1 + jj] = np.maximum(ysim_in[:, h], RMINWAGE)
            jj += 1

    LTinc[:, 0] = LTinc[:, 0] / hmax
    LTinc[emp < MINEMP, 0] = DPMISSING

    for i in range(EMPCDF_NUM - 1):
        ecdf[i] = 100.0 * np.sum(emp <= i) / nsim
    ecdf[-1] = 100.0

    temp_lt = LTinc.copy()
    temp_lt, nonmiss = _sortrows_col1(temp_lt, LTINCPCT)

    for j in range(NLTINCPCT):
        lb = int(np.floor(nonmiss * (LTINCPCT[j] - 1) / 100))
        ub = min(int(np.floor(nonmiss * (LTINCPCT[j + 1] - 1) / 100)) - 1, nonmiss - 1)
        for h in range(LTH):
            if ub > lb:
                incg[j, h] = _mean_miss(temp_lt[lb:ub + 1, h + 1])

    return {
        'SdSkewKurt_L1': SSK_L1,
        'SdSkewKurt_L5': SSK_L5,
        'irmoments': irm,
        'incgrwth': incg,
        'var_lny': varlny,
        'EmpCDF': ecdf,
    }


def flatten_moments(mom_dict):
    """
    Flatten all moment arrays into a single 1-D vector.
    Order: SSK_L1, SSK_L5, irmoments, incgrwth, var_lny, EmpCDF

    Returns:
        vec: 1-D array
        slices: dict mapping moment name -> (start_idx, end_idx)
    """
    arrays = [
        ('SdSkewKurt_L1', mom_dict['SdSkewKurt_L1'].ravel()),
        ('SdSkewKurt_L5', mom_dict['SdSkewKurt_L5'].ravel()),
        ('irmoments', mom_dict['irmoments'].ravel()),
        ('incgrwth', mom_dict['incgrwth'].ravel()),
        ('var_lny', mom_dict['var_lny'].ravel()),
        ('EmpCDF', mom_dict['EmpCDF'].ravel()),
    ]
    parts = []
    slices = {}
    idx = 0
    for name, arr in arrays:
        slices[name] = (idx, idx + len(arr))
        parts.append(arr)
        idx += len(arr)
    return np.concatenate(parts), slices
