#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_coord
#SBATCH --nodes=1
#SBATCH --ntasks=1                # one stable process: init + babysit + aggregate
#SBATCH --cpus-per-task=2         # minimal; only the final POLISH does real compute
#SBATCH --partition=day          # STABLE partition (not preemptible)
#SBATCH --time=1-00:00:00
#SBATCH --mem=8G
#SBATCH --requeue                 # resume (re-attach to the workdir) if preempted
#SBATCH --output=tiktak_coord_%j.out
# ---------------------------------------------------------------------------
# Stable coordinator for a preemptible scavenge run. It (1) initializes the run
# (draws the Sobol set, writes run_meta), (2) submits + babysits the scavenge
# worker array (resubmitting it if it fully drains), (3) drives the leader-only
# stage transitions so the run progresses even when every scavenge worker is
# preempted, and (4) aggregates into final_results.json at the end. Because it
# lives on a stable partition (and is --requeue-able) the run always completes.
#
# Submit via the launcher, which sets all the env vars:  code/runs/submit_scavenge.sh
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs (forwarded by the launcher; safe defaults if run by hand) -------
WORKDIR="${WORKDIR:-$ROOT/output/run_scavenge}"
N_SIM="${N_SIM:-20000}"
N_SOBOL="${N_SOBOL:-20000}"
KEEP_BEST="${KEEP_BEST:-96}"
MAXITER="${MAXITER:-20}"                 # per-restart budget (see submit_scavenge.sh)
MAXITER_POLISH="${MAXITER_POLISH:-250}" # final polish budget (runs here, full n_sim ~ a few hours)
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
LEASE_TTL="${LEASE_TTL:-600}"
FREE="${FREE:-all}"
FRESH="${FRESH:-0}"
DATA="${DATA:-$ROOT/data}"        # real Guvenen moments in $DATA/intermediate/*.dat

# ---- scavenge worker array (resources only; workload knobs inherited) ------
WPARTITION="${WPARTITION:-scavenge}"
NWORKERS="${NWORKERS:-16}"
MAXPAR="${MAXPAR:-$NWORKERS}"
WCORES="${WCORES:-8}"
WWALLTIME="${WWALLTIME:-1-00:00:00}"
WMEM="${WMEM:-32G}"
ACCOUNT="${ACCOUNT:-}"             # SLURM account to charge the worker array to

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

if [ ! -f "$DATA/intermediate/var_lny.dat" ]; then
    echo "ERROR: real moments not found in $DATA/intermediate/ (need the .dat files)." >&2
    exit 1
fi

# The command the coordinator runs to (re)submit the scavenge worker array.
# --export=ALL propagates THIS job's environment (WORKDIR + all workload knobs)
# to the array tasks, so the worker script reads them straight from its env.
# No commas in this string -> no SLURM --export parsing trouble. Charge the array
# to the same account as the coordinator (so the whole run bills one budget).
ACCT_FLAG=""
[ -n "$ACCOUNT" ] && ACCT_FLAG="--account=$ACCOUNT "
export WORKER_SUBMIT_CMD="sbatch --parsable --partition=$WPARTITION --nodes=1 --ntasks=1 --cpus-per-task=$WCORES --array=0-$((NWORKERS-1))%$MAXPAR --time=$WWALLTIME --mem=$WMEM --requeue --signal=B:TERM@90 ${ACCT_FLAG}--export=ALL $ROOT/code/runs/hpc_workers_scavenge.sh"

FRESH_FLAG=""
[ "$FRESH" = "1" ] && FRESH_FLAG="--fresh"

echo
echo "Coordinator: workdir=$WORKDIR  free=$FREE  n_sim=$N_SIM n_sobol=$N_SOBOL"
echo "  keep_best=$KEEP_BEST maxiter=$MAXITER polish=$MAXITER_POLISH lease_ttl=$LEASE_TTL fresh=$FRESH"
echo "  worker array: $NWORKERS x $WCORES cores on $WPARTITION"
echo

python code/run_tiktak.py \
    --role coordinator \
    $FRESH_FLAG \
    --free "$FREE" \
    --n-sim "$N_SIM" \
    --n-sobol "$N_SOBOL" \
    --keep-best "$KEEP_BEST" \
    --maxiter "$MAXITER" \
    --maxiter-polish "$MAXITER_POLISH" \
    --seed "$SEED" \
    --sobol-seed "$SOBOL_SEED" \
    --lease-ttl "$LEASE_TTL" \
    --real-moments "$DATA" \
    --workdir "$WORKDIR"

echo
echo "Producing comparison + objective-slice figures ..."
( cd code && python plot_results.py "$WORKDIR" --real-moments "$DATA" )

echo
echo "Done. See $WORKDIR/ : final_results.json, params_vs_guvenen.png, objective_slices.png"
