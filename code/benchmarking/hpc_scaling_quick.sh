#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_quick
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12        # small request -> schedules fast (backfill)
#SBATCH --time=00:30:00           # generous: first run may build the conda env
#SBATCH --mem=16G
#SBATCH --output=tiktak_quick_%j.out
# Optional: many clusters have a short/debug partition that schedules sooner.
# #SBATCH --partition=devel
# ---------------------------------------------------------------------------
# FAST sanity version of hpc_scaling_test.sh: a tiny workload at small core
# counts. Use it to confirm the whole pipeline works on the cluster (module +
# conda env + numba + file coordination + report) without waiting for a big
# job to schedule. It is NOT a precise scaling benchmark -- it does not request
# the node exclusively, so timings are noisy; it just verifies correctness and
# that speed improves with cores. Run the full hpc_scaling_test.sh for real
# numbers.
#
#     sbatch code/benchmarking/hpc_scaling_quick.sh
#
# Results land in output/scaling_quick/ (separate from the full run's
# output/scaling/). Shared body: _scaling_lib.sh.
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs (tiny) ----------------------------------------------------------
CORES_LIST=(2 4 8 12)             # small counts; keep <= --cpus-per-task above
N_SIM=5000                        # fewer individuals -> fast objective evals
N_SOBOL=512                       # small Sobol screen
KEEP_BEST=24                      # local restarts; keep >= max core count (12)
MAXITER=200
SEED=42
SOBOL_SEED=999
OUTDIR="output/scaling_quick"

source "$ROOT/code/benchmarking/_scaling_lib.sh"
run_scaling_test
