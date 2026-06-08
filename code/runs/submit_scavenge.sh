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
# Defaults (128 array tasks x 4 cores = 512 scavenge cores, 1h tasks; reduced-
# Guvenen workload n_sim=100k, 2^16 Sobol, 1000 restarts). Small short tasks
# schedule easily on scavenge -- a node free for an hour can take one -- and the
# coordinator resubmits the array as tasks expire, so progress accumulates:
#     ACCOUNT=pi_johng code/runs/submit_scavenge.sh
#
# Useful-core ceiling is KEEP_BEST (the local-search restarts): the Sobol screen
# parallelizes over N_SOBOL points but is short, while the local stage has only
# KEEP_BEST independent restarts, so >KEEP_BEST cores idle during it.
#
# Lighter smoke-test of the 1h/requeue/resubmit loop (one 4-core worker):
#     NWORKERS=1 code/runs/submit_scavenge.sh
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
NWORKERS="${NWORKERS:-128}"              # number of array tasks (nodes)
MAXPAR="${MAXPAR:-$NWORKERS}"            # max array tasks running at once
WCORES="${WCORES:-4}"                    # worker processes per array task
WWALLTIME="${WWALLTIME:-1:00:00}"        # short tasks -> easy to schedule on scavenge
WMEM="${WMEM:-12G}"                      # WCORES x ~2 GB at n_sim=100k

# ---- workload knobs (shared) ----------------------------------------------
N_SIM="${N_SIM:-100000}"                  # full fidelity (the final POLISH + reported estimate)
# Multi-fidelity: the Sobol screen + local restarts run at this cheaper n_sim
# (they only need to rank/explore basins); the polish runs at the full N_SIM.
# At ~30k an eval is ~3x cheaper than at 100k, so restarts fit a 1h worker with
# a useful MAXITER. Set =N_SIM (or 0) to disable.
N_SIM_SCREEN="${N_SIM_SCREEN:-30000}"
N_SOBOL="${N_SOBOL:-65536}"
KEEP_BEST="${KEEP_BEST:-1000}"
# Per-restart budget for the LOCAL_SEARCH stage. Must be small enough that one
# 21-dim Powell restart finishes well inside a worker's WWALLTIME. At the screen
# n_sim=30k an eval is ~0.3s and a restart is ~100s of evals/maxiter, so
# MAXITER=50 is ~25min (fits 1h). The POLISH does the final accurate
# convergence at full N_SIM, so coarse restarts here are by design.
MAXITER="${MAXITER:-50}"
# Budget for the final POLISH local search. Runs on the stable coordinator,
# but still at full n_sim, so it is NOT free: at n_sim=100k, ~250 is a few hours
# (fits the 1-day coordinator); 1000 would be tens of hours and never finish.
MAXITER_POLISH="${MAXITER_POLISH:-250}"
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

# Absolute, shared-filesystem run directory used by EVERY job. A fresh name
# (vs a prior run with different N_SOBOL/KEEP_BEST) avoids re-attaching to stale
# init state and the slow wipe of the old dir's many small files.
WORKDIR="${WORKDIR:-$ROOT/output/run_scavenge_4c}"

# Charge both jobs to a specific account if one is given (empty -> your default).
ACCT_FLAG=""
[ -n "$ACCOUNT" ] && ACCT_FLAG="--account=$ACCOUNT"

echo "Submitting preemptible scavenge run:"
echo "  coordinator: partition=$PARTITION cores=$COORD_CORES walltime=$COORD_WALLTIME mem=$COORD_MEM"
echo "  workers:     partition=$WPARTITION array=0-$((NWORKERS-1))%$MAXPAR cores/task=$WCORES walltime=$WWALLTIME mem=$WMEM"
echo "  workload:    n_sim=$N_SIM screen=$N_SIM_SCREEN n_sobol=$N_SOBOL keep_best=$KEEP_BEST maxiter=$MAXITER polish=$MAXITER_POLISH lease_ttl=$LEASE_TTL fresh=$FRESH"
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
    --export=ALL,WORKDIR="$WORKDIR",N_SIM="$N_SIM",N_SIM_SCREEN="$N_SIM_SCREEN",N_SOBOL="$N_SOBOL",KEEP_BEST="$KEEP_BEST",MAXITER="$MAXITER",MAXITER_POLISH="$MAXITER_POLISH",SEED="$SEED",SOBOL_SEED="$SOBOL_SEED",LEASE_TTL="$LEASE_TTL",FREE="$FREE",FRESH="$FRESH",ACCOUNT="$ACCOUNT",WPARTITION="$WPARTITION",NWORKERS="$NWORKERS",MAXPAR="$MAXPAR",WCORES="$WCORES",WWALLTIME="$WWALLTIME",WMEM="$WMEM" \
    "$@" \
    code/runs/hpc_coordinator.sh
