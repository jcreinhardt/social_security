# data/

## What the 2-parameter test uses

By default the estimation in `../code/` runs against **synthetic target
moments**: it simulates the income process once at the known true parameters
(`THETA_TRUE` in `../code/msm_model.py`) and uses the resulting moment vector as
the target. This needs **no input files** and gives a known ground truth, so a
correct optimizer must recover `a1 ≈ 0.8115` and `rho1 ≈ 0.9592` with an
objective near zero — ideal for benchmarking the algorithm.

## Estimating against the real PSID moments

To fit the empirical targets instead, place the Fortran moment files under
`data/intermediate/` and pass `--real-moments ../data` to `run_tiktak.py`.

```
data/intermediate/
    SdSkewKurt_L1.dat      # (39, 3)  -> (3, 13, 3): cross-sectional 1-yr growth
    SdSkewKurt_L5.dat      # (39, 3)  -> (3, 13, 3): cross-sectional 5-yr growth
    ImpulseA_mean.dat      # (368, 6) -> (2, 8, 10, 6): impulse responses
    meanLTinc_level.dat    # (15, 8): lifetime-income growth
    var_lny.dat            # (36,): variance of log income by age
    EmpCDF.dat             # (37,): employment CDF
```

A working copy of these files already exists in
`../earning_dynamics/data/intermediate/` (produced by the Stata moment programs
in `../guvenen_2021_replication/targeted_moments_stata/`); copy them here to use
them. The loader is `load_target_moments` in `../code/msm_model.py`.
