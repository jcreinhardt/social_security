"""
Tests for the file-based coordination layer (FileCoordinator + Locked) — the
parallel-correctness primitives that are otherwise nearly impossible to debug in
a live multi-worker HPC job.
"""

import threading

from tiktak import FileCoordinator, EVAL_SOBOL, LOCAL_SEARCH


def test_claim_next_hands_out_each_index_once(tmp_path):
    """Concurrent claimers must partition 0..TOTAL-1 with no dupes or gaps."""
    coord = FileCoordinator(str(tmp_path))
    TOTAL = 300
    claimed = []
    lock = threading.Lock()

    def worker():
        local = []
        while True:
            k = coord.claim_next("c")
            if k >= TOTAL:
                break
            local.append(k)
        with lock:
            claimed.extend(local)

    threads = [threading.Thread(target=worker) for _ in range(8)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert sorted(claimed) == list(range(TOTAL))


def test_locked_counter_no_lost_updates(tmp_path):
    """Under pure contention, no increments are lost: after 4*N claims the next
    value is exactly 4*N."""
    coord = FileCoordinator(str(tmp_path))
    n = 400

    def worker():
        for _ in range(n):
            coord.claim_next("mx")

    threads = [threading.Thread(target=worker) for _ in range(4)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert coord.claim_next("mx") == 4 * n


def test_state_roundtrip_and_wait(tmp_path):
    coord = FileCoordinator(str(tmp_path))
    assert coord.get_state() is None
    coord.set_state(EVAL_SOBOL)
    assert coord.get_state() == EVAL_SOBOL
    # wait_state returns immediately when already at the target
    assert coord.wait_state(EVAL_SOBOL, timeout=2) == EVAL_SOBOL
    assert coord.wait_state({EVAL_SOBOL, LOCAL_SEARCH}, timeout=2) == EVAL_SOBOL


def test_read_best_returns_min_local(tmp_path):
    coord = FileCoordinator(str(tmp_path))
    assert coord.read_best() is None
    coord.write_local_result(0, [0.1, 0.2], 5.0)
    coord.write_local_result(1, [0.3, 0.4], 2.0)   # best
    coord.write_local_result(2, [0.5, 0.6], 9.0)
    x, f = coord.read_best()
    assert f == 2.0
    assert list(x) == [0.3, 0.4]
    assert coord.count_local_results() == 3


def test_meta_roundtrip(tmp_path):
    coord = FileCoordinator(str(tmp_path))
    coord.write_meta("n_sobol", 1234)
    assert coord.read_meta_int("n_sobol") == 1234


def test_lease_staleness_and_reclaim(tmp_path):
    """Preemption recovery primitive: a fresh lease is held; a lease past its
    TTL is reclaimable; a completed task is never reclaimable."""
    coord = FileCoordinator(str(tmp_path))
    # No lease yet -> stale (reclaimable).
    assert coord.lease_is_stale("local", 7, ttl=600)
    # A just-written lease is fresh under a generous TTL, stale under ttl=0.
    coord.write_lease("local", 7, wid=3)
    assert not coord.lease_is_stale("local", 7, ttl=600)
    assert coord.lease_is_stale("local", 7, ttl=0)
    # try_reclaim honors the TTL: refuses a fresh lease, grants a stale one.
    assert not coord.try_reclaim("local", 7, wid=9, ttl=600)
    assert coord.try_reclaim("local", 7, wid=9, ttl=0)
    # Once a result exists the task is done -> never reclaimable.
    coord.write_local_result(7, [0.1, 0.2], 1.0)
    assert not coord.try_reclaim("local", 7, wid=9, ttl=0)


def test_next_missing_finds_only_unfinished_stale(tmp_path):
    """next_missing returns an index that has no result and a stale (or absent)
    lease; it skips completed and freshly-leased indices."""
    coord = FileCoordinator(str(tmp_path))
    n = 5
    coord.write_local_result(0, [0.0], 1.0)   # done -> skip
    coord.write_local_result(1, [0.0], 1.0)   # done -> skip
    coord.write_lease("local", 2, wid=1)      # fresh lease -> skip under big TTL
    # indices 3, 4 have neither result nor lease -> reclaimable
    found = coord.next_missing("local", n, ttl=600)
    assert found in (3, 4)
    # With ttl=0 the fresh lease on 2 also counts as stale/reclaimable.
    seen = {coord.next_missing("local", n, ttl=0) for _ in range(40)}
    assert 0 not in seen and 1 not in seen   # completed never returned
    assert {2, 3, 4} & seen                   # at least some unfinished returned
    # When everything is finished, next_missing reports nothing to do.
    for k in (2, 3, 4):
        coord.write_local_result(k, [0.0], 1.0)
    assert coord.next_missing("local", n, ttl=0) is None
