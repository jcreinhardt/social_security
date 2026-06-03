#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_21param
#SBATCH --nodes=1
#SBATCH --ntasks=1                # one launcher task; it spawns the workers
#SBATCH --cpus-per-task=64        # match to a node with >= this many cores
#SBATCH --exclusive
#SBATCH --time=06:00:00           # the full 21-param solve is heavy; adjust
#SBATCH --mem=48G                 # ~64 workers x ~0.45 GB at n_sim=25000 (mem_benchmark.py)
#SBATCH --output=tiktak_21param_%j.out
# ---------------------------------------------------------------------------
# Full 21-parameter Guvenen income-process estimation on one node with 64
# cores, against SYNTHETIC targets (moments at the Guvenen values), so the
# known answer for every parameter is its Guvenen value. After the solve it
# produces two figures comparing the found minimum to the Guvenen values and
# showing a slice of the objective along each parameter.
#
#     sbatch code/runs/hpc_full_21param.sh
#
# Outputs in output/run_21param/:
#   final_results.json, tiktak_results.csv,
#   params_vs_guvenen.png, objective_slices.png
#
# NOTE: this is a heavy global optimization. The knobs below are a sensible
# first run, not Guvenen's full budget (900k Sobol / 2000 restarts). Scale
# N_SOBOL / KEEP_BEST up for a more thorough solve (and raise --time/--mem).
# To fit real PSID moments instead of synthetic, drop the .dat files into
# ../data/intermediate and add `--real-moments "$ROOT/data"` to the run + plot.
# ---------------------------------------------------------------------------
set -eo pipefail   # not -u: conda's activate/deactivate hooks use unbound vars

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs -----------------------------------------------------------------
CORES=64
N_SIM=25000
N_SOBOL=50000                     # Sobol screen (21-dim needs broad coverage)
KEEP_BEST=480                     # local restarts; >= CORES so stage B uses all
MAXITER=1500                      # 21-dim local searches need more iterations
SEED=42
SOBOL_SEED=999
WORKDIR="output/run_21param"

source "$ROOT/code/benchmarking/_scaling_lib.sh"
setup_env

echo
echo "Full 21-parameter solve: cores=$CORES, n_sim=$N_SIM, n_sobol=$N_SOBOL, "
echo "keep_best=$KEEP_BEST, maxiter=$MAXITER  ->  $WORKDIR"
echo

SECONDS=0
python code/run_tiktak.py \
    --spawn "$CORES" \
    --free all \
    --n-sim "$N_SIM" \
    --n-sobol "$N_SOBOL" \
    --keep-best "$KEEP_BEST" \
    --maxiter "$MAXITER" \
    --seed "$SEED" \
    --sobol-seed "$SOBOL_SEED" \
    --workdir "$WORKDIR"
echo "Solve wall time: ${SECONDS}s"

echo
echo "Producing comparison + objective-slice figures ..."
( cd code && python plot_results.py "$ROOT/$WORKDIR" )

echo
echo "Done. See $WORKDIR/ : final_results.json, params_vs_guvenen.png, objective_slices.png"
