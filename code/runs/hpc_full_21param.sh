#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_21param
#SBATCH --nodes=1
#SBATCH --ntasks=1                # one launcher task; it spawns the workers
#SBATCH --cpus-per-task=32        # match to a node with >= this many cores (this cluster: 32)
#SBATCH --exclusive
#SBATCH --partition=default_queue # usually idle here -> starts immediately; capped at 4h
#SBATCH --time=04:00:00           # default_queue QOS MaxWall; workload below is sized to fit
#SBATCH --mem=48G                 # ~32 workers x ~0.45 GB at n_sim=25000 (mem_benchmark.py)
#SBATCH --output=tiktak_21param_%j.out
# ---------------------------------------------------------------------------
# Full 21-parameter Guvenen income-process estimation on one node with 64
# cores, fitting the REAL Guvenen data moments in data/intermediate/*.dat.
# After the solve it produces two figures comparing the found minimum to the
# published Guvenen values and showing a slice of the objective along each
# parameter.
#
#     sbatch code/runs/hpc_full_21param.sh
#
# Requires the moment files in data/intermediate/ (SdSkewKurt_L1.dat,
# SdSkewKurt_L5.dat, ImpulseA_mean.dat, meanLTinc_level.dat, var_lny.dat,
# EmpCDF.dat). Outputs in output/run_21param/:
#   final_results.json, tiktak_results.csv,
#   params_vs_guvenen.png, objective_slices.png
#
# NOTE: this is a heavy global optimization. The knobs below are a sensible
# first run, not Guvenen's full budget (900k Sobol / 2000 restarts). Scale
# N_SOBOL / KEEP_BEST up for a more thorough solve (and raise --time/--mem).
# To use synthetic targets instead (a noise-free recovery check), drop the
# `--real-moments "$DATA"` flags from the run + plot calls below.
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs (env-overridable; defaults sized for default_queue's 4h / 32 cores)
# Override per cluster via env vars -- easiest through the launcher
# code/runs/submit_full.sh, which also sets the matching --partition/--time/
# --cpus-per-task. e.g. on Bouchet 'day' (64 cores, 1 day, full workload):
#   PARTITION=day CORES=64 WALLTIME=1-00:00:00 \
#     N_SIM=25000 N_SOBOL=50000 KEEP_BEST=480 MAXITER=1500 \
#     code/runs/submit_full.sh
CORES="${CORES:-32}"              # must match --cpus-per-task (launcher keeps them in sync)
N_SIM="${N_SIM:-20000}"
N_SOBOL="${N_SOBOL:-20000}"       # Sobol screen (21-dim needs broad coverage)
KEEP_BEST="${KEEP_BEST:-96}"      # local restarts; >= CORES so stage B uses all
MAXITER="${MAXITER:-800}"         # 21-dim local searches need more iterations
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
WORKDIR="output/run_21param"
DATA="$ROOT/data"                 # real Guvenen moments in $DATA/intermediate/*.dat

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

if [ ! -f "$DATA/intermediate/var_lny.dat" ]; then
    echo "ERROR: real moments not found in $DATA/intermediate/ (need the .dat files)." >&2
    echo "Copy them there (see data/README.md) or edit DATA above." >&2
    exit 1
fi

echo
echo "Full 21-parameter solve (REAL moments): cores=$CORES, n_sim=$N_SIM, "
echo "n_sobol=$N_SOBOL, keep_best=$KEEP_BEST, maxiter=$MAXITER  ->  $WORKDIR"
echo

SECONDS=0
python code/run_tiktak.py \
    --spawn "$CORES" \
    --free all \
    --n-sim "$N_SIM" \
    --n-sobol "$N_SOBOL" \
    --keep-best "$KEEP_BEST" \
    --maxiter "$MAXITER" \
    --seed "$SEED" \
    --sobol-seed "$SOBOL_SEED" \
    --real-moments "$DATA" \
    --workdir "$WORKDIR"
echo "Solve wall time: ${SECONDS}s"

echo
echo "Producing comparison + objective-slice figures ..."
( cd code && python plot_results.py "$ROOT/$WORKDIR" --real-moments "$DATA" )

echo
echo "Done. See $WORKDIR/ : final_results.json, params_vs_guvenen.png, objective_slices.png"
