"""R8/14: invalid signals cannot grow the audit forever or keep an abandoned order alive."""
import asyncio
from datetime import timedelta

from conftest import proposal
from test_workflows import order, temporal_env, until  # noqa: F401


def test_invalid_proposals_have_a_finite_audit_budget(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            for _ in range(55):
                await handle.signal("proposal", args=[1, {}])
            for _ in range(500):
                rows = isolated_db.audit_for(oid, 200)
                if len([r for r in rows if r["event"] in ("ignored_signal", "ignored_signal_flood")]) >= 51:
                    break
                await asyncio.sleep(.01)
            await asyncio.sleep(.3)
            rows = isolated_db.audit_for(oid, 200)
            assert len([r for r in rows if r["event"] == "ignored_signal"]) == 50
            assert len([r for r in rows if r["event"] == "ignored_signal_flood"]) == 1
    temporal_env[0].run(scenario(temporal_env[1]))


def test_abandoned_failure_expires_even_if_invalid_signals_keep_arriving(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await env.sleep(timedelta(days=6))
            await handle.signal("proposal", args=[1, {}])
            await env.sleep(timedelta(days=2))
            snap = await handle.query("snapshot")
            assert snap["state"] == "expired"
            assert (await handle.result())["state"] == "expired"
            assert any(r["event"] == "expired" for r in isolated_db.audit_for(oid))
    temporal_env[0].run(scenario(temporal_env[1]))
