import numpy as np
from dataclasses import dataclass, field
from scipy.optimize import minimize
from scipy.stats import qmc
import multiprocessing as mp

# ============================================================
# Helper functions
# ============================================================

def project_to_bounds(x: np.ndarray, bounds: np.ndarray) -> np.ndarray:
    """Project x into [low, high] box constraints."""
    lows = bounds[:, 0]
    highs = bounds[:, 1]
    return np.minimum(np.maximum(x, lows), highs)

def make_bounded_objective(objective_fn, bounds: np.ndarray):
    """
    Wrap objective so any x proposed by an unbounded optimizer (e.g. Nelder-Mead)
    is projected back into bounds before evaluation.
    """
    bounds = np.asarray(bounds, float)
    def obj(x):
        x = project_to_bounds(np.asarray(x, float), bounds)
        return objective_fn(x)
    return obj


# ──────────────────────────────────────────────────────────────
# CHANGED: Added quadratic penalty function (Guvenen-style)
# Instead of only clipping to bounds, Guvenen also adds a smooth
# penalty when parameters go outside bounds. This gives the
# optimizer gradient information pushing it back inside.
# ──────────────────────────────────────────────────────────────
def compute_bound_penalty(x: np.ndarray, bounds: np.ndarray, penalty_weight: float = 1e6) -> float:
    """
    Guvenen-style quadratic penalty for bound violations.
    Returns penalty_weight * sum of squared violations.
    """
    lows = bounds[:, 0]
    highs = bounds[:, 1]
    below = np.maximum(lows - x, 0.0)
    above = np.maximum(x - highs, 0.0)
    return penalty_weight * float(np.sum(below**2 + above**2))


def make_penalized_objective(objective_fn, bounds: np.ndarray, penalty_weight: float = 1e6):
    """
    CHANGED: Guvenen-style penalized objective.
    Instead of hard-clipping, adds a quadratic penalty for out-of-bounds.
    This gives smoother gradient information to the optimizer.
    """
    bounds = np.asarray(bounds, float)
    def obj(x):
        x = np.asarray(x, float)
        penalty = compute_bound_penalty(x, bounds, penalty_weight)
        x_clipped = project_to_bounds(x, bounds)
        return objective_fn(x_clipped) + penalty
    return obj
# ──────────────────────────────────────────────────────────────


# ============================================================
# 0) Config
# ============================================================

@dataclass
class MSMConfig:
    n_sim: int = 100_000
    age_start: int = 25
    age_end: int = 60
    seed: int = 123

    # Stage A: global Sobol screening
    sobol_draws: int = 250_000      # like Appendix D
    keep_best: int = 1_000          # keep best K points

    # Stage B: local optimization (derivative-free)
    local_methods: tuple = ("Powell", "Nelder-Mead")
    maxiter_local: int = 1_000

    # ──────────────────────────────────────────────────────────
    # CHANGED: Added TikTak blending parameters (Guvenen's key innovation)
    # theta_min/theta_max control how starting points are blended
    # toward the current best minimum as optimization progresses.
    # Early restarts: mostly the Sobol seed (broad exploration)
    # Late restarts: mostly pulled toward current best (focused search)
    # ──────────────────────────────────────────────────────────
    theta_min: float = 0.1          # blending weight for first restart
    theta_max: float = 0.995        # blending weight for last restart

    # ──────────────────────────────────────────────────────────
    # CHANGED: Added legitimate point filtering (Guvenen-style)
    # Sobol points with objective above this threshold are
    # discarded as "illegitimate" (model blew up, etc.)
    # ──────────────────────────────────────────────────────────
    max_legit_obj_val: float = 1e8  # max valid objective value

    # ──────────────────────────────────────────────────────────
    # CHANGED: Added penalty weight for bound enforcement
    # ──────────────────────────────────────────────────────────
    penalty_weight: float = 1e6     # quadratic penalty for out-of-bounds


# ============================================================
# 1) MSM building blocks: weights, psi, objective
# ============================================================

def make_diagonal_weights(n_mom: int, groups: dict) -> np.ndarray:
    """
    Build diagonal weights w (length n_mom) from groups.
    groups: dict like {"emp_cdf": (idx_array, group_weight), ...}
    Within each group, weight is split equally across its moments.
    """
    w = np.zeros(n_mom, dtype=float)
    for name, (idxs, group_weight) in groups.items():
        idxs = np.asarray(idxs, dtype=int)
        if idxs.size == 0:
            continue
        w[idxs] = float(group_weight) / idxs.size
    if np.any(w < 0) or np.isclose(w.sum(), 0.0):
        raise ValueError("Weights invalid. Check your group indices / weights.")
    return w

def compute_psi(m: np.ndarray, moment_sets: dict, floor: float = 1e-12) -> np.ndarray:
    """
    psi_n is the 10th percentile of |m_n| within each moment set.
    moment_sets: dict mapping set_name -> idx array
    """
    m = np.asarray(m, float)
    psi = np.zeros_like(m)
    abs_m = np.abs(m)
    for _, idxs in moment_sets.items():
        idxs = np.asarray(idxs, dtype=int)
        if idxs.size == 0:
            continue
        p10 = np.percentile(abs_m[idxs], 10)
        psi[idxs] = max(float(p10), floor)
    psi[psi == 0] = floor  # any moment not covered by a set gets a tiny floor
    return psi

# Full MSM objective (integrated with model and toolbox)
from toolbox_updated_2_2 import (
    toolbox, merge_arc_moments,
    p10, p25, p50, p75, p90, p98,
    meanlog, sdlog, skewlog, kurtlog
)
from model_to_toolbox import guv_to_toolbox
from f_guv_model import model

def msm_objective(th, m, w_diag, psi, cfg):
    """
    MSM objective function.
    
    Args:
        th: parameter vector to evaluate
        m: empirical moments
        w_diag: diagonal weight matrix
        psi: moment-specific scaling factors
        cfg: MSMConfig object
    
    Returns:
        MSM objective value
    """
    np.random.seed(cfg.seed)  # For CRN
    
    # Simulate income array
    income_array = model(
        sampleN=cfg.n_sim,
        sexes=[0],
        cohorts=[1970],
        array=True
    )
    
    # Convert to toolbox format
    df = guv_to_toolbox(income_array)
    
    # Compute moments
    results = toolbox(
        df,
        cohort=[1970],
        ages=range(cfg.age_start, cfg.age_end + 1),
        sex=[0],
        real_wage_summary=[p10, p25, p50, p75, p90, p98],
        log_wage_summary=[meanlog, sdlog, skewlog, kurtlog]
    )
    
    # Add ARC moments
    results = merge_arc_moments(
        df,
        results,
        cohort=[1970],
        ages=range(cfg.age_start, cfg.age_end + 1),
        sex=[0]
    )
    
    # Flatten to vector
    s = results.values.flatten()
    
    # Compute objective
    d = (s - m) / psi
    obj = np.dot(d, np.dot(np.diag(w_diag), d))  # Quadratic form
    
    return obj


# ============================================================
# 4) Sobol screen + refine (TikTak-style with blending)
# ============================================================

def sobol_screen(objective_fn, bounds, n, max_legit_obj_val, seed=123):
    """
    Screen many Sobol points in parallel.
    
    CHANGED: Added max_legit_obj_val parameter for legitimate point filtering.
    
    Returns:
        starts: array of starting points (sorted best-first among legitimate ones)
        fvals: corresponding objective values
        n_legit: number of legitimate points found
    """
    bounds = np.asarray(bounds)
    sampler = qmc.Sobol(d=bounds.shape[0], seed=seed)
    starts = sampler.random(n=n) * (bounds[:, 1] - bounds[:, 0]) + bounds[:, 0]
    
    # Parallel evaluation
    with mp.Pool(mp.cpu_count() - 1) as pool:
        fvals = pool.map(objective_fn, list(starts))
    
    fvals = np.asarray(fvals, float)

    # ──────────────────────────────────────────────────────────
    # CHANGED: Legitimate point filtering (Guvenen-style)
    # Discard Sobol points where the objective is too large or invalid.
    # Guvenen keeps drawing until he has enough legitimate points;
    # here we filter after the fact and warn if too few survive.
    # ──────────────────────────────────────────────────────────
    legit_mask = np.isfinite(fvals) & (fvals < max_legit_obj_val)
    n_legit = int(legit_mask.sum())
    
    # Mark illegitimate points as inf so they sort to the bottom
    fvals[~legit_mask] = np.inf
    
    if n_legit == 0:
        raise ValueError(
            f"No legitimate Sobol points found (all objectives >= {max_legit_obj_val}). "
            "Try widening bounds or increasing max_legit_obj_val."
        )
    
    print(f"[TikTak] Sobol screening: {n_legit}/{n} points legitimate "
          f"(obj < {max_legit_obj_val:.1e})")
    # ──────────────────────────────────────────────────────────

    idx = np.argsort(fvals)
    starts = starts[idx]
    fvals = fvals[idx]
    return starts, fvals, n_legit


def run_local_opts_for_start(args):
    """
    Run local optimization starting from a given point.
    
    CHANGED: Now receives a penalized_obj (Guvenen-style penalty) 
    in addition to bounded_obj.
    """
    (x_start, objective_fn, penalized_obj, bounded_obj, 
     bounds, local_methods, maxiter_local) = args
    best_res = None
    x_curr = x_start.copy()
    
    for method in local_methods:
        if method == "Powell":
            try:
                res = minimize(
                    objective_fn,
                    x0=x_curr,
                    method="Powell",
                    bounds=[tuple(b) for b in bounds],
                    options={"maxiter": maxiter_local, "disp": False},
                )
            except TypeError:
                # ──────────────────────────────────────────────
                # CHANGED: Use penalized objective instead of 
                # just clipping. This gives Powell gradient info
                # about the bounds via the penalty term.
                # ──────────────────────────────────────────────
                res = minimize(
                    penalized_obj,
                    x0=x_curr,
                    method="Powell",
                    options={"maxiter": maxiter_local, "disp": False},
                )
                res.x = project_to_bounds(res.x, bounds)
                res.fun = objective_fn(res.x)
        
        elif method == "Nelder-Mead":
            # ──────────────────────────────────────────────────
            # CHANGED: Use penalized objective for Nelder-Mead too.
            # The penalty pushes the simplex back inside bounds
            # more smoothly than hard clipping.
            # ──────────────────────────────────────────────────
            res = minimize(
                penalized_obj,
                x0=x_curr,
                method="Nelder-Mead",
                options={"maxiter": maxiter_local, "disp": False},
            )
            res.x = project_to_bounds(res.x, bounds)
            res.fun = objective_fn(res.x)
        
        else:
            raise ValueError(f"Unknown local method: {method}")
        
        if best_res is None or (np.isfinite(res.fun) and res.fun < best_res.fun):
            best_res = res
        x_curr = best_res.x
    
    return best_res


# ──────────────────────────────────────────────────────────────
# CHANGED: This is the main function that was rewritten to add
# Guvenen's TikTak blending step. The old version ran all local
# optimizations independently in parallel from raw Sobol seeds.
# The new version runs them SEQUENTIALLY so each restart can
# blend its starting point toward the current best (z_star).
# ──────────────────────────────────────────────────────────────
def sobol_screen_and_refine(objective_fn, bounds, sobol_draws, keep_best,
                            local_methods, maxiter_local, 
                            seed=123,
                            theta_min=0.1,           # CHANGED: new param
                            theta_max=0.995,          # CHANGED: new param
                            max_legit_obj_val=1e8,    # CHANGED: new param
                            penalty_weight=1e6,       # CHANGED: new param
                            n_parallel_batch=0):      # CHANGED: new param
    """
    TikTak-style Sobol screen followed by local refinement WITH BLENDING.
    
    CHANGED from original:
    - Added blending step (theta_min, theta_max)
    - Added legitimate point filtering (max_legit_obj_val)  
    - Added quadratic penalty (penalty_weight)
    - Local stage is now sequential (blending requires knowing z_star)
    - Added n_parallel_batch: if > 0, runs batches of this size in parallel
      (a compromise between fully sequential blending and fully parallel)
    
    Returns:
        results: list of optimization results sorted by objective value
        all_starts: all Sobol starting points
        best_starts: the keep_best best starting points
        best_idx: indices of best starting points
    """
    bounds = np.asarray(bounds)
    
    # ── Stage A: Sobol Screening ──────────────────────────────
    # (Same as before, but now with legitimate point filtering)
    all_starts, all_fvals, n_legit = sobol_screen(
        objective_fn, bounds, n=sobol_draws, 
        max_legit_obj_val=max_legit_obj_val,     # CHANGED: pass threshold
        seed=seed
    )
    
    # Keep the best points (only legitimate ones will be at the top)
    actual_keep = min(keep_best, n_legit)         # CHANGED: cap at # legitimate
    best_idx = np.arange(actual_keep)             # already sorted
    best_starts = all_starts[:actual_keep]
    best_fvals = all_fvals[:actual_keep]

    # Prepare objective wrappers
    bounded_obj = make_bounded_objective(objective_fn, bounds)
    penalized_obj = make_penalized_objective(objective_fn, bounds, penalty_weight)  # CHANGED

    # ──────────────────────────────────────────────────────────
    # CHANGED: Initialize z_star (global best) from the best Sobol point
    # This is what gets blended toward in Guvenen's algorithm.
    # ──────────────────────────────────────────────────────────
    z_star = best_starts[0].copy()
    f_star = best_fvals[0]
    
    print(f"[TikTak] Starting local stage: {actual_keep} restarts, "
          f"blending θ from {theta_min} to {theta_max}")
    print(f"[TikTak] Initial best from Sobol: obj = {f_star:.6e}")

    # ── Stage B: Local Refinement with TikTak Blending ────────
    results = []
    
    if n_parallel_batch > 0:
        # ──────────────────────────────────────────────────────
        # CHANGED: Batched parallel mode — a compromise.
        # Run batches of local opts in parallel, then update z_star 
        # between batches. Not as good as fully sequential blending
        # but much faster.
        # ──────────────────────────────────────────────────────
        for batch_start in range(0, actual_keep, n_parallel_batch):
            batch_end = min(batch_start + n_parallel_batch, actual_keep)
            batch_args = []
            
            for k in range(batch_start, batch_end):
                # ── THE BLENDING STEP ─────────────────────────
                frac = (k + 1) / actual_keep
                theta_k = theta_min + (theta_max - theta_min) * frac
                x_blended = theta_k * z_star + (1.0 - theta_k) * best_starts[k]
                x_blended = project_to_bounds(x_blended, bounds)
                # ──────────────────────────────────────────────
                
                batch_args.append((
                    x_blended, objective_fn, penalized_obj, bounded_obj,
                    bounds, local_methods, maxiter_local
                ))
            
            with mp.Pool(mp.cpu_count() - 1) as pool:
                batch_results = pool.map(run_local_opts_for_start, batch_args)
            
            for res in batch_results:
                if res is not None and np.isfinite(res.fun):
                    results.append(res)
                    if res.fun < f_star:
                        z_star = res.x.copy()
                        f_star = res.fun
                        print(f"[TikTak] New best after restart batch "
                              f"{batch_start}-{batch_end}: obj = {f_star:.6e}")
    else:
        # ──────────────────────────────────────────────────────
        # CHANGED: Fully sequential mode (true Guvenen TikTak).
        # Each restart blends toward the LATEST z_star, which
        # may have been updated by the previous restart.
        # This is the most faithful to the original algorithm.
        # ──────────────────────────────────────────────────────
        for k in range(actual_keep):
            # ── THE BLENDING STEP (Guvenen's key innovation) ──
            # theta_k increases from theta_min to theta_max as k
            # goes from 0 to actual_keep-1.
            # 
            # Early restarts (small k, small theta_k):
            #   x_start ≈ seed_k           (broad exploration)
            # Late restarts (large k, large theta_k):
            #   x_start ≈ z_star           (focused refinement)
            #
            # Formula: x_start = θ_k * z* + (1 - θ_k) * seed_k
            # ──────────────────────────────────────────────────
            frac = (k + 1) / actual_keep
            theta_k = theta_min + (theta_max - theta_min) * frac
            
            x_blended = theta_k * z_star + (1.0 - theta_k) * best_starts[k]
            x_blended = project_to_bounds(x_blended, bounds)
            # ──────────────────────────────────────────────────

            # Run local optimization from the blended starting point
            args = (x_blended, objective_fn, penalized_obj, bounded_obj,
                    bounds, local_methods, maxiter_local)
            res = run_local_opts_for_start(args)

            if res is not None and np.isfinite(res.fun):
                results.append(res)

                # ──────────────────────────────────────────────
                # CHANGED: Update z_star if this restart found
                # something better. Future restarts will blend
                # toward this new best.
                # ──────────────────────────────────────────────
                if res.fun < f_star:
                    z_star = res.x.copy()
                    f_star = res.fun
                    print(f"[TikTak] New best at restart {k+1}/{actual_keep}: "
                          f"obj = {f_star:.6e}")
            
            # Progress reporting every 10%
            if (k + 1) % max(1, actual_keep // 10) == 0:
                print(f"[TikTak] Progress: {k+1}/{actual_keep} restarts complete, "
                      f"best obj = {f_star:.6e}")

    if not results:
        raise ValueError("All local optimizations failed")
    
    results.sort(key=lambda r: r.fun if np.isfinite(r.fun) else np.inf)
    
    print(f"[TikTak] Done. Final best obj = {results[0].fun:.6e}")
    
    return results, all_starts, best_starts, best_idx


# ============================================================
# 5) Fit wrapper
# ============================================================

def fit_msm_appendixD_style(
    m: np.ndarray,
    bounds,
    weights_groups: dict,
    moment_sets: dict,
    cfg: MSMConfig,
    sobol_seed: int = 999
):
    """
    Appendix D style estimation with TikTak blending.
    
    CHANGED: Now passes blending parameters and legitimate-point
    threshold from cfg through to sobol_screen_and_refine.
    """
    m = np.asarray(m, float)
    n_mom = m.size

    w_diag = make_diagonal_weights(n_mom, weights_groups)
    psi = compute_psi(m, moment_sets)

    def obj(th):
        return msm_objective(th, m, w_diag, psi, cfg)

    # ──────────────────────────────────────────────────────────
    # CHANGED: Pass all new TikTak parameters to the optimizer
    # ──────────────────────────────────────────────────────────
    results, all_starts, best_starts, best_idx = sobol_screen_and_refine(
        objective_fn=obj,
        bounds=bounds,
        sobol_draws=cfg.sobol_draws,
        keep_best=cfg.keep_best,
        local_methods=cfg.local_methods,
        maxiter_local=cfg.maxiter_local,
        seed=sobol_seed,
        theta_min=cfg.theta_min,                  # CHANGED: blending
        theta_max=cfg.theta_max,                  # CHANGED: blending
        max_legit_obj_val=cfg.max_legit_obj_val,  # CHANGED: filtering
        penalty_weight=cfg.penalty_weight,        # CHANGED: penalty
        # Set n_parallel_batch=0 for true sequential TikTak.
        # Set n_parallel_batch=50 (for example) for faster batched mode.
        n_parallel_batch=0,                       # CHANGED: sequential by default
    )
    # ──────────────────────────────────────────────────────────

    best = results[0]
    return best, results, all_starts, best_starts, best_idx


# ============================================================
# SUMMARY OF ALL CHANGES
# ============================================================
#
# 1. BLENDING STEP (most important)
#    - Added theta_min, theta_max to MSMConfig
#    - In sobol_screen_and_refine: each local opt now starts from
#      x_start = θ_k * z_star + (1 - θ_k) * seed_k
#      where θ_k ramps from theta_min to theta_max across restarts
#    - z_star is updated whenever a restart finds a better minimum
#    - This is THE key innovation of Guvenen's TikTak algorithm
#
# 2. QUADRATIC PENALTY (bound enforcement)
#    - Added compute_bound_penalty() function
#    - Added make_penalized_objective() wrapper
#    - Local optimizers now use penalized objective instead of
#      just hard-clipping. Gives smoother gradient info near bounds.
#    - Added penalty_weight to MSMConfig
#
# 3. LEGITIMATE POINT FILTERING (Sobol screening)
#    - Added max_legit_obj_val to MSMConfig
#    - sobol_screen() now marks points with obj >= max_legit_obj_val
#      as illegitimate (set to inf)
#    - Reports how many points survived filtering
#    - Caps keep_best at the number of legitimate points
#
# 4. SEQUENTIAL LOCAL STAGE (required for blending)
#    - Old code: all local opts ran in parallel (no coordination)
#    - New code: local opts run sequentially so each can blend
#      toward the latest z_star
#    - Optional: n_parallel_batch > 0 for batched parallel mode
#      (compromise between speed and blending quality)
#
# 5. PROGRESS REPORTING
#    - Added print statements showing Sobol screening results,
#      best objective updates, and progress through restarts
#
# WHAT WAS NOT CHANGED:
#    - make_diagonal_weights, compute_psi: identical
#    - msm_objective: identical
#    - deviation_F formula: identical
#    - project_to_bounds: identical
#    - make_bounded_objective: still available as fallback
#    - fit_msm_appendixD_style: same interface, just passes new params
#
# NOTE ON PARALLELISM:
#    Guvenen's original Fortran uses file-based parallelism where
#    each process reads z_star from a shared file. This lets the
#    blending step work even in parallel (each process gets a
#    slightly stale z_star, which is fine). To replicate this in
#    Python you could use multiprocessing.Manager() for a shared
#    z_star, but the sequential version is simpler and matches
#    the algorithm's intended behavior most faithfully.
