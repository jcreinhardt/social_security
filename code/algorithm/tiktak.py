"""
tiktak.py
=========
File-coordinated TikTak global optimizer (Arnoud, Guvenen & Kleineberg 2019).

This is a Python port of the Fortran state machine in
``TikTak-main/TiktakGlobalSearch.f90`` + ``stateControl.f90``. Its defining
feature -- and the reason it scales across an HPC -- is that many *independent*
processes (on one machine or across many machines sharing a filesystem)
cooperate purely through lock-protected files. There is no MPI and no shared
memory: coordination is the filesystem.

Algorithm (each "worker" is one OS process running ``run_worker``):
  1. INIT          one worker becomes leader, draws the Sobol point set.
  2. EVAL_SOBOL    workers atomically claim point indices, evaluate the
                   objective, and drop a per-index result file.
  3. SELECT_STARTS leader sorts the evaluations, keeps the best K legitimate
                   points as local-search start points.
  4. LOCAL_SEARCH  workers atomically claim start indices; each start is
                   blended toward the running global best
                   (theta_k * z_star + (1-theta_k) * start_k, theta_k ramping
                   up) and refined with a local optimizer.
  5. POLISH        leader runs one final local search from the global best.
  6. DONE          all workers exit.

Coordination primitives (replacing ``stateControl.f90``):
  * Locked          -> fcntl.flock advisory lock (mirrors myopen SHARE='DENYRW')
  * claim_next      -> atomic read/increment/write of a counter (getNextNumber)
  * get/set/wait_state -> a `state` file polled by non-leaders (getState/waitState)
  * per-index result files + glob -> robust on NFS, no single-file append
    contention (replaces the locked append to sobolFnVal.dat/searchResults.dat)
"""

import fcntl
import glob
import json
import os
import time

import numpy as np
from scipy.optimize import minimize
from scipy.stats import qmc

# ── State machine ───────────────────────────────────────────────────────
INIT = "INIT"
EVAL_SOBOL = "EVAL_SOBOL"
SELECT_STARTS = "SELECT_STARTS"
LOCAL_SEARCH = "LOCAL_SEARCH"
POLISH = "POLISH"
DONE = "DONE"

POLL_SLEEP = 0.3       # seconds between polls while waiting
DEFAULT_TIMEOUT = 3600  # safety cap on any wait loop


class Locked:
    """Context manager taking an exclusive advisory lock on ``<path>``.

    Mirrors the Fortran ``myopen`` with SHARE='DENYRW': blocks (with retry)
    until the lock is acquired. Used both as a mutex (state transitions,
    leader election) and to make counter increments atomic.
    """

    def __init__(self, path):
        self.path = path
        self._fh = None

    def __enter__(self):
        self._fh = open(self.path, "a+")
        while True:
            try:
                fcntl.flock(self._fh.fileno(), fcntl.LOCK_EX)
                return self._fh
            except OSError:
                time.sleep(0.05)

    def __exit__(self, *exc):
        try:
            fcntl.flock(self._fh.fileno(), fcntl.LOCK_UN)
        finally:
            self._fh.close()
            self._fh = None


class FileCoordinator:
    """The shared run directory and all file-based coordination logic."""

    def __init__(self, workdir):
        self.workdir = os.path.abspath(workdir)
        self.sobol_dir = os.path.join(self.workdir, "sobol")
        self.local_dir = os.path.join(self.workdir, "local")
        for d in (self.workdir, self.sobol_dir, self.local_dir):
            os.makedirs(d, exist_ok=True)

    # -- paths ------------------------------------------------------------
    def _p(self, name):
        return os.path.join(self.workdir, name)

    # -- state ------------------------------------------------------------
    def get_state(self):
        try:
            with open(self._p("state")) as fh:
                return fh.read().strip()
        except FileNotFoundError:
            return None

    def set_state(self, state):
        tmp = self._p("state.tmp")
        with open(tmp, "w") as fh:
            fh.write(state)
        os.replace(tmp, self._p("state"))

    def wait_state(self, target, timeout=DEFAULT_TIMEOUT):
        """Block until state == target (or one of a set), or DONE/timeout."""
        targets = {target} if isinstance(target, str) else set(target)
        t0 = time.time()
        while True:
            s = self.get_state()
            if s in targets:
                return s
            if s == DONE and DONE not in targets:
                return s
            if time.time() - t0 > timeout:
                raise TimeoutError(f"wait_state({targets}) timed out; state={s}")
            time.sleep(POLL_SLEEP)

    # -- atomic counters (work claiming) ---------------------------------
    def claim_next(self, counter):
        """Atomically read, increment, and write a counter; return the value
        the caller claimed. Guarantees every index is handed out exactly once
        across all processes (replaces getNextNumber)."""
        lock = self._p(f"{counter}.lock")
        path = self._p(counter)
        with Locked(lock):
            try:
                with open(path) as fh:
                    val = int(fh.read().strip() or "0")
            except FileNotFoundError:
                val = 0
            with open(path, "w") as fh:
                fh.write(str(val + 1))
            return val

    # -- small meta values ------------------------------------------------
    def write_meta(self, key, value):
        tmp = self._p(f"{key}.tmp")
        with open(tmp, "w") as fh:
            fh.write(str(value))
        os.replace(tmp, self._p(key))

    def read_meta_int(self, key):
        with open(self._p(key)) as fh:
            return int(fh.read().strip())

    # -- result files (atomic via tmp+rename) ----------------------------
    @staticmethod
    def _write_json(path, obj):
        tmp = path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(obj, fh)
        os.replace(tmp, path)

    def write_sobol_result(self, i, x, f):
        self._write_json(os.path.join(self.sobol_dir, f"{i:08d}.json"),
                          {"i": int(i), "x": list(map(float, x)), "f": float(f)})

    def write_local_result(self, k, x, f):
        self._write_json(os.path.join(self.local_dir, f"{k:08d}.json"),
                         {"k": int(k), "x": list(map(float, x)), "f": float(f)})

    def count_sobol_results(self):
        return len(glob.glob(os.path.join(self.sobol_dir, "*.json")))

    def count_local_results(self):
        return len(glob.glob(os.path.join(self.local_dir, "*.json")))

    def load_sobol_results(self):
        recs = []
        for p in glob.glob(os.path.join(self.sobol_dir, "*.json")):
            try:
                with open(p) as fh:
                    recs.append(json.load(fh))
            except (json.JSONDecodeError, FileNotFoundError):
                continue
        return recs

    def load_local_results(self):
        recs = []
        for p in glob.glob(os.path.join(self.local_dir, "*.json")):
            try:
                with open(p) as fh:
                    recs.append(json.load(fh))
            except (json.JSONDecodeError, FileNotFoundError):
                continue
        return recs

    def read_best(self):
        """Best (x, f) among completed local searches; None if none yet
        (replaces getBestPoint)."""
        best = None
        for r in self.load_local_results():
            if best is None or r["f"] < best[1]:
                best = (np.array(r["x"], float), r["f"])
        return best

    def wait_until(self, predicate, timeout=DEFAULT_TIMEOUT):
        t0 = time.time()
        while not predicate():
            if self.get_state() == DONE:
                return
            if time.time() - t0 > timeout:
                raise TimeoutError("wait_until timed out")
            time.sleep(POLL_SLEEP)


# ============================================================================
# Local optimizer  (replaces BOBYQA_H / amoeba / dfpmin)
# ============================================================================

def _bound_penalty(x, lo, hi, weight):
    below = np.maximum(lo - x, 0.0)
    above = np.maximum(x - hi, 0.0)
    return weight * float(np.sum(below ** 2 + above ** 2))


def local_search(objective, x_start, bounds, cfg, maxiter=None):
    """Run a chain of local optimizers from ``x_start``; return (best_x,
    best_f). Powell is tried with native bounds, others via a smooth penalty
    (the pattern from earning_dynamics/4_parameter_test.py:_run_restart).
    ``maxiter`` overrides ``cfg.maxiter_local`` for this restart (used to give
    exploit-heavy restarts a smaller budget)."""
    lo, hi = bounds[:, 0], bounds[:, 1]
    bounds_list = [tuple(b) for b in bounds]
    mi = cfg.maxiter_local if maxiter is None else int(maxiter)

    def clipped_obj(x):
        return objective(np.clip(np.atleast_1d(x), lo, hi))

    def penalized_obj(x):
        x = np.atleast_1d(x)
        return clipped_obj(x) + _bound_penalty(x, lo, hi, cfg.penalty_weight)

    best_x = np.clip(np.asarray(x_start, float), lo, hi)
    best_f = clipped_obj(best_x)
    x_curr = best_x.copy()

    for method in cfg.local_methods:
        try:
            if method == "Powell":
                try:
                    res = minimize(clipped_obj, x0=x_curr, method="Powell",
                                   bounds=bounds_list,
                                   options={"maxiter": mi, "disp": False})
                except TypeError:
                    res = minimize(penalized_obj, x0=x_curr, method="Powell",
                                   options={"maxiter": mi, "disp": False})
            else:
                res = minimize(penalized_obj, x0=x_curr, method=method,
                               options={"maxiter": mi, "disp": False})
            cand_x = np.clip(np.atleast_1d(res.x), lo, hi)
            cand_f = clipped_obj(cand_x)
            if np.isfinite(cand_f) and cand_f < best_f:
                best_f, best_x = cand_f, cand_x
                x_curr = best_x.copy()
        except Exception:
            pass

    return best_x, float(best_f)


# ============================================================================
# Stages
# ============================================================================

def _try_become_leader(coord, objective, bounds, cfg):
    """First process to grab the init lock and find no `initialized` flag
    becomes leader: it draws the Sobol set and opens EVAL_SOBOL. Returns True
    if this process is the leader."""
    with Locked(coord._p("init.lock")):
        if os.path.exists(coord._p("initialized")):
            return False
        lo, hi = bounds[:, 0], bounds[:, 1]
        d = bounds.shape[0]
        sampler = qmc.Sobol(d=d, scramble=True, seed=cfg.sobol_seed)
        m_pow2 = int(np.ceil(np.log2(cfg.sobol_draws)))
        u = sampler.random_base2(m=m_pow2)[:cfg.sobol_draws]
        starts = qmc.scale(u, lo, hi)
        np.save(coord._p("sobol_points.npy"), starts)
        coord.write_meta("n_sobol", len(starts))
        coord.set_state(EVAL_SOBOL)
        # mark initialized last, so the flag implies everything above is done
        with open(coord._p("initialized"), "w") as fh:
            fh.write("1")
        return True


def _stage_eval_sobol(coord, objective, wid):
    sobol_points = np.load(coord._p("sobol_points.npy"))
    n_sobol = coord.read_meta_int("n_sobol")
    n_done_local = 0
    while True:
        i = coord.claim_next("sobol_counter")
        if i >= n_sobol:
            break
        f = objective(sobol_points[i])
        coord.write_sobol_result(i, sobol_points[i], f)
        n_done_local += 1
    print(f"[worker {wid}] evaluated {n_done_local} Sobol points", flush=True)
    # wait for the whole set to be finished by all workers
    coord.wait_until(lambda: coord.count_sobol_results() >= n_sobol)


def _stage_select(coord, cfg, wid):
    """Leader-only critical section: sort Sobol evals, keep best-K legitimate
    starts (replaces chooseSobol / indexx)."""
    with Locked(coord._p("select.lock")):
        if coord.get_state() != EVAL_SOBOL:
            return  # someone else already selected
        recs = coord.load_sobol_results()
        x = np.array([r["x"] for r in recs], float)
        f = np.array([r["f"] for r in recs], float)
        legit = np.isfinite(f) & (f < cfg.max_legit_obj_val)
        n_legit = int(legit.sum())
        if n_legit == 0:
            raise ValueError("No legitimate Sobol points; widen bounds.")
        f_sort = np.where(legit, f, np.inf)
        order = np.argsort(f_sort)
        keep = min(cfg.keep_best, n_legit)
        np.save(coord._p("x_starts.npy"), x[order][:keep])
        np.save(coord._p("x_starts_vals.npy"), f_sort[order][:keep])
        coord.write_meta("n_starts", keep)
        print(f"[worker {wid}] selected {keep} starts "
              f"(best Sobol f={f_sort[order][0]:.6e}, {n_legit} legit)", flush=True)
        coord.set_state(LOCAL_SEARCH)


def _stage_local_search(coord, objective, bounds, cfg, wid):
    starts = np.load(coord._p("x_starts.npy"))
    start_vals = np.load(coord._p("x_starts_vals.npy"))
    n_starts = coord.read_meta_int("n_starts")
    lo, hi = bounds[:, 0], bounds[:, 1]
    sobol_best = (starts[0].copy(), float(start_vals[0]))
    n_done_local = 0

    while True:
        k = coord.claim_next("local_counter")
        if k >= n_starts:
            break
        # running global best (z_star): best completed local result, else
        # the best Sobol point.
        rb = coord.read_best()
        z_star, _ = rb if (rb is not None and rb[1] < sobol_best[1]) else sobol_best

        frac = (k + 1) / n_starts
        if cfg.blend_shape == "linear":
            theta_k = cfg.theta_min + (cfg.theta_max - cfg.theta_min) * frac
        else:  # "sqrt": concave ramp, exploits the incumbent best earlier
            theta_k = min(max(np.sqrt(frac), cfg.theta_min), cfg.theta_max)
        x_start = np.clip(theta_k * z_star + (1.0 - theta_k) * starts[k], lo, hi)

        # Scale the local-optimizer budget down as theta_k rises: a restart
        # that already starts essentially at z_star needs little refinement.
        mi = int(round(cfg.maxiter_local
                       * (1.0 - (1.0 - cfg.maxiter_min_frac) * theta_k)))
        best_x, best_f = local_search(objective, x_start, bounds, cfg,
                                      maxiter=max(mi, 1))
        coord.write_local_result(k, best_x, best_f)
        n_done_local += 1

    print(f"[worker {wid}] ran {n_done_local} local searches", flush=True)
    coord.wait_until(lambda: coord.count_local_results() >= n_starts)


def _stage_polish(coord, objective, bounds, cfg, wid):
    """Leader-only: final local search from the global best (replaces the
    State-10 DFPMIN polish)."""
    with Locked(coord._p("polish.lock")):
        if coord.get_state() != LOCAL_SEARCH:
            return
        rb = coord.read_best()
        if rb is None:
            starts = np.load(coord._p("x_starts.npy"))
            rb = (starts[0], float("inf"))
        best_x, best_f = local_search(objective, rb[0], bounds, cfg)
        if not (np.isfinite(best_f) and best_f <= rb[1]):
            best_x, best_f = rb[0], rb[1]
        coord._write_json(coord._p("final_result.json"),
                          {"x": list(map(float, best_x)), "f": float(best_f)})
        print(f"[worker {wid}] polish done, final f={best_f:.6e}", flush=True)
        coord.set_state(DONE)


# ============================================================================
# Worker entry point
# ============================================================================

def run_worker(coord, objective, bounds, cfg, wid=0):
    """Run one TikTak worker process to completion against the shared run
    directory ``coord``. ``objective(x)`` is the scalar objective over the free
    parameters; ``bounds`` is a (d,2) array."""
    bounds = np.asarray(bounds, float)

    # 1. INIT (leader election)
    if coord.get_state() is None:
        _try_become_leader(coord, objective, bounds, cfg)
    coord.wait_state({EVAL_SOBOL, SELECT_STARTS, LOCAL_SEARCH, POLISH, DONE})
    if coord.get_state() == DONE:
        return

    # 2. EVAL_SOBOL
    _stage_eval_sobol(coord, objective, wid)

    # 3. SELECT_STARTS (whoever gets the lock first does it)
    if coord.get_state() == EVAL_SOBOL:
        _stage_select(coord, cfg, wid)
    coord.wait_state({LOCAL_SEARCH, POLISH, DONE})
    if coord.get_state() == DONE:
        return

    # 4. LOCAL_SEARCH
    _stage_local_search(coord, objective, bounds, cfg, wid)

    # 5. POLISH (whoever gets the lock first does it)
    if coord.get_state() == LOCAL_SEARCH:
        _stage_polish(coord, objective, bounds, cfg, wid)
    coord.wait_state(DONE)


def read_final(coord):
    """Read the leader's final polished result, or None."""
    try:
        with open(coord._p("final_result.json")) as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None
