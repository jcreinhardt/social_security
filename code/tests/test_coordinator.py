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
