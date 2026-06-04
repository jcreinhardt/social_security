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

    # Make conda available. The conda/anaconda module is the ONLY
    # cluster-specific module we need (everything else comes from the conda
    # env). To support multiple clusters, try a list of known module names and
    # load the first that actually provides `conda`; set CONDA_MODULE to force a
    # specific one. `module purge` first drops anything the login shell
    # auto-loaded (e.g. a `Python` module) that would conflict. (Lmod keeps
    # sticky/base modules through a purge.)
    #   Bouchet: miniconda/24.11.3   |   <other cluster>: anaconda3/2023.09-0-k3at
    CONDA_MODULES="${CONDA_MODULE:-miniconda/24.11.3 anaconda3/2023.09-0-k3at miniconda anaconda3 anaconda}"
    if command -v module >/dev/null 2>&1; then
        module purge 2>/dev/null || true
        for _m in $CONDA_MODULES; do
            if module load "$_m" 2>/dev/null && command -v conda >/dev/null 2>&1; then
                echo "Loaded conda module: $_m"
                break
            fi
        done
    fi
    if command -v conda >/dev/null 2>&1; then
        # Disable `nounset` for conda: its activate/deactivate hooks (e.g. the
        # gcc_linux-64 compiler package's deactivate.d) reference unbound vars
        # and abort activation under `set -u`. We must `set +u` explicitly here
        # because the shell may have inherited -u from the login shell/.bashrc
        # (a script-level `set -eo pipefail` does not clear an inherited -u).
        set +u
        source "$(conda info --base)/etc/profile.d/conda.sh"
        if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
            echo "Creating conda env '$ENV_NAME' from environment.yml ..."
            conda env create -f environment.yml -n "$ENV_NAME"
        fi
        conda activate "$ENV_NAME"
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
    ( cd code/algorithm && python -c "from msm_model import simulate_income, calculate_moments, THETA_TRUE; calculate_moments(simulate_income(THETA_TRUE, 1000, 36, 42)); print('numba kernels compiled')" )
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
    ( cd code/benchmarking && python scaling_report.py "$ROOT/$OUTDIR" )
    echo
    echo "Done. See $OUTDIR/scaling_summary.csv and the per-core logs."
}
