# data/

## What lives here

`data/intermediate/` holds the **real Guvenen data moments** (the Fortran `.dat`
files). The estimation run scripts in `../code/runs/` fit these by default
(`--real-moments "$ROOT/data"`), so the files must be present:

```
data/intermediate/
    SdSkewKurt_L1.dat      # (39, 3)  -> (3, 13, 3): cross-sectional 1-yr growth
    SdSkewKurt_L5.dat      # (39, 3)  -> (3, 13, 3): cross-sectional 5-yr growth
    ImpulseA_mean.dat      # (368, 6) -> (2, 8, 10, 6): impulse responses
    meanLTinc_level.dat    # (15, 8): lifetime-income growth
    var_lny.dat            # (36,): variance of log income by age
    EmpCDF.dat             # (37,): employment CDF
```

These were produced by the Stata moment programs in
`../guvenen_2021_replication/targeted_moments_stata/`; an identical copy lives in
`../earning_dynamics/data/intermediate/`. `data/` is git-ignored (synced
separately), so ensure these files are present on any machine you run on — the
run scripts check for them and error early if missing. The loader is
`load_target_moments` in `../code/algorithm/targets.py`.

## Synthetic targets (no input files)

For a noise-free recovery check / benchmarking, the code can instead simulate
the target at the known true parameters (`THETA_TRUE`): omit `--real-moments`.
The optimizer then must recover the truth (e.g. `a1 ≈ 0.8115`, `rho1 ≈ 0.9592`)
with objective ≈ 0. The benchmarking/scaling scripts use this mode (known ground
truth lets them report recovery accuracy across core counts).

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
