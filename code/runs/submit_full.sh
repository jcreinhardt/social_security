#!/bin/bash
# ---------------------------------------------------------------------------
# Launcher for the full 21-parameter run — NOT a batch script. Run it on the
# login node; it translates env vars into the matching `sbatch` flags so the
# scheduler resources (partition / walltime / cores) AND the workload knobs all
# come from one place, and stay in sync. Switching clusters needs no edits.
#
# Defaults target the small cluster's default_queue (32 cores, 4h, trimmed):
#     code/runs/submit_full.sh
#
# Bouchet 'day' (64-core nodes, 1-day limit, full workload):
#     PARTITION=day CORES=64 WALLTIME=1-00:00:00 \
#       N_SIM=25000 N_SOBOL=50000 KEEP_BEST=480 MAXITER=1500 \
#       code/runs/submit_full.sh
#
# Extra sbatch flags pass through, e.g. an account:
#     PARTITION=day CORES=64 WALLTIME=1-00:00:00 code/runs/submit_full.sh -A mygroup
# ---------------------------------------------------------------------------
set -eo pipefail

PARTITION="${PARTITION:-default_queue}"
CORES="${CORES:-32}"
WALLTIME="${WALLTIME:-04:00:00}"
MEM="${MEM:-48G}"
N_SIM="${N_SIM:-20000}"
N_SOBOL="${N_SOBOL:-20000}"
KEEP_BEST="${KEEP_BEST:-96}"
MAXITER="${MAXITER:-800}"
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"

# Run from the repo root so SLURM_SUBMIT_DIR (and thus the run's ROOT) is the
# repo root regardless of where this launcher was invoked.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

echo "Submitting full 21-param run:"
echo "  partition=$PARTITION  cores=$CORES  walltime=$WALLTIME  mem=$MEM"
echo "  n_sim=$N_SIM n_sobol=$N_SOBOL keep_best=$KEEP_BEST maxiter=$MAXITER"

exec sbatch \
    --partition="$PARTITION" \
    --cpus-per-task="$CORES" \
    --time="$WALLTIME" \
    --mem="$MEM" \
    --export=ALL,CORES="$CORES",N_SIM="$N_SIM",N_SOBOL="$N_SOBOL",KEEP_BEST="$KEEP_BEST",MAXITER="$MAXITER",SEED="$SEED",SOBOL_SEED="$SOBOL_SEED" \
    "$@" \
    code/runs/hpc_full_21param.sh
