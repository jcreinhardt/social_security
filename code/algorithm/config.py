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

    # Defaults below mirror Guvenen et al.'s estimation replication code
    # (guvenen_2021_replication/.../Estimation/{OBJECTIVE,ESTIMATE}.f90).
    n_sim: int = 100_000         # Simulated individuals. Guvenen: nsim=100000,
                                 # nrun=1 (OBJECTIVE.f90:13-14)
    hmax: int = 36               # Ages 25-60
    seed: int = 42               # CRN seed for simulation

    # Stage A: Sobol screening
    # Guvenen draws qr_ndraw=900000 Sobol points (ESTIMATE.f90:30). We round up
    # to the next power of two (2^20 = 1,048,576) because scipy's Sobol sequence
    # is only balanced at powers of two (a truncated draw loses that balance).
    sobol_draws: int = 1_048_576
    sobol_seed: int = 999        # Sobol scramble seed (shared across workers)
    keep_best: int = 2_000       # Local-search starts. Guvenen: nstart=2000
                                 # (ESTIMATE.f90:31)

    # Multi-fidelity: the Sobol screen + local restarts (exploration -- they only
    # need to RANK basins) may run at a cheaper, noisier n_sim_screen, while the
    # final POLISH (which sets the reported estimate's accuracy) runs at the full
    # n_sim. 0 -> disabled (screen == polish == n_sim). At n_sim=100k one eval is
    # ~0.9s, so screening at ~30k (~3x cheaper) lets a restart fit a short
    # preemptible walltime without making the final estimate coarse.
    n_sim_screen: int = 0

    # Stage B: local optimization
    local_methods: tuple = ("Powell", "Nelder-Mead")
    maxiter_local: int = 1_000
    # Exploit-heavy restarts (blend weight near theta_max, start already close
    # to the incumbent best) need far fewer iterations; the per-restart budget
    # scales from maxiter_local (at theta_k=0) down to this fraction (at =1).
    maxiter_min_frac: float = 0.15
    # Stage D POLISH (one final local search from the global best) uses its OWN
    # budget, decoupled from the restarts: the restarts are deliberately coarse
    # (so a preemptible scavenge worker can finish one inside its short walltime),
    # while the polish runs on the stable coordinator with no walltime pressure
    # and does the accurate final convergence. Default generous.
    maxiter_polish: int = 1_000

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

    # Fault tolerance (preemptible / scavenge runs). A task (Sobol point or
    # local restart) whose lease has not been refreshed within lease_ttl seconds
    # is presumed abandoned (its worker was preempted) and re-claimed by a
    # survivor. Live workers refresh the lease via a per-iteration heartbeat, so
    # this only needs to exceed the gap between heartbeats with margin.
    lease_ttl: float = 600.0
    # Coordinator babysitter cadence: how often the stable coordinator checks on
    # the scavenge array (resubmit if drained) and drives stage transitions.
    babysit_interval: float = 60.0
