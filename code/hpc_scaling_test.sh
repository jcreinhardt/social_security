#!/bin/bash
#SBATCH --job-name=tiktak_scaling
#SBATCH --nodes=1                 # single node: this is an intra-node scaling test
#SBATCH --ntasks=1                # one launcher task; it spawns the workers itself
#SBATCH --cpus-per-task=60        # >= max core count tested below; match your node
#SBATCH --exclusive               # own the whole node for clean timings
#SBATCH --time=00:30:00
#SBATCH --mem=128G
#SBATCH --output=tiktak_scaling_%j.out
# ---------------------------------------------------------------------------
# Self-contained intra-node scaling + accuracy test for the 2-parameter TikTak
# MSM problem. Copy the repo (code/ + data/ + environment.yml) to the HPC, then:
#
#     sbatch code/hpc_scaling_test.sh
#
# It runs the SAME problem at several core counts on ONE node, times each run,
# and produces output/scaling/scaling_summary.csv comparing speed + accuracy.
# Nothing here hard-codes a local path; everything is relative to the submit dir.
# ---------------------------------------------------------------------------
set -euo pipefail

# ---- knobs -----------------------------------------------------------------
CORES_LIST=(12 24 36 48 60)       # core counts to test (intra-node)
N_SIM=25000                       # simulated individuals per objective eval
N_SOBOL=8192                      # Sobol screening points (stage A)
KEEP_BEST=120                     # local restarts (stage B); keep >= max cores
MAXITER=600                       # local-optimizer iterations per restart
SEED=42
SOBOL_SEED=999
ENV_NAME="${ENV_NAME:-socsec_mac}"   # override: `ENV_NAME=foo sbatch ...`

# ---- locate the repo root (works under SLURM or a plain shell) -------------
ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
cd "$ROOT"
echo "Repo root: $ROOT"
echo "Node: $(hostname)   logical CPUs: $(nproc)"
mkdir -p output/scaling

# ---- environment -----------------------------------------------------------
# Make conda available. On Yale's Bouchet cluster that's the miniconda module
# (`module spider conda` -> miniconda/{23.5.2,24.7.1,24.11.3}). Change this line
# for a different cluster (e.g. `module load anaconda3`), or drop it if conda is
# already on PATH.
if command -v module >/dev/null 2>&1; then
    module load miniconda/24.11.3
fi
if command -v conda >/dev/null 2>&1; then
    set +u   # conda's shell hook references unbound vars under `set -u`
    source "$(conda info --base)/etc/profile.d/conda.sh"
    if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
        echo "Creating conda env '$ENV_NAME' from environment.yml ..."
        conda env create -f environment.yml -n "$ENV_NAME"
    fi
    conda activate "$ENV_NAME"
    set -u
else
    echo "ERROR: conda not found. Load it via 'module load' or install miniconda." >&2
    exit 1
fi
echo "Python: $(which python)"
python -c "import numpy, scipy, numba; print('numpy', numpy.__version__, '| scipy', scipy.__version__, '| numba', numba.__version__)"

# ---- thread pinning: one BLAS thread per worker process --------------------
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
# Shared, writable numba cache so workers load compiled kernels instead of each
# recompiling (and so the cache survives across configs).
export NUMBA_CACHE_DIR="$ROOT/output/numba_cache"
mkdir -p "$NUMBA_CACHE_DIR"

# ---- warm up the numba cache once, before any timed run --------------------
# This compiles the @njit kernels a single time so the first (12-core) config
# isn't penalised by JIT compilation during its timing.
echo "Warming up numba cache ..."
( cd code && python -c "from msm_model import simulate_income, calculate_moments, THETA_TRUE; calculate_moments(simulate_income(THETA_TRUE, 1000, 36, 42)); print('numba kernels compiled')" )

# ---- scaling loop ----------------------------------------------------------
echo
echo "Workload: n_sim=$N_SIM, n_sobol=$N_SOBOL, keep_best=$KEEP_BEST, maxiter=$MAXITER"
echo "Core counts: ${CORES_LIST[*]}"
echo

for N in "${CORES_LIST[@]}"; do
    WORKDIR="output/scaling/cores_${N}"
    LOG="output/scaling/cores_${N}.log"
    echo "================  $N cores  ================"
    SECONDS=0
    python code/run_tiktak.py \
        --spawn "$N" \
        --n-sim "$N_SIM" \
        --n-sobol "$N_SOBOL" \
        --keep-best "$KEEP_BEST" \
        --maxiter "$MAXITER" \
        --seed "$SEED" \
        --sobol-seed "$SOBOL_SEED" \
        --workdir "$WORKDIR" \
        > "$LOG" 2>&1
    WALL=$SECONDS
    echo "$WALL" > "$WORKDIR/wall_seconds.txt"
    echo "  $N cores -> ${WALL}s   (full log: $LOG)"
    tail -n 6 "$LOG" | sed 's/^/    /'
    echo
done

# ---- comparison report -----------------------------------------------------
echo "Building scaling report ..."
( cd code && python scaling_report.py "$ROOT/output/scaling" )
echo
echo "Done. See output/scaling/scaling_summary.csv and the per-core logs."
