#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_scav
#SBATCH --nodes=1
#SBATCH --ntasks=1                # one launcher task per array element; it spawns workers
#SBATCH --cpus-per-task=8         # worker processes per array task (override via sbatch flag)
#SBATCH --partition=scavenge      # PREEMPTIBLE: tasks can be killed at any time
#SBATCH --time=1-00:00:00
#SBATCH --mem=32G
#SBATCH --requeue                 # SLURM re-runs a preempted task; it rejoins the run
#SBATCH --signal=B:TERM@90        # SIGTERM 90s before kill -> graceful, low-waste exit
#SBATCH --output=tiktak_scav_%A_%a.out
# ---------------------------------------------------------------------------
# One element of the preemptible worker array. Each task spawns WCORES local
# TikTak workers (role=worker) that join the shared run at $WORKDIR: they pull
# Sobol points / local restarts, heartbeat a per-task lease, and -- if preempted
# -- leave their in-flight task to be reclaimed by a survivor (or by this task
# when SLURM requeues it). These tasks never wipe the workdir, never elect the
# leader, and never aggregate; the stable coordinator owns all of that.
#
# Not submitted directly -- the coordinator (hpc_coordinator.sh) submits and
# resubmits this array via $WORKER_SUBMIT_CMD, forwarding $WORKDIR + the
# workload knobs through --export=ALL.
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs (inherited from the coordinator via --export=ALL) ---------------
WORKDIR="${WORKDIR:-$ROOT/output/run_scavenge}"
N_SIM="${N_SIM:-20000}"
N_SOBOL="${N_SOBOL:-20000}"
KEEP_BEST="${KEEP_BEST:-96}"
N_SIM_SCREEN="${N_SIM_SCREEN:-0}"        # multi-fidelity screen n_sim (0 = off)
MAXITER="${MAXITER:-50}"                 # per-restart budget; must fit the worker walltime
MAXITER_POLISH="${MAXITER_POLISH:-250}" # forwarded for cfg consistency (polish runs on coordinator)
SEED="${SEED:-42}"
SOBOL_SEED="${SOBOL_SEED:-999}"
LEASE_TTL="${LEASE_TTL:-600}"
FREE="${FREE:-all}"
DATA="${DATA:-$ROOT/data}"
WCORES="${SLURM_CPUS_PER_TASK:-8}"
ATASK="${SLURM_ARRAY_TASK_ID:-0}"

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

echo
echo "Scavenge worker array task $ATASK: $WCORES workers -> $WORKDIR"
echo "  (node $(hostname); offset $((ATASK * WCORES)); lease_ttl=$LEASE_TTL)"
echo

# Run the spawn-parent in the background and forward SLURM's preemption SIGTERM
# to it (which re-forwards to the worker children). Then `wait` so the trap can
# fire while the job is running.
python code/run_tiktak.py \
    --spawn "$WCORES" \
    --role worker \
    --worker-id-offset "$((ATASK * WCORES))" \
    --free "$FREE" \
    --n-sim "$N_SIM" \
    --n-sim-screen "$N_SIM_SCREEN" \
    --n-sobol "$N_SOBOL" \
    --keep-best "$KEEP_BEST" \
    --maxiter "$MAXITER" \
    --maxiter-polish "$MAXITER_POLISH" \
    --seed "$SEED" \
    --sobol-seed "$SOBOL_SEED" \
    --lease-ttl "$LEASE_TTL" \
    --real-moments "$DATA" \
    --workdir "$WORKDIR" &
PYPID=$!
trap 'kill -TERM "$PYPID" 2>/dev/null || true' TERM USR1
wait "$PYPID"
