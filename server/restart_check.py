"""Kill -9 the worker mid-order against the REAL Temporal dev server and check nothing is lost
or doubled. Uses its own task queue and a throwaway DB, so app data is never touched."""
import asyncio
import os
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path
from uuid import uuid4

HERE = Path(__file__).resolve().parent
QUEUE = "parchi-restart-check"
TMP = Path(tempfile.mkdtemp(prefix="parchi-restart-"))
os.environ["PARCHI_DB"] = str(TMP / "restart.db")
os.environ["PARCHI_TASK_QUEUE"] = QUEUE
sys.path.insert(0, str(HERE))

from temporalio.client import Client  # noqa: E402

import db  # noqa: E402

failures = 0


def check(ok: bool, message: str) -> None:
    global failures
    failures += 0 if ok else 1
    print(("PASS " if ok else "FAIL ") + message, flush=True)


def start_worker() -> subprocess.Popen:
    return subprocess.Popen([sys.executable, "worker.py"], cwd=HERE, env=os.environ.copy(),
                            stdout=open(TMP / "worker.log", "ab"), stderr=subprocess.STDOUT)


async def until(handle, predicate, what: str, seconds: float = 40):
    last = None
    for _ in range(int(seconds * 10)):
        try:
            last = await asyncio.wait_for(handle.query("snapshot"), 5)
            if predicate(last):
                return last
        except Exception:
            pass  # worker may still be starting
        await asyncio.sleep(0.1)
    raise AssertionError(f"timed out waiting for {what}: {last}")


def order_input(oid: str) -> dict:
    def line(item: str, seller: str) -> dict:
        return {"itemID": item, "sellerID": seller, "price": 100, "isSubstitute": False}
    lines = [line("a", "s1"), line("b", "s2")]
    plan = {"lines": lines, "feesBySeller": {}, "itemsTotal": 200, "feesTotal": 0, "stops": 2,
            "maxEtaMinutes": 60, "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0}
    sellers = [{"id": s, "name": s, "channel": "localChemist", "etaMinutes": 60,
                "requiresVisit": True} for s in ("s1", "s2")]
    return {"order_id": oid, "install_id": "restart-check", "plan": plan, "sellers": sellers,
            "auto_approve_cap_paise": None, "time_scale": 1}


async def main() -> None:
    db.init_db()
    client = await Client.connect(os.environ.get("PARCHI_TEMPORAL", "localhost:7233"))
    oid = "rc-" + uuid4().hex[:12]
    db.reserve_order(oid, "restart-check")
    worker = start_worker()
    handle = None
    try:
        handle = await client.start_workflow("OrderWorkflow", order_input(oid), id="order-" + oid,
                                             task_queue=QUEUE)
        await until(handle, lambda s: s["ready"], "order placed")
        await handle.signal("seller_event", args=["s1", "confirmed"])
        await until(handle, lambda s: s["sellers"][0]["status"] == "confirmed", "s1 confirmed")
        check(True, "order placed and s1 confirmed before the kill")

        worker.send_signal(signal.SIGKILL)
        worker.wait()
        check(worker.returncode == -signal.SIGKILL, "worker killed with SIGKILL")
        # Signals sent while no worker is running must be kept by Temporal.
        await handle.signal("seller_event", args=["s1", "shipped"])

        worker = start_worker()
        state = await until(handle, lambda s: s["sellers"][0]["status"] == "shipped",
                            "s1 shipped after restart")
        check(state["state"] == "placed", "state rebuilt from history after restart")
        await handle.signal("seller_event", args=["s1", "delivered"])
        await handle.signal("seller_event", args=["s2", "confirmed"])
        await handle.signal("seller_event", args=["s2", "delivered"])
        final = await asyncio.wait_for(handle.result(), 40)
        check(final["state"] == "done", f"final state is done (got {final['state']})")
        check([s["status"] for s in final["sellers"]] == ["delivered", "delivered"],
              "both sellers delivered")
        placements = db.placements_for(oid)
        check(len(placements) == 2, f"exactly 2 placements, no doubles (got {len(placements)})")
        seqs = [r["seq"] for r in db.audit_for(oid, 1000)]
        check(bool(seqs) and seqs == list(range(1, len(seqs) + 1)),
              f"audit sequence contiguous ({len(seqs)} rows)")
    except Exception as error:
        check(False, f"{type(error).__name__}: {error}")
        if handle is not None:
            try:
                await handle.terminate(reason="restart_check failed")
            except Exception:
                pass
    finally:
        if worker.poll() is None:
            worker.terminate()
            worker.wait()
        shutil.rmtree(TMP, ignore_errors=True)
    print("RESULT " + ("PASS" if failures == 0 else "FAIL"), flush=True)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    asyncio.run(main())
