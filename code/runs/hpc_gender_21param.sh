#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_gender
#SBATCH --nodes=1
#SBATCH --ntasks=1                # one launcher task; it spawns the workers
#SBATCH --cpus-per-task=48        # launcher keeps this in sync with $CORES
#SBATCH --exclusive
#SBATCH --partition=day
#SBATCH --time=00:30:00           # fast first-pass workload (~15-20 min) + margin
#SBATCH --mem=48G
#SBATCH --output=tiktak_gender_%j.out
# ---------------------------------------------------------------------------
# Single-SEX 21-parameter Guvenen income-process estimation, fitting the GKOS
# 2016 workbook moments for one sex plus the PUF-built employment CDF:
#   SdSkewKurt_L1 + SdSkewKurt_L5 + repagent impulse + incgrwth + EmpCDF
#   (only var_lny is dropped -- absent for women).  See code/GENDER_MOMENTS.md.
#
# Submit BOTH sexes with the launcher (recommended):
#     code/runs/submit_gender.sh
# or one sex directly:
#     GENDER=women sbatch code/runs/hpc_gender_21param.sh
#
# Targets are read from the frozen numpy cache data/gender_targets/<sex>.npz
# (produced locally by `python code/freeze_gender_targets.py`); if absent it
# falls back to collapsing data/GKOS_2016_moments_<sex>.xlsx directly (needs
# openpyxl). Either the cache OR the .xlsx must be present under $DATA.
#
# Output in output/run_gender_<sex>/: final_results.json, tiktak_results.csv.
# Monitor live:  python code/monitor.py output/run_gender_<sex>
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"
GENDER="${GENDER:?set GENDER=men or GENDER=women}"

# ---- knobs (env-overridable; defaults sized for a fast ~15-20 min first pass on
# a 48-core node -- scale N_SIM/N_SOBOL/KEEP_BEST up (and WALLTIME) for a fuller
# global search once the pipeline is confirmed).
# The final POLISH local search runs on a single worker and is the wall-clock
# long pole, so MAXITER_POLISH (not core count) caps the run length; size it and
# WALLTIME together. Restarts + Sobol parallelize across $CORES.
CORES="${CORES:-48}"              # must match --cpus-per-task (launcher syncs)
N_SIM="${N_SIM:-25000}"
N_SOBOL="${N_SOBOL:-8000}"        # Sobol screen (21-dim needs broad coverage)
KEEP_BEST="${KEEP_BEST:-48}"      # local restarts; >= CORES so a wave uses all cores
MAXITER="${MAXITER:-60}"          # per-restart local-search cap
MAXITER_POLISH="${MAXITER_POLISH:-80}"   # final single-worker polish cap
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
WORKDIR="output/run_gender_${GENDER}"
DATA="$ROOT/data"

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

if [ ! -f "$DATA/gender_targets/${GENDER}.npz" ] \
   && [ ! -f "$DATA/GKOS_2016_moments_${GENDER}.xlsx" ]; then
    echo "ERROR: no targets for '$GENDER' under $DATA." >&2
    echo "  expected $DATA/gender_targets/${GENDER}.npz (run code/freeze_gender_targets.py" >&2
    echo "  locally and sync it) OR $DATA/GKOS_2016_moments_${GENDER}.xlsx (+ openpyxl)." >&2
    exit 1
fi

echo
echo "Single-sex solve [$GENDER] (GKOS workbook moments, common subset):"
echo "  cores=$CORES n_sim=$N_SIM n_sobol=$N_SOBOL keep_best=$KEEP_BEST"
echo "  maxiter=$MAXITER maxiter_polish=$MAXITER_POLISH  ->  $WORKDIR"
echo

SECONDS=0
python code/run_tiktak.py \
    --spawn "$CORES" \
    --free all \
    --gender "$GENDER" \
    --gender-data "$DATA" \
    --n-sim "$N_SIM" \
    --n-sobol "$N_SOBOL" \
    --keep-best "$KEEP_BEST" \
    --maxiter "$MAXITER" \
    --maxiter-polish "$MAXITER_POLISH" \
    --seed "$SEED" \
    --sobol-seed "$SOBOL_SEED" \
    --workdir "$WORKDIR"
echo "Solve wall time: ${SECONDS}s"
echo
echo "Done. See $WORKDIR/final_results.json"
echo "Compare both sexes vs Guvenen:  python code/compare_gender_estimates.py"
