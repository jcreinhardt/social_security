"""
block_residuals.py
==================
Evaluate the MSM objective at Guvenen's published THETA_TRUE against the REAL
data target and break down the weighted contribution block by block. This tells
us whether the run's discrepancy from Guvenen is a moment-computation bug (some
block is large at their own published parameters -> our moment differs from
theirs) or genuine flat-valley non-identification (every block already near zero
at their point, so a *different* parameter vector can fit marginally better).

    conda run -n socsec_mac python code/benchmarking/block_residuals.py \
        --data data --n-sim 100000
"""

import argparse
import os as _os
import sys as _sys

import numpy as np

_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)),
                                  "..", "algorithm"))

from msm_model import (
    MSMConfig, THETA_TRUE,
    simulate_income, calculate_moments, flatten_moments,
    build_weight_and_psi, deviation_F, get_shocks,
    load_target_moments, load_ir_data_full, impulse_response_F,
)


def per_block_F(theta, cfg, data_path):
    """Return (slices, w_diag, F, m_target, d) for `theta` against the real
    target, replacing the impulse block with the interpolated-target residual
    exactly as problem.make_objective does."""
    m_target, slices = load_target_moments(data_path)
    ir_data = load_ir_data_full(data_path)
    w_diag, psi, _, _ = build_weight_and_psi(m_target, slices)

    shocks = get_shocks(cfg.n_sim, cfg.hmax, cfg.seed)
    ysim = simulate_income(theta, cfg.n_sim, cfg.hmax, cfg.seed, shocks=shocks)
    mom = calculate_moments(ysim)
    d, _ = flatten_moments(mom)

    F = deviation_F(d, m_target, psi)
    s, e = slices["irmoments"]
    F[s:e] = impulse_response_F(mom["irmoments"], ir_data).ravel()
    return slices, w_diag, F, m_target, d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data")
    ap.add_argument("--n-sim", type=int, default=100_000)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    cfg = MSMConfig(n_sim=args.n_sim, hmax=36, seed=args.seed)
    slices, w, F, m_target, d = per_block_F(THETA_TRUE, cfg, args.data)

    total = float(np.sqrt(np.sum(w * F ** 2)))
    ssq_total = float(np.sum(w * F ** 2))
    print(f"n_sim={args.n_sim}, seed={args.seed}, real target = {args.data}\n")
    print(f"Objective at Guvenen THETA_TRUE (real data): {total:.6e}\n")

    print(f"{'block':16s} {'n':>5s} {'w*F^2 sum':>12s} {'% SSQ':>7s} "
          f"{'rms|F|':>8s} {'max|F|':>9s} {'@i':>5s}")
    print("-" * 70)
    for name, (s, e) in slices.items():
        wf2 = float(np.sum(w[s:e] * F[s:e] ** 2))
        mask = w[s:e] > 0
        fblk = F[s:e][mask]
        rms = float(np.sqrt(np.mean(fblk ** 2))) if fblk.size else 0.0
        if fblk.size:
            wi = int(np.argmax(np.abs(F[s:e]) * mask))
            mx = float(F[s:e][wi])
        else:
            wi, mx = -1, 0.0
        pct = 100 * wf2 / ssq_total if ssq_total else 0.0
        print(f"{name:16s} {e-s:5d} {wf2:12.5e} {pct:6.1f}% {rms:8.4f} "
              f"{mx:+9.4f} {wi:5d}")
    print("-" * 70)
    print(f"{'TOTAL (SSQ)':16s} {'':5s} {ssq_total:12.5e}   sqrt = {total:.6e}")

    # The persistent-innovation mixture (pdf_ar, sd_eta1/2, mu_eta1) is seen only
    # through the std/skew/kurt of earnings changes. Surface those residuals.
    print("\nSdSkewKurt residual detail (cols = sd / skew / kurt):")
    for blk in ("SdSkewKurt_L1", "SdSkewKurt_L5"):
        s, e = slices[blk]
        Fb = F[s:e].reshape(-1, 3)
        lab = ["sd", "skew", "kurt"]
        rms = np.sqrt(np.mean(Fb ** 2, axis=0))
        mx = Fb[np.argmax(np.abs(Fb), axis=0), [0, 1, 2]]
        print(f"  {blk}:  " + "   ".join(
            f"{lab[k]} rms={rms[k]:.3f} max={mx[k]:+.3f}" for k in range(3)))


if __name__ == "__main__":
    main()
