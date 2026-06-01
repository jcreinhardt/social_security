import numpy as np
from dataclasses import dataclass
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
# FIX: Import the summary statistic functions from toolbox
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
    
    # Simulate income array - FIX: Use correct function signature
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
# 4) Sobol screen + refine (parallelized)
# ============================================================

def sobol_screen(objective_fn, bounds, n, seed=123):
    """
    Screen many Sobol points in parallel.
    
    Returns:
        starts: sorted array of starting points (best first)
        fvals: sorted objective values
    """
    bounds = np.asarray(bounds)
    sampler = qmc.Sobol(d=bounds.shape[0], seed=seed)
    starts = sampler.random(n=n) * (bounds[:, 1] - bounds[:, 0]) + bounds[:, 0]
    
    # FIX: Convert to list for pool.map
    # Parallel evaluation
    with mp.Pool(mp.cpu_count() - 1) as pool:
        fvals = pool.map(objective_fn, list(starts))
    
    fvals = np.asarray(fvals, float)
    idx = np.argsort(fvals)
    starts = starts[idx]
    fvals = fvals[idx]
    return starts, fvals

def run_local_opts_for_start(args):
    """
    Run local optimization starting from a given point.
    FIX: All variables passed as arguments for proper pickling.
    
    Args:
        args: tuple of (x_start, objective_fn, bounded_obj, bounds, local_methods, maxiter_local)
    
    Returns:
        best_res: optimization result with lowest objective
    """
    x_start, objective_fn, bounded_obj, bounds, local_methods, maxiter_local = args
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
                res = minimize(
                    bounded_obj,
                    x0=x_curr,
                    method="Powell",
                    options={"maxiter": maxiter_local, "disp": False},
                )
                res.x = project_to_bounds(res.x, bounds)
                res.fun = objective_fn(res.x)
        
        elif method == "Nelder-Mead":
            res = minimize(
                bounded_obj,
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

def sobol_screen_and_refine(objective_fn, bounds, sobol_draws, keep_best, local_methods, maxiter_local, seed=123):
    """
    Sobol screen followed by parallel local refinement.
    
    Returns:
        results: list of optimization results sorted by objective value
        all_starts: all Sobol starting points
        best_starts: the keep_best best starting points
        best_idx: indices of best starting points
    """
    # FIX: Ensure bounds is numpy array
    bounds = np.asarray(bounds)
    
    # Screen all Sobol points
    all_starts, all_fvals = sobol_screen(objective_fn, bounds, n=sobol_draws, seed=seed)
    best_idx = np.argsort(all_fvals)[:keep_best]
    best_starts = all_starts[best_idx]
    
    # FIX: Create bounded_obj once before parallel loop
    bounded_obj = make_bounded_objective(objective_fn, bounds)
    
    # Parallel refinement
    with mp.Pool(mp.cpu_count() - 1) as pool:
        args_list = [
            (best_starts[i], objective_fn, bounded_obj, bounds, local_methods, maxiter_local) 
            for i in range(keep_best)
        ]
        results = pool.map(run_local_opts_for_start, args_list)
    
    # FIX: Filter out None results and handle failures
    results = [r for r in results if r is not None and np.isfinite(r.fun)]
    
    if not results:
        raise ValueError("All local optimizations failed")
    
    results.sort(key=lambda r: r.fun)
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
    Appendix D style estimation:
      - build W and psi
      - define MSM objective with CRN
      - Sobol screen many points
      - local derivative-free refinement from best points
    
    Args:
        m: empirical moments
        bounds: parameter bounds
        weights_groups: dict mapping group names to (indices, weight)
        moment_sets: dict mapping set names to indices
        cfg: MSMConfig object
        sobol_seed: random seed for Sobol sequence
    
    Returns:
        best: best optimization result
        results: list of all optimization results
        all_starts: all Sobol starting points
        best_starts: best Sobol starting points
        best_idx: indices of best starting points
    """
    m = np.asarray(m, float)
    n_mom = m.size

    w_diag = make_diagonal_weights(n_mom, weights_groups)
    psi = compute_psi(m, moment_sets)

    def obj(th):
        return msm_objective(th, m, w_diag, psi, cfg)

    results, all_starts, best_starts, best_idx = sobol_screen_and_refine(
        objective_fn=obj,
        bounds=bounds,
        sobol_draws=cfg.sobol_draws,
        keep_best=cfg.keep_best,
        local_methods=cfg.local_methods,
        maxiter_local=cfg.maxiter_local,
        seed=sobol_seed
    )

    best = results[0]
    return best, results, all_starts, best_starts, best_idx