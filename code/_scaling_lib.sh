# shellcheck shell=bash
# ---------------------------------------------------------------------------
# Shared logic for the TikTak intra-node scaling tests, sourced by
# hpc_scaling_test.sh (full) and hpc_scaling_quick.sh (fast sanity run).
#
# The caller must define, before sourcing + calling run_scaling_test:
#   ROOT        repo root (e.g. ${SLURM_SUBMIT_DIR:-$(pwd)})
#   ENV_NAME    conda env name
#   CORES_LIST  bash array of core counts, e.g. (12 24 36 48 60)
#   N_SIM N_SOBOL KEEP_BEST MAXITER SEED SOBOL_SEED   workload knobs
#   OUTDIR      results dir relative to ROOT (e.g. output/scaling)
# ---------------------------------------------------------------------------

# Activate the conda env, pin BLAS threads, and warm the numba cache. Shared by
# the scaling sweep and the full 21-param run, so env fixes live in one place.
# Requires: ROOT, ENV_NAME.
setup_env() {
    cd "$ROOT"
    echo "Repo root: $ROOT"
    echo "Node: $(hostname)   logical CPUs: $(nproc)"

    # Make conda available. On Yale's Bouchet cluster that's the miniconda
    # module; change/remove this for a different cluster.
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

    # One BLAS thread per worker process.
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1
    export NUMEXPR_NUM_THREADS=1
    # Shared, writable numba cache so workers load compiled kernels rather than
    # each recompiling, and warm it once before any timed/parallel run.
    export NUMBA_CACHE_DIR="$ROOT/output/numba_cache"
    mkdir -p "$NUMBA_CACHE_DIR"
    echo "Warming up numba cache ..."
    ( cd code && python -c "from msm_model import simulate_income, calculate_moments, THETA_TRUE; calculate_moments(simulate_income(THETA_TRUE, 1000, 36, 42)); print('numba kernels compiled')" )
}

run_scaling_test() {
    mkdir -p "$OUTDIR"
    setup_env

    # ---- scaling loop ------------------------------------------------------
    echo
    echo "Workload: n_sim=$N_SIM, n_sobol=$N_SOBOL, keep_best=$KEEP_BEST, maxiter=$MAXITER"
    echo "Core counts: ${CORES_LIST[*]}   ->  $OUTDIR"
    echo

    for N in "${CORES_LIST[@]}"; do
        WORKDIR="$OUTDIR/cores_${N}"
        LOG="$OUTDIR/cores_${N}.log"
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

    # ---- comparison report -------------------------------------------------
    echo "Building scaling report ..."
    ( cd code && python scaling_report.py "$ROOT/$OUTDIR" )
    echo
    echo "Done. See $OUTDIR/scaling_summary.csv and the per-core logs."
}
