#!/bin/bash
# ---------------------------------------------------------------------------
# Launcher for a PREEMPTIBLE, MULTI-NODE run on the scavenge partition — NOT a
# batch script. Run it on the login node. It submits ONE small, stable
# coordinator job (partition `day`); that coordinator then submits + babysits a
# SLURM array of workers on `scavenge`, where any task can be preempted at any
# time. All jobs share one run directory on the cluster filesystem and
# coordinate purely through files, so the run survives workers dying or moving
# between nodes. See code/README.md ("Running on scavenge").
#
# Two-job model:
#   coordinator (day)  -> inits the run, keeps the array alive (resubmits if it
#                         drains), drives the leader-only stages, aggregates.
#   workers (scavenge) -> a SLURM array; each task spawns WCORES local workers
#                         that pull tasks, heartbeat a lease, and on preemption
#                         leave their in-flight task to be reclaimed.
#
# Defaults (16 array tasks x 8 cores = 128 scavenge cores):
#     code/runs/submit_scavenge.sh
#
# Heavier sanity re-run (n_sim=50k, 2^17 Sobol, 480 restarts):
#     N_SIM=50000 N_SOBOL=131072 KEEP_BEST=480 MAXITER=800 \
#       NWORKERS=32 WCORES=8 WMEM=48G code/runs/submit_scavenge.sh
#
# Resume a run that was interrupted (coordinator re-attaches; default behavior):
#     code/runs/submit_scavenge.sh          # FRESH=0 by default
# Force a clean restart over an existing workdir:
#     FRESH=1 code/runs/submit_scavenge.sh
#
# Extra sbatch flags for the coordinator pass through, e.g. an account:
#     code/runs/submit_scavenge.sh -A mygroup
# ---------------------------------------------------------------------------
set -eo pipefail

# ---- coordinator (stable) resources ---------------------------------------
PARTITION="${PARTITION:-day}"            # stable partition for the coordinator
COORD_CORES="${COORD_CORES:-2}"          # minimal: only POLISH does real compute
COORD_WALLTIME="${COORD_WALLTIME:-1-00:00:00}"
COORD_MEM="${COORD_MEM:-8G}"

# ---- worker array (scavenge) resources ------------------------------------
WPARTITION="${WPARTITION:-scavenge}"     # preemptible partition for the workers
NWORKERS="${NWORKERS:-16}"               # number of array tasks (nodes)
MAXPAR="${MAXPAR:-$NWORKERS}"            # max array tasks running at once
WCORES="${WCORES:-8}"                    # worker processes per array task
WWALLTIME="${WWALLTIME:-1-00:00:00}"
WMEM="${WMEM:-32G}"                      # WCORES x ~0.9 GB at n_sim=50k

# ---- workload knobs (shared) ----------------------------------------------
N_SIM="${N_SIM:-20000}"
N_SOBOL="${N_SOBOL:-20000}"
KEEP_BEST="${KEEP_BEST:-96}"
MAXITER="${MAXITER:-800}"
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
LEASE_TTL="${LEASE_TTL:-600}"
FREE="${FREE:-all}"
FRESH="${FRESH:-0}"                      # 1 -> coordinator wipes + restarts
ACCOUNT="${ACCOUNT:-}"                   # SLURM account to charge (e.g. johng); applies
                                         # to BOTH the coordinator and the worker array

# Run from the repo root so SLURM_SUBMIT_DIR (and thus ROOT) is the repo root.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

# Absolute, shared-filesystem run directory used by EVERY job.
WORKDIR="${WORKDIR:-$ROOT/output/run_scavenge}"

# Charge both jobs to a specific account if one is given (empty -> your default).
ACCT_FLAG=""
[ -n "$ACCOUNT" ] && ACCT_FLAG="--account=$ACCOUNT"

echo "Submitting preemptible scavenge run:"
echo "  coordinator: partition=$PARTITION cores=$COORD_CORES walltime=$COORD_WALLTIME mem=$COORD_MEM"
echo "  workers:     partition=$WPARTITION array=0-$((NWORKERS-1))%$MAXPAR cores/task=$WCORES walltime=$WWALLTIME mem=$WMEM"
echo "  workload:    n_sim=$N_SIM n_sobol=$N_SOBOL keep_best=$KEEP_BEST maxiter=$MAXITER lease_ttl=$LEASE_TTL fresh=$FRESH"
echo "  account:     ${ACCOUNT:-<default>}"
echo "  workdir:     $WORKDIR  (must be on a shared filesystem)"

# Everything the coordinator needs is forwarded via --export=ALL,<vars>. The
# coordinator assembles the scavenge-array sbatch command from the W* vars (no
# commas, so no SLURM --export parsing trouble) and inherits the workload knobs;
# the array tasks then inherit them again from the coordinator via --export=ALL.
exec sbatch \
    --partition="$PARTITION" \
    --cpus-per-task="$COORD_CORES" \
    --time="$COORD_WALLTIME" \
    --mem="$COORD_MEM" \
    $ACCT_FLAG \
    --export=ALL,WORKDIR="$WORKDIR",N_SIM="$N_SIM",N_SOBOL="$N_SOBOL",KEEP_BEST="$KEEP_BEST",MAXITER="$MAXITER",SEED="$SEED",SOBOL_SEED="$SOBOL_SEED",LEASE_TTL="$LEASE_TTL",FREE="$FREE",FRESH="$FRESH",ACCOUNT="$ACCOUNT",WPARTITION="$WPARTITION",NWORKERS="$NWORKERS",MAXPAR="$MAXPAR",WCORES="$WCORES",WWALLTIME="$WWALLTIME",WMEM="$WMEM" \
    "$@" \
    code/runs/hpc_coordinator.sh
