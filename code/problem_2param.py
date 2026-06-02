"""
problem_2param.py
=================
The 2-parameter test bed (free: a1, rho1; the other 19 fixed at the Guvenen
values). Thin specialization of ``problem.Problem`` that re-exports the module-
level API used by benchmark.py, mem_benchmark.py and run_tiktak.py.
"""

from problem import Problem

_p = Problem(["a1", "rho1"])

FREE_NAMES = _p.FREE_NAMES
FREE_IDXS = _p.FREE_IDXS
N_FREE = _p.N_FREE
FREE_BOUNDS = _p.FREE_BOUNDS
FREE_TRUE = _p.FREE_TRUE
build_full_theta = _p.build_full_theta
build_target = _p.build_target
make_objective = _p.make_objective
