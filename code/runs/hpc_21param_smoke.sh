#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_21smoke
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4         # tiny request -> schedules fast (backfill)
#SBATCH --time=00:15:00
#SBATCH --mem=8G
#SBATCH --output=tiktak_21smoke_%j.out
# Optional: a short/debug partition schedules even sooner, if your cluster has one.
# #SBATCH --partition=devel
# ---------------------------------------------------------------------------
# MINI smoke test of the full 21-parameter run: confirms the pipeline starts on
# the cluster and writes output, using a handful of points on 4 cores. Fits the
# REAL Guvenen moments (data/intermediate/*.dat) -- same path as the full run --
# so it also catches a missing/misplaced data dir. NOT an estimate; the workload
# is far too small to recover anything. Use it to verify env + module + numba +
# file coordination + data loading + result writing before committing real
# compute to runs/hpc_full_21param.sh.
#
#     sbatch code/runs/hpc_21param_smoke.sh
#
# Should finish in ~2-3 min. On success, output/run_21param_smoke/ contains:
#   final_results.json, tiktak_results.csv, run_meta.json,
#   params_vs_guvenen.png, objective_slices.png
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs (deliberately tiny) ---------------------------------------------
CORES=4
N_SIM=2000
N_SOBOL=128
KEEP_BEST=8
MAXITER=100
SEED=42
SOBOL_SEED=999
WORKDIR="output/run_21param_smoke"
DATA="$ROOT/data"                 # real Guvenen moments in $DATA/intermediate/*.dat

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

if [ ! -f "$DATA/intermediate/var_lny.dat" ]; then
    echo "ERROR: real moments not found in $DATA/intermediate/ (need the .dat files)." >&2
    echo "Copy them there (see data/README.md) or edit DATA above." >&2
    exit 1
fi

echo
echo "21-param SMOKE test (REAL moments): cores=$CORES, n_sim=$N_SIM, "
echo "n_sobol=$N_SOBOL, keep_best=$KEEP_BEST, maxiter=$MAXITER  ->  $WORKDIR"
echo

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

echo
echo "Producing figures (also exercises plot_results) ..."
( cd code && python plot_results.py "$ROOT/$WORKDIR" --real-moments "$DATA" )

# ---- confirm it actually wrote the key artifact ----------------------------
echo
if [ -f "$ROOT/$WORKDIR/final_results.json" ]; then
    echo "SMOKE TEST PASSED: wrote $WORKDIR/final_results.json"
    ls -1 "$ROOT/$WORKDIR" | sed 's/^/  /'
else
    echo "SMOKE TEST FAILED: no final_results.json in $WORKDIR" >&2
    exit 1
fi
