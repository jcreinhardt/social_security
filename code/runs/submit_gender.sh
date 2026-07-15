#!/bin/bash
# ---------------------------------------------------------------------------
# Launcher for the single-sex 21-parameter runs — NOT a batch script. Run it on
# the login node; it submits TWO independent jobs (men + women), each a full
# node, each a fast ~15-20 min first-pass solve. It translates env vars into the
# matching `sbatch` flags so scheduler resources and workload knobs stay in sync.
#
# Default (Bouchet 'day', 48 cores/node, ~15-20 min, both sexes):
#     code/runs/submit_gender.sh
#
# Bigger nodes / longer budget:
#     CORES=64 WALLTIME=01:00:00 N_SOBOL=40000 KEEP_BEST=128 MAXITER_POLISH=200 \
#       code/runs/submit_gender.sh
#
# One sex only:        SEXES=women code/runs/submit_gender.sh
# Extra sbatch flags pass through (e.g. an account):  code/runs/submit_gender.sh -A mygroup
#
# PREREQ: targets must be present under data/ on the cluster — either the frozen
# caches data/gender_targets/{men,women}.npz (run `python
# code/freeze_gender_targets.py` locally, then sync data/gender_targets/), or
# the data/GKOS_2016_moments_{men,women}.xlsx workbooks (+ openpyxl in the env).
# ---------------------------------------------------------------------------
set -eo pipefail

PARTITION="${PARTITION:-day}"
CORES="${CORES:-48}"
WALLTIME="${WALLTIME:-00:30:00}"
MEM="${MEM:-48G}"
N_SIM="${N_SIM:-25000}"
N_SOBOL="${N_SOBOL:-8000}"
KEEP_BEST="${KEEP_BEST:-48}"
MAXITER="${MAXITER:-60}"
MAXITER_POLISH="${MAXITER_POLISH:-80}"
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
SEXES="${SEXES:-men women}"

# Run from the repo root so SLURM_SUBMIT_DIR (the run's ROOT) is the repo root.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

echo "Submitting single-sex 21-param runs for: $SEXES"
echo "  partition=$PARTITION cores=$CORES walltime=$WALLTIME mem=$MEM"
echo "  n_sim=$N_SIM n_sobol=$N_SOBOL keep_best=$KEEP_BEST maxiter=$MAXITER maxiter_polish=$MAXITER_POLISH"

for SEX in $SEXES; do
    echo
    echo ">> submitting $SEX"
    sbatch \
        --job-name="tiktak_gender_${SEX}" \
        --partition="$PARTITION" \
        --cpus-per-task="$CORES" \
        --time="$WALLTIME" \
        --mem="$MEM" \
        --export=ALL,GENDER="$SEX",CORES="$CORES",N_SIM="$N_SIM",N_SOBOL="$N_SOBOL",KEEP_BEST="$KEEP_BEST",MAXITER="$MAXITER",MAXITER_POLISH="$MAXITER_POLISH",SEED="$SEED",SOBOL_SEED="$SOBOL_SEED" \
        "$@" \
        code/runs/hpc_gender_21param.sh
done

echo
echo "Submitted. Monitor live (per sex):"
for SEX in $SEXES; do
    echo "  python code/monitor.py output/run_gender_${SEX}"
done
echo "When both finish:  python code/compare_gender_estimates.py"
