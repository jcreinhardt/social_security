"""
config.py
=========
``MSMConfig`` — all tuning knobs for an estimation run (simulation size, Sobol
screening, local-optimizer budget, TikTak blending, penalties).
"""

from dataclasses import dataclass


@dataclass
class MSMConfig:
    """All tuning knobs for the estimation."""

    n_sim: int = 50_000          # Number of simulated individuals
    hmax: int = 36               # Ages 25-60
    seed: int = 42               # CRN seed for simulation

    # Stage A: Sobol screening
    sobol_draws: int = 250_000   # Appendix D uses 250K
    sobol_seed: int = 999        # Sobol scramble seed (shared across workers)
    keep_best: int = 1_000       # Keep top-K legitimate points for local stage

    # Stage B: local optimization
    local_methods: tuple = ("Powell", "Nelder-Mead")
    maxiter_local: int = 1_000
    # Exploit-heavy restarts (blend weight near theta_max, start already close
    # to the incumbent best) need far fewer iterations; the per-restart budget
    # scales from maxiter_local (at theta_k=0) down to this fraction (at =1).
    maxiter_min_frac: float = 0.15

    # TikTak blending: x_start = theta_k * z_star + (1-theta_k) * sobol_start,
    # theta_k ramping theta_min -> theta_max across the restarts.
    #   "sqrt"   concave ramp (Guvenen-style): exploits the incumbent best
    #            earlier, so most restarts start near it and converge in fewer
    #            objective evaluations.
    #   "linear" gentler ramp: more exploration, more evals.
    blend_shape: str = "sqrt"
    theta_min: float = 0.1
    theta_max: float = 0.995

    # Filtering / penalties
    max_legit_obj_val: float = 1e8
    penalty_weight: float = 1e6
