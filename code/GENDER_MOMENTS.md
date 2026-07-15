# Gender-separated GKOS estimation: moment inventory, aggregation, and validation

Canonical reference for the single-sex (men/women) MSM estimation. Companion to
`code/algorithm/gender_targets.py`, `code/algorithm/impulse_repagent.py`,
`code/build_puf_empcdf.py`, and the tests in `code/tests/test_gender_targets.py`
+ `code/tests/test_gender_problem.py`. Regenerable diagnostic figures/tables land
in `output/gender_moments/` (git-ignored); this doc is the committed source of
truth.

## 0. Which code is canonical

The gender estimation lives in the top-level **`code/`** tree and is wired
through `Problem(gender="men"|"women")`. The earlier first pass in
`earning_dynamics/code_women/` is **deprecated and superseded**: its real-data
path is broken (it expects a never-generated `women_EmpCDF.dat` and run scripts
that point at a nonexistent `data/intermediate_women/`), and it still weights the
full seven-block objective. Do not use it; it is kept only as history.

## 1. Moment availability: original male replication vs. the 2016 workbooks

Legend: (a) male replication package (`.dat` targets built by the Stata programs
in `guvenen_2021_replication/`); (b) `data/GKOS_2016_moments_men.xlsx`;
(c) `data/GKOS_2016_moments_women.xlsx`.

| Moment family | (a) male replication | (b) men 2016 xlsx | (c) women 2016 xlsx |
|---|:--:|:--:|:--:|
| SSK L1 (sd/skew/kurt of 1-yr arc-% change) | `SdSkewKurt_L1.dat` | `L1_arc_age_re` | `L1_arc_age_re` |
| SSK L5 (5-yr) | `SdSkewKurt_L5.dat` | `L5_arc_age_re` | `L5_arc_age_re` |
| Mean lifetime-income levels / growth | `meanLTinc_level.dat` | `incgrowth` | `incgrowth` |
| Impulse responses (estimation grid) | `ImpulseA_mean.dat` | — | — |
| Impulse responses (repagent grid) | (do-file only) | `impulse log`, `impulse arc` | `impulse log`, `impulse arc` |
| Variance of log earnings by age | `var_lny.dat` | `varlny` | **missing** |
| Employment CDF | `EmpCDF.dat` | **missing** | **missing** |
| Top-coding fractions | (Stata) | `top_coding` | **missing** |
| Stayer/switcher SSK | — | `stayL1/L5_year`, `stayL1/L5_age_re` | **missing** |
| Year × RE cross-section | — | `cross_year_re` | **missing** |
| Imputed income growth | — | `imputed_incgrowth` | **missing** |
| Prob(large move) by year×RE | — | `impulse_year_re` | **missing** |

**Premise corrections worth stating explicitly:**
- The **employment/nonemployment CDF is not a GKOS moment** — it is absent from
  *both* workbooks (verified by a full-cell search). It exists only as the men's
  Stata-built `EmpCDF.dat`, and is constructed from the SSA PUF for both sexes
  (§4).
- The genuine GKOS block **women actually lack is `varlny`** (variance of log
  income by age), plus the non-targeted men-only extras (`top_coding`,
  `imputed_incgrowth`, stayer/switcher, `cross_year_re`, `impulse_year_re`).

## 2. How raw moments are collapsed for the SMM (identical for both sexes)

The full men's estimation targets ~1226 weighted moments in six blocks. The
workbook sheets are on a finer grid than the estimation and are collapsed exactly
as the men's `.dat` targets were built — **validated**: the men's collapse
reproduces `SdSkewKurt_L1/L5.dat` to ~1e-6 and `meanLTinc_level.dat` to `.dat`
rounding (`test_collapse_reproduces_men_dat`). Because women use the identical
code path, this anchors the women collapse too (women have no reference `.dat`).

- **SSK L1/L5** (`L{1,5}_arc_age_re`, 6 age groups × 100 recent-earnings
  percentiles × {sd, skew, kurt}): 6 age groups → 3 bins by pairwise mean
  (`{1,2},{3,4},{5,6}`, matching `NAGEBIN=[2,2,2]`); 100 RE percentiles → 13 bins
  with breakpoints `VASEINCPCT = [1,2,11,...,91,96,100,101]` (mean of
  per-percentile stats within each bin). Result: (3, 13, 3) = 117 per horizon.
  Kurtosis is raw (Gaussian = 3), N−1 sd, matching Stata/Guvenen.
- **incgrowth** (100 lifetime-earnings percentiles × 8 ages 25,30,…,60): 100 → 15
  bins with breakpoints `LTINCPCT` (mean within bin), ÷1000 ($ → $000s). Result:
  (15, 8) = 120.

## 3. The impulse block: two constructions

- **Estimation version** (`impulse_LABOR_estimation.do` → `ImpulseA_mean.dat`,
  used by the full-model men's replication, unchanged): 2 age bins × 8 uneven RE
  bins × 23 fixed change-percentile points; means of *individual* arc changes
  t−1→t+k, k ∈ {1,2,3,5,10}; positive earnings required at t−1 only; matched by
  interpolating the data response to the simulated change.
- **Workbook ("representative agent") version**
  (`impulse_LABOR_repagent_DIB.do`, identical construction for both sexes, mirror
  = `impulse_repagent.repagent_impulse`): benchmark years 1997–2003 pooled; alive
  through t+10; age at t−1 ∈ [25, 50]; age bins ≤34/≥35; RE = mean of
  max(labor, Y_min) over t−5..t−1 (≥3 years above Y_min), residualized by the age
  mean; positive earnings required at t−1 **and** t (log version); **21 RE
  groups** within age bin (nineteen 5-percentile bins, p96–99, p100); **20
  shock-quantile groups** of the age-demeaned log change t−1→t within each age×RE
  cell; statistic = log-changes of the **cell-mean** normalized income levels at
  horizons t+1, 2, 3, 5, 10.

The gender runs target the workbook `impulse log` sheet for **both** sexes and
match it **rank-to-rank** (both sides are shock-quantile-group means), so there is
no interpolation grid (`ir_data=None`). Documented, symmetric caveats: the
simulation has no pre-age-25 history (youngest benchmarks absent / shortened RE
windows) and no mortality (data conditions on survival to t+10); the shock-rank-10
"exact-zero-change" rows are anchor rows (42 cells × 5 horizons = 210 moments
zero-weighted); the shock columns are zero-weighted diagnostics; the log
construction drops moves to/from zero earnings (the extensive margin is carried by
EmpCDF). See `output/gender_moments/impulse_validation.png`.

## 4. EmpCDF for women: SSA 2004 PUF construction (`code/build_puf_empcdf.py`)

Guvenen's `EmpCDF_ByAge.do` counts years with earnings above
Y_min(t) = 40·13·0.5·minwage(t) between ages 25 and 60 and reports
ecdf[i] = 100·P(emp ≤ i), i = 0..35, forced 100 at 36. **PUF mirror:** all
December-2004 beneficiaries (any benefit type — restricting to retired workers
would truncate the low-attachment left tail, where many women claim as
spouses/widows) linkable to an earnings record, cohorts 1927–44 (the full
age-25–60 window lies inside the observed 1951–2003 earnings; age = year − yob +
1); the nominal threshold is applied to nominal PUF earnings. The earnings
subfile has no sex/age, so it is linked to the benefits subfile on `ID` for
`SEX`/`YOB`.

Sample funnel (reproduced by `test_puf_empcdf_reproducible`): 473,366
beneficiaries → 472,511 linked → 263,574 born 1927–44 (119,416 men; 144,158
women).

The raw PUF is biased vs. the MEF-based target (benefit-receipt conditioning,
survivorship to 2004, older cohorts): PUF men show **5.1%** with ≤10 employed
years vs. **10.3%** in Guvenen's target. The women's target is therefore
**gap-adjusted through men**:
`women_adj = clip(women_puf + (EmpCDF.dat − men_puf), 0, 100)`, made monotone,
endpoint forced to 100. Men keep the true `EmpCDF.dat`. Files:
`data/gender_targets/EmpCDF_{men,women}_puf.dat` (raw, diagnostic) and
`EmpCDF_women_pufadj.dat` (target); diagnostic `empcdf_puf_gapadj.png`.

`var_lny` is **not** supplemented from the PUF: taxable-maximum top-coding
truncates the upper tail and attenuates the variance, and there is no women's
benchmark to validate against — so it is simply dropped from the objective.

## 5. Gender target vector and weights

Layout (`gender_targets.flatten_gender_moments`; the full-model layout is
unchanged):

| block | shape | flat | weighted |
|---|---|---:|---:|
| SdSkewKurt_L1 | (3,13,3) | 117 | 117 |
| SdSkewKurt_L5 | (3,13,3) | 117 | 117 |
| ir_repagent | (2,21,20,10) | 8400 | 3990 (responses only, anchors excluded) |
| incgrwth | (15,8) | 120 | 120 |
| EmpCDF | (37,) | 37 | 36 |
| **total** | | **8791** | **4380** |

Weights renormalize Guvenen's sevenths after dropping only `var_lny` (×7/6): SSK
**1/3**, impulse-short (t+1,2,3) **1/6**, impulse-long (t+5,10) **1/6**, incgrwth
**1/6**, EmpCDF **1/6**; per-moment weight = share / block count. Scale floors
(psi): SSK 0.05, impulse 0.0403, others 0. Frozen caches:
`data/gender_targets/{men,women}.npz` (rebuild with
`python code/freeze_gender_targets.py --data data` after changing any input).

With EmpCDF and the impulse block restored, the five nonemployment parameters
(`nu_*`) and the persistent-shock block are identified in the gender runs
(previously: SSK + incgrwth only, 354 moments).

## 6. Data-side men-vs-women comparison

`python code/plot_gender_moments.py` renders the collapsed targets each sex fits,
men vs women (SSK sd/skew/kurt of 5-yr arc-% change by RE percentile; lifecycle
earnings growth and level by LE percentile; the employment-years CDF) →
`output/gender_moments/gender_targets_men_vs_women.png`. Headline gaps: women's
low-attachment mass is far heavier — **P[≤10 employed years] ≈ 34.6% (women) vs
10.3% (men)** — and top-decile lifetime earnings are **$183k (women) vs $488k
(men)**.

## 7. Validation (what the tests lock)

`cd code && python -m pytest tests/test_gender_targets.py tests/test_gender_problem.py`
(add `-m "not slow"` to skip the PUF re-parse). Coverage:

- **Layout/weights** (`test_cache_build_shape_and_weights`): 8791 flat / 4380
  weighted, block shares 1/3·1/6·1/6·1/6·1/6 summing to 1, psi floors, shock
  columns + anchor cells + forced-100 endpoint unweighted.
- **Men collapse anchored to `.dat`** (`test_collapse_reproduces_men_dat`,
  `.xlsx`-gated) — and the women collapse rides the same code path.
- **Cache↔workbook identity** for both sexes (`test_cache_matches_xlsx`).
- **Women block sanity** (`test_collapse_sanity`): positive finite SSK
  dispersion, finite leptokurtic higher moments, lifetime earnings monotone in
  the LE-percentile bin — catches a transposed/mis-indexed sheet read where women
  have no `.dat` to diff.
- **EmpCDF**: men == Guvenen `.dat`; women monotone, ends at 100, heavier left
  tail than men (`test_empcdf_targets`); women cache == local pufadj `.dat`
  (`test_women_empcdf_cache_matches_dat`, skipped where the git-ignored `.dat` is
  absent).
- **PUF reproducibility** (`test_puf_empcdf_reproducible`, `slow`, skipped
  without the raw PUF): re-parsing reproduces the committed
  `EmpCDF_{men,women}_puf.dat` / `_women_pufadj.dat` and confirms the men-PUF gap.
- **End-to-end objective** (`test_gender_problem.py`): `Problem(gender=...)`
  builds the target and returns a finite `Q` at `THETA_TRUE` for both sexes, with
  the simulated moment vector length matching the target.

## 8. Running the estimation

```
python code/run_tiktak.py --spawn <cores> --free all --gender {men,women} \
    --gender-data data ...
```
or the batch launchers `code/runs/submit_gender.sh` / `code/runs/hpc_gender_21param.sh`
(with `GENDER=` env var). The gender branch of `Problem` computes
`calculate_gender_moments` (shared SSK/incgrwth/EmpCDF kernels + `repagent_impulse`)
and flattens with `flatten_gender_moments`; no impulse interpolation (rank-to-rank
matching). Compare finished runs with `code/compare_gender_estimates.py`.
