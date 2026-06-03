# Python TikTak MSM — income-process estimation

A Python re-implementation of the Guvenen, Karahan, Ozkan & Song (2021)
income-process estimation. The income process is fit by the **Simulated Method
of Moments (SMM)**, and the global search is driven by the **TikTak** optimizer
(Arnoud, Guvenen & Kleineberg 2019). The original is Fortran
(`../guvenen_2021_replication/.../Estimation/` + `../TikTak-main/`); this port is
designed to run **in parallel across many processes and many machines** on an
HPC, coordinating purely through a shared filesystem.

This directory contains a **2-parameter test bed** (free: `a1`, `rho1`; the other
19 parameters fixed at their Guvenen values) used to optimize and benchmark the
algorithm against a known ground truth.

---

## 1. The economics

### The income process (`msm_model.py: simulate_income`)
Log income for individual *i* at age *h* is

```
log y = a0 + a1·s + a2·s²            (deterministic life-cycle profile, s = h/10)
        + α_i + β_i·s                (heterogeneous income profile, HIP)
        + z_ih                       (persistent AR(1) component)
        + ε_ih                       (transitory shock)
y = max(0, (1 − ν) · exp(log y))     (ν = non-employment shock)
```

with, across the **21 parameters**:
- **Life-cycle profile** `a0, a1, a2`.
- **HIP heterogeneity** `(α, β) ~ N(0, Σ)` set by `sigma_alpha, sigma_beta, corr_ab`.
- **Persistent AR(1)** `z = ρ·z + η`, where the innovation `η` is a two-component
  mixture (`pdf_ar, mu_eta1, sd_eta1, sd_eta2`) and the initial condition has std
  `sd_z0`. Persistence is `rho1`.
- **Transitory** `ε`: a two-component mixture (`pr_eps, mu_eps1, sd_eps1, sd_eps2`).
- **Non-employment** `ν`: occurs with a logit probability in age and the persistent
  state (`nu_const, nu_age, nu_z, nu_inter`), with duration drawn from an
  exponential (`nu_lam`).

### The moments (`msm_model.py: calculate_moments`)
~670 moments in six groups: cross-sectional dispersion/skewness/kurtosis of 1- and
5-year income growth by age × income bin (`SdSkewKurt_L1/L5`), impulse responses
(`irmoments`), lifetime-income growth (`incgrwth`), variance of log income by age
(`var_lny`), and the employment CDF (`EmpCDF`).

### The SMM objective (`msm_model.py: deviation_F`, `make_objective`)
For simulated moments `d(θ)` and targets `m`,

```
F_n(θ) = (d_n − m_n) / ( ½(|d_n| + |m_n|) + ψ_n )     ψ_n = 10th pct of |m| in group
Q(θ)   = Σ_n  w_n · F_n(θ)²                           w = diagonal group weights
```

Common Random Numbers (a fixed RNG seed) make `Q` deterministic in `θ`, so the
optimizer sees a smooth surface rather than simulation noise.

---

## 2. The TikTak algorithm (`tiktak.py`)

TikTak is a multi-start global optimizer:

1. **Sobol pre-test.** Draw a low-discrepancy Sobol set over the bounded
   parameter box and evaluate `Q` at each point.
2. **Sort & keep.** Keep the best `keep_best` "legitimate" points (finite,
   `Q < max_legit_obj_val`) as local-search start points, sorted ascending.
3. **Sequential local searches with blending.** Process starts `k = 0,1,…`. Each
   start is pulled toward the **running global best** `z*`:
   ```
   x_start_k = θ_k · z*  +  (1 − θ_k) · start_k,   θ_k ramps theta_min → theta_max
   ```
   Early searches (θ_k small) explore; later ones (θ_k → 1) refine near the best
   basin found so far. `blend_shape` controls the ramp: `"sqrt"` (default,
   Guvenen-style `θ_k = √frac`, concave — exploits the incumbent best earlier)
   or `"linear"`. Each `x_start_k` is polished with a local optimizer (Powell,
   then Nelder-Mead); the per-restart iteration budget scales down with θ_k
   (`maxiter_min_frac`), since exploit-heavy restarts start essentially at `z*`.
4. **Final polish** from the global best.

   *Note:* in practice these two knobs move wall time only marginally for this
   problem — the local optimizer self-terminates well before the iteration cap
   binds, so shrinking the cap rarely helps, and the Sobol stage plus the
   high-budget *explore* restarts dominate. They're kept because the sqrt ramp
   is Guvenen-faithful and reliably steers restarts into good basins at no cost.

TikTak scales roughly **linearly up to √N cores**, where *N* is the number of
local searches (see `../TikTak-main/README.md`); beyond that, extra cores compete
for the same top starts.

---

## 3. The file-based parallel design

The whole point of TikTak is that workers share *information* (the running best,
the work still to do) without shared memory or MPI — only a directory on a shared
filesystem. **One worker = one OS process.** They can be threads of a single
`--spawn N` launch on one node, or independent SLURM array tasks across many
nodes pointing at the same `--workdir`.

Coordination primitives (`tiktak.py: FileCoordinator`, porting `stateControl.f90`):

| Need | Mechanism |
|---|---|
| Mutual exclusion | `Locked` — `fcntl.flock(LOCK_EX)` on a `.lock` file (mirrors Fortran `myopen` `SHARE='DENYRW'`) |
| Claim the next unit of work | `claim_next(counter)` — atomic read/increment/write of an integer counter file |
| Global phase | `state` file with `get/set/wait_state` (workers poll while waiting) |
| Store results without write contention | **per-index result files** `sobol/<i>.json`, `local/<k>.json`, written tmp-then-`os.replace` (atomic); aggregation = glob |
| Read the running best `z*` | `read_best()` globs `local/*.json` |
| Leader election | first process to take `init.lock` and find no `initialized` flag |

State machine: `INIT → EVAL_SOBOL → SELECT_STARTS → LOCAL_SEARCH → POLISH → DONE`.
Workers race to claim Sobol indices, then start indices; whichever worker first
acquires `select.lock` / `polish.lock` performs those single-shot leader steps.

**Run directory layout** (`output/<run>/`):
```
state                 current phase            x_starts.npy        kept start points
*.lock                advisory locks           x_starts_vals.npy   their objective values
sobol_counter         next Sobol index         sobol/<i>.json      per-point evaluations
local_counter         next start index         local/<k>.json      per-start local results
n_sobol, n_starts     phase sizes              final_result.json   polished best (engine)
sobol_points.npy      the Sobol set            final_results.json  + tiktak_2param_results.csv (worker 0)
initialized           leader-done flag
```

> **NFS note:** `flock` is reliable on local disks and most HPC shared
> filesystems, but can be flaky on some NFS mounts. For production multi-node
> runs, install [`filelock`](https://pypi.org/project/filelock/) and swap the
> `Locked` class for `filelock.FileLock` (a one-class drop-in). The per-index
> result files are already NFS-safe (no concurrent append to a single file).

---

## 4. (a) Fortran → Python conversion map

**Hot path — runs on *every* objective evaluation, so it must be fast/vectorized:**

| Fortran (`OBJECTIVE.f90`) | Python (`msm_model.py`) | Notes |
|---|---|---|
| `SIMULATE` | `simulate_income` | vectorized over `n_sim`; loop only over `hmax` ages |
| `SIM_RN` | inline `np.random.default_rng` draws | CRN via fixed seed |
| `MOMENTS` | `calculate_moments` | the ~670 moments |
| `SdSkewKurt`, mean/var helpers | `_sdskewkurt_miss`, `_mean_var_miss`, `_mean_miss`, `_sortrows_col1` | missing-value-aware |
| `dfovec` / `OBJ_FUNC` | `deviation_F` / `make_objective` / `msm_objective` | scalar `Q(θ)` |

**Hot-path performance notes** (the objective is ~90% moment computation):
- `_sdskewkurt_miss`, `_mean_miss`, `_demean_col` are **numba-JIT** kernels
  (`@njit`, with a pure-Python fallback if numba is absent). The skew/kurtosis
  kernel computes the bias-corrected estimators directly, reproducing
  `scipy.stats.skew/kurtosis(bias=False)` to ~1e-13 without scipy's per-call
  wrapper overhead.
- Shocks are **frozen**: `draw_shocks`/`get_shocks` draw the simulation random
  numbers once and reuse them across every evaluation (the Python equivalent of
  the Fortran `SIM_RN`), instead of re-seeding each call. Bit-identical, and it
  removes the RNG cost from the hot loop.
- Percentile bins are formed by **rank**, and the per-bin statistics are
  order-independent, so `_sortrows_col1` uses `np.argpartition` at the rank
  cut-points (~O(N)) instead of a full `np.argsort` (O(N log N)) for the
  **continuous-key** sorts (cross-sectional income, lifetime income). The
  impulse-response block (section D) keeps a full sort: its inner key is the
  realized shock, which has a point-mass at zero, and `argpartition` would
  split those tied zeros across bins differently than the reference.
- Sections A+B of `calculate_moments` (variance of log income + the `longdata`
  panel of average past income and arc-percent changes) are a single numba
  `@njit` kernel `_build_longdata_ab` over raw arrays, replacing the
  Python-orchestrated loop with its many masks and large temporaries. And
  `_sortrows_col1` drops the missing rows (every call site only reads the
  non-missing prefix) and gathers in a single pass.
- Net effect vs. the first implementation: `calculate_moments` ≈195 → 65 ms,
  per objective evaluation ≈216 → 75 ms (−66%), end-to-end 10-worker wall time
  447 → 138 s (−69%) at `n_sim=10000`, with the moment vector unchanged to
  ~1e-13. The remaining cost is now near the floor: the `_build_longdata_ab`
  kernel and the numpy sorts. The section-D sorts stay in numpy on purpose —
  numba's `argsort` could break the shock-tie ordering differently. `numba` is
  pinned in `../environment.yml`.

**Parallel-coordination layer — re-implemented for file-based parallelism:**

| Fortran | Python (`tiktak.py`) | Notes |
|---|---|---|
| `TiktakGlobalSearch` state machine | `run_worker` | `INIT…DONE` phases |
| `stateControl`: `getState`/`setState`/`waitState` | `FileCoordinator.get/set/wait_state` | polled `state` file |
| `stateControl`: `getNextNumber`, `myopen` (locking) | `claim_next`, `Locked` | atomic counters / `flock` |
| `setupSobol`, `insobl`, `I4_SOBOL` | `scipy.stats.qmc.Sobol` (in `_try_become_leader`) | |
| `chooseSobol`, `indexx` (sort) | `_stage_select` + `np.argsort` | keep best-K legitimate |
| `LocalMinimizations`, `completeSearch` | `_stage_local_search` | claim & refine starts |
| `getModifiedParam` (blending) | blend step in `_stage_local_search` | `θ_k·z* + (1−θ_k)·start_k` |
| `getBestPoint` | `FileCoordinator.read_best` | glob `local/*` |
| `BOBYQA_H`, `amoeba`, `EST_dfpmin` | `local_search` → `scipy.optimize.minimize` | Powell + Nelder-Mead w/ bound penalty |

---

## 5. (b) Running the 2-parameter test

Use the project conda env (has numpy/scipy/pandas): **`conda run -n socsec_mac python …`**

**Single machine, N local workers:**
```bash
conda run -n socsec_mac python code/run_tiktak.py \
    --spawn 4 --n-sim 25000 --n-sobol 2048 --keep-best 40 --maxiter 600 \
    --workdir output/run_2param
```
The parent wipes `--workdir` (unless `--resume`), launches 4 workers, and worker 0
prints a recovery table and writes `final_results.json` + `tiktak_2param_results.csv`.
With synthetic targets the run recovers the truth: **a1 ≈ 0.8115, rho1 ≈ 0.9592,
Q ≈ 0.**

**HPC SLURM array (many machines, shared filesystem):**
```bash
#SBATCH --array=0-63
#SBATCH --ntasks=1 --cpus-per-task=1
WORKDIR=/shared/fs/run_2param          # must be on the shared filesystem
conda run -n socsec_mac python code/run_tiktak.py \
    --worker-id $SLURM_ARRAY_TASK_ID --workers $SLURM_ARRAY_TASK_COUNT \
    --workdir $WORKDIR --n-sim 50000 --n-sobol 250000 --keep-best 1000
```
Each array task is one independent worker; they coordinate only through
`$WORKDIR`. Worker 0 aggregates once the run reaches `DONE`. (Create the workdir
fresh per run; the workers do not wipe it in array mode.)

**Estimate against the real PSID moments** instead of synthetic: drop the `.dat`
files into `../data/intermediate/` and add `--real-moments ../data`.

### Intra-node scaling test (HPC)
`hpc_scaling_test.sh` is a self-contained SLURM job that runs the *same*
2-parameter problem at several core counts on one node (default 12/24/36/48/60)
and reports speed + accuracy. Copy the repo (`code/` + `data/` +
`environment.yml`) to the cluster and submit from the repo root:
```bash
sbatch code/hpc_scaling_test.sh
```
It creates/activates the conda env from `environment.yml`, pins one BLAS thread
per worker, warms the numba cache once (so the first config isn't charged for
JIT compilation), times each run, and writes `output/scaling/scaling_summary.csv`
plus per-core logs. `scaling_report.py output/scaling` rebuilds the table:
core count, wall time, speedup + parallel efficiency (relative to the smallest
count), objective, and the `a1`/`rho1` estimate and error vs. truth. Edit the
knobs at the top of the script (`CORES_LIST`, `N_SIM`, `N_SOBOL`, `KEEP_BEST`,
`MAXITER`); keep `KEEP_BEST` ≥ the largest core count so stage B saturates
every core. Set `--cpus-per-task` to your node size.

For a **fast pipeline check** that schedules quickly (small request, so it
backfills) while a big job waits in the queue, submit the companion
`hpc_scaling_quick.sh` — a tiny workload at small core counts (2/4/8/12) that
verifies the whole chain (module + conda env + numba + file coordination +
report) end-to-end in a couple of minutes. It writes `output/scaling_quick/` and
is *not* a precise benchmark (it does not take the node exclusively), only a
correctness/sanity run; use the full script for real numbers. Both scripts share
their body via `_scaling_lib.sh`, so env fixes apply to both.

### Sizing `--mem`
`mem_benchmark.py` measures one worker's peak RSS and extrapolates to N workers
(the job runs N independent processes, so total ≈ N × per-worker — and SLURM's
`MaxRSS` undercounts that, reporting only the largest single process):
```bash
python mem_benchmark.py --n-sim 25000 --cores 12 24 36 48 60
```
At `n_sim=25000` that's ~425 MB/worker → ~32 GB (with headroom) at 60 cores,
which is why the full script requests 48 GB; the quick run needs ~4 GB. Re-run
it if you change `n_sim` (memory scales with it).

### Choosing which parameters to estimate
`--free` selects the free parameters; the rest stay at their Guvenen values.
Default is `a1,rho1` (the 2-param test bed). For the **full 21-parameter
problem** pass `--free all`, or any comma-separated subset, e.g.
`--free a0,a1,a2,rho1`:
```bash
conda run -n socsec_mac python code/run_tiktak.py --spawn 8 --free all \
    --n-sim 25000 --n-sobol 50000 --keep-best 480 --maxiter 1500 \
    --workdir output/run_21param
```

### Full 21-parameter run on an HPC + plots
`hpc_full_21param.sh` solves all 21 parameters on one 96-core node against
synthetic targets (so the known answer for each is its Guvenen value), then runs
`plot_results.py` to produce two figures in the run dir:
- `params_vs_guvenen.png` — the found minimum vs. the Guvenen value for every
  parameter, as normalized positions within each parameter's search bounds.
- `objective_slices.png` — a 1-D slice of the objective along each parameter
  (others held at the estimate), marking the estimate and the Guvenen value, so
  you can see how well each parameter is identified.
```bash
sbatch code/hpc_full_21param.sh
# or regenerate plots from a finished run:
python code/plot_results.py output/run_21param
```
The defaults are a sensible first solve, not Guvenen's full budget (900k Sobol /
2000 restarts) — scale `N_SOBOL`/`KEEP_BEST` up (and `--time`/`--mem`) for a more
thorough global search. 21-D local searches are far more expensive than 2-D, so
expect this to run for hours.

### Monitoring a live run
While a job is optimizing, snapshot its progress without disturbing it —
`monitor.py` is read-only and reads only the small coordination files (not the
tens-of-thousands of Sobol results), so it's safe to run anytime against the
shared work directory:
```bash
python code/monitor.py output/run_21param           # one-shot
watch -n 30 python code/monitor.py output/run_21param   # refresh every 30s
```
It prints the current phase, Sobol/local-stage progress, the current best
objective, and a table of the current-best parameters vs. their Guvenen values
(with each parameter's error as a % of its bound range). `run_tiktak.py` writes
a `run_meta.json` at start so this works before the run finishes.

### Key flags
`--spawn N` local workers · `--worker-id`/`--workers` array mode ·
`--free all|<names>` parameters to estimate · `--workdir` shared dir ·
`--n-sim` individuals · `--n-sobol` Sobol draws · `--keep-best` local starts ·
`--maxiter` local-opt iterations · `--blend-shape sqrt|linear` ·
`--maxiter-min-frac` (exploit-restart budget, 1.0 = no scaling) · `--seed` CRN
seed · `--sobol-seed` shared Sobol scramble seed · `--real-moments PATH` ·
`--resume`.

## 6. Layout
The things you *run* sit flat in `code/`; the importable library lives in
`code/lib/`. Each entry point adds `lib/` to `sys.path` at startup, so run
commands and imports are unaffected by the split.

**`code/lib/` — the importable library** (economics core split by responsibility):
- `params.py` — the 21 parameter names, Guvenen values (`THETA_TRUE`), bounds.
- `config.py` — `MSMConfig` (all run knobs).
- `dgp.py` — frozen-shock draws + `simulate_income` (Fortran `SIMULATE`/`SIM_RN`).
- `moments.py` — the numba moment kernels + `calculate_moments` (Fortran `MOMENTS`).
- `objective.py` — weights/ψ, `deviation_F`, `msm_objective` (Fortran `dfovec`).
- `targets.py` — synthetic + real (`.dat`) target moments.
- `msm_model.py` — back-compat shim re-exporting all of the above (so
  `from msm_model import …` and notebooks keep working).
- `problem.py` — `Problem` over any free-parameter subset (incl. all 21).
- `problem_2param.py` — thin specialization (`a1`, `rho1`) for the test bed.
- `tiktak.py` — file-coordinated TikTak engine (`FileCoordinator`, `run_worker`).

**`code/` — entry points you run directly:**
- `run_tiktak.py` — CLI / worker entry point and result aggregation.
- `monitor.py` — read-only live progress snapshot (current best vs Guvenen).
- `plot_results.py` — recovery + objective-slice figures from a finished run.
- `benchmark.py`, `mem_benchmark.py` — per-step timing and memory sizing.
- `scaling_report.py` — assemble the scaling-sweep comparison table.
- `hpc_scaling_test.sh` / `hpc_scaling_quick.sh` / `hpc_full_21param.sh` +
  `_scaling_lib.sh` — HPC scaling sweep, fast sanity run, and the full
  multi-core solve.

Reused, validated economics core from `../earning_dynamics/code/msm_optimizer.py`.

## 7. Tests
A pytest suite under `code/tests/` guards the invariants we relied on during
development. Run from `code/` (needs `pytest`, pinned in `../environment.yml`):
```bash
cd code && pytest              # full suite (~30s; the recovery test optimizes)
cd code && pytest -m "not slow"   # fast subset (~1s): regression + coordinator
```
- `test_moments.py` — **regression** of the moment vector at `THETA_TRUE` vs. a
  committed reference (`tests/data/ref_moments_*.npy`); locks the hot path to
  `rtol=1e-6`. Regenerate the reference deliberately if you change a moment
  definition (command in the test's docstring).
- `test_coordinator.py` — `FileCoordinator`: `claim_next` hands out each index
  exactly once under concurrency, state transitions, `read_best`, locking.
- `test_recovery.py` — tiny 2-param synthetic end-to-end; asserts `a1`/`rho1`
  recovery (marked `slow`).
