import asyncio
from concurrent.futures import ThreadPoolExecutor


def seed(db, order="o1", install="i1"):
    db.reserve_order(order, install)


def test_placement_is_idempotent(isolated_db):
    from activities import place_order
    seed(isolated_db)
    first = asyncio.run(place_order("o1", "s1", 1))
    second = asyncio.run(place_order("o1", "s1", 1))
    assert first == second
    assert first["label"] == "Test order"
    assert len(isolated_db.placements_for("o1")) == 1


def test_concurrent_placement_is_idempotent(isolated_db):
    seed(isolated_db)
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(lambda _: isolated_db.place_order("o1", "s1", 1), range(16)))
    assert all(row == rows[0] for row in rows)
    assert len(isolated_db.placements_for("o1")) == 1


def test_audit_retry_preserves_sequence(isolated_db):
    from activities import audit
    seed(isolated_db)
    asyncio.run(audit("o1", "workflow", "placed", {"sellerID": "s1"}, 1, 1))
    asyncio.run(audit("o1", "workflow", "placed", {"sellerID": "s1"}, 1, 1))
    rows = isolated_db.audit_for("o1")
    assert len(rows) == 1
    assert rows[0]["seq"] == 1


def test_reset_tombstone_blocks_late_activity(isolated_db):
    seed(isolated_db)
    isolated_db.mark_deleting("i1")
    assert isolated_db.place_order("o1", "s1", 1) is None
    isolated_db.delete_orders("i1")
    assert isolated_db.place_order("o1", "s1", 1) is None
    isolated_db.add_audit("o1", "workflow", "late", {}, 1, 1)
    assert isolated_db.audit_for("o1") == []


def test_approval_retry(isolated_db):
    seed(isolated_db)
    isolated_db.store_approval("o1", 2, "install", "abc")
    isolated_db.store_approval("o1", 2, "install", "abc")
    with isolated_db.connect() as conn:
        assert conn.execute("SELECT count(*) FROM approvals").fetchone()[0] == 1
