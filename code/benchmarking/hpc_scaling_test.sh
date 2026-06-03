#!/bin/bash -l
# (login shell: initializes the module system so `module load` works in batch)
#SBATCH --job-name=tiktak_scaling
#SBATCH --nodes=1                 # single node: this is an intra-node scaling test
#SBATCH --ntasks=1                # one launcher task; it spawns the workers itself
#SBATCH --cpus-per-task=60        # >= max core count tested below; match your node
#SBATCH --exclusive               # own the whole node for clean timings
#SBATCH --time=00:30:00
#SBATCH --mem=48G                 # measured ~25G at 60 cores/n_sim=25000 (see mem_benchmark.py)
#SBATCH --output=tiktak_scaling_%j.out
# ---------------------------------------------------------------------------
# Self-contained intra-node scaling + accuracy test for the 2-parameter TikTak
# MSM problem. Copy the repo (code/ + data/ + environment.yml) to the HPC, then:
#
#     sbatch code/benchmarking/hpc_scaling_test.sh
#
# It runs the SAME problem at several core counts on ONE node, times each run,
# and writes output/scaling/scaling_summary.csv comparing speed + accuracy.
# For a quick pipeline sanity check that schedules fast, use the companion
# hpc_scaling_quick.sh instead. The shared body lives in _scaling_lib.sh.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
ENV_NAME="${ENV_NAME:-socsec_mac}"

# ---- knobs -----------------------------------------------------------------
CORES_LIST=(12 24 36 48 60)       # core counts to test (intra-node)
N_SIM=25000                       # simulated individuals per objective eval
N_SOBOL=8192                      # Sobol screening points (stage A)
KEEP_BEST=120                     # local restarts (stage B); keep >= max cores
MAXITER=600                       # local-optimizer iterations per restart
SEED=42
SOBOL_SEED=999
OUTDIR="output/scaling"

source "$ROOT/code/benchmarking/_scaling_lib.sh"
run_scaling_test
