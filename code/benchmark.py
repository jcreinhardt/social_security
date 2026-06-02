"""
benchmark.py
============
Times the building blocks of one objective evaluation and the local-search
step, to see where wall time goes. Run:

    conda run -n socsec_mac python code/benchmark.py --n-sim 10000 --reps 20
"""

import argparse
import time

import numpy as np

from msm_model import (
    MSMConfig, THETA_TRUE, simulate_income, calculate_moments,
    flatten_moments, build_weight_and_psi, deviation_F,
)
import problem_2param as prob
from tiktak import local_search


def timeit(fn, reps):
    # one warmup (JIT/cache), then timed reps
    fn()
    t0 = time.perf_counter()
    for _ in range(reps):
        fn()
    return (time.perf_counter() - t0) / reps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n-sim", type=int, default=10_000)
    ap.add_argument("--reps", type=int, default=20)
    ap.add_argument("--maxiter", type=int, default=600)
    args = ap.parse_args()

    cfg = MSMConfig(n_sim=args.n_sim, hmax=36, seed=42, maxiter_local=args.maxiter)
    theta = THETA_TRUE

    print(f"n_sim={args.n_sim}, hmax={cfg.hmax}, reps={args.reps}\n")

    # 1. simulate_income
    t_sim = timeit(lambda: simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed), args.reps)

    # 2. calculate_moments (on a fixed panel)
    ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed)
    t_mom = timeit(lambda: calculate_moments(ysim), args.reps)

    # 3. full objective eval (sim + moments + deviation)
    m_target, slices = flatten_moments(calculate_moments(ysim))
    w_diag, psi, _, _ = build_weight_and_psi(m_target, slices)

    def one_eval():
        ys = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed)
        d, _ = flatten_moments(calculate_moments(ys))
        return float(np.sum(w_diag * (deviation_F(d, m_target, psi) ** 2)))

    t_eval = timeit(one_eval, args.reps)

    # 4. objective via the problem closure (what the optimizer actually calls)
    objective = prob.make_objective(cfg)         # builds synthetic target once
    x_true = prob.FREE_TRUE
    t_obj = timeit(lambda: objective(x_true), args.reps)

    # 5. one local search restart (Powell -> Nelder-Mead), single rep (expensive)
    x0 = np.array([0.7, 0.95])
    t0 = time.perf_counter()
    bx, bf = local_search(objective, x0, prob.FREE_BOUNDS, cfg)
    t_local = time.perf_counter() - t0

    print(f"{'step':32s} {'time/call':>12s}")
    print("-" * 46)
    print(f"{'simulate_income':32s} {t_sim*1e3:9.2f} ms")
    print(f"{'calculate_moments':32s} {t_mom*1e3:9.2f} ms")
    print(f"{'  -> moments / sim ratio':32s} {t_mom/t_sim:11.2f}x")
    print(f"{'full objective eval':32s} {t_eval*1e3:9.2f} ms")
    print(f"{'objective() closure':32s} {t_obj*1e3:9.2f} ms")
    print(f"{'one local_search restart':32s} {t_local:9.2f} s   "
          f"(~{t_local/max(t_obj,1e-9):.0f} evals, f={bf:.2e})")
    print()
    print("Extrapolation (per worker, serial):")
    print(f"  Sobol stage  (2048 pts):  {2048*t_obj:8.1f} s")
    print(f"  Local stage  (40 starts): {40*t_local:8.1f} s")


if __name__ == "__main__":
    main()
