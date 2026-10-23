import asyncio
from collections import defaultdict
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import p3_db
import shop
import shop_workflows

READY = "2026-10-25T18:30:00+05:30"
XSS = "<script>alert(1)</script>"


class FakeHandle:
    def __init__(self):
        self.signals = []

    async def signal(self, name, *, args):
        self.signals.append((name, args))


class FakeTemporal:
    def __init__(self):
        self.handles = defaultdict(FakeHandle)
        self.started = []
        self.fail_start = False

    async def start_workflow(self, name, data, *, id, **kwargs):
        if self.fail_start:
            raise RuntimeError("down")
        self.started.append((name, id, data))

    def get_workflow_handle(self, id):
        return self.handles[id]


def ask_body(n_shops=4, **extra):
    body = {
        "items": [{"itemID": "i1", "name": "Metformin", "strength": "500 mg", "quantity": 2},
                  {"itemID": "i2", "name": "Vitamin D", "quantity": 1}],
        "shops": [{"shopID": f"s{n}", "name": f"Shop {n}", "phone": "+910000000000",
                   "distanceM": 100 * n} for n in range(1, n_shops + 1)],
        "pickupBy": "2026-10-25T20:00:00+05:30",
    }
    body.update(extra)
    return body


def reply_body(available=True, price=1000):
    return {"items": [{"itemID": "i1", "available": available, **({"pricePaise": price} if available else {})},
                      {"itemID": "i2", "available": available, **({"pricePaise": 500} if available else {})}],
            "readyBy": READY}


@pytest.fixture
def ctx(isolated_db, monkeypatch):
    import auth
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    temporal = FakeTemporal()
    app = FastAPI()

    async def get_temporal():
        return temporal

    def install(request: Request) -> str:
        return request.headers["X-Test-Install"]

    shop.register(app, get_temporal, install)
    with TestClient(app) as client:
        yield SimpleNamespace(client=client, temporal=temporal, app=app, get_temporal=get_temporal,
                              h={"X-Test-Install": "inst-a"}, admin={"X-Admin-Key": "judge-secret"})
    auth.limiter.clear()


def make_ask(ctx, **kw):
    response = ctx.client.post("/shop/ask", headers=ctx.h, json=ask_body(**kw))
    assert response.status_code == 201, response.text
    return response.json()


def token_of(link):
    return link["url"].rsplit("/", 1)[1]


def status(ctx, ask_id, headers=None):
    return ctx.client.get(f"/shop/{ask_id}/status", headers=headers or ctx.h).json()


def shop_state(ctx, ask_id, shop_id):
    return next(s for s in status(ctx, ask_id)["shops"] if s["shopID"] == shop_id)


# ---- router ----

def test_ask_opens_first_group_only_and_stores_only_hashes(ctx, isolated_db):
    data = make_ask(ctx)
    assert data["round"] == 1
    assert [l["shopID"] for l in data["replyLinks"]] == ["s1", "s2", "s3"]
    tokens = [token_of(l) for l in data["replyLinks"]]
    assert all(len(t) >= 22 for t in tokens) and len(set(tokens)) == 3
    name, wid, wf_data = ctx.temporal.started[0]
    assert (name, wid) == ("ShopAskWorkflow", "shop-" + data["askID"])
    assert wf_data["groups"] == [["s1", "s2", "s3"], ["s4"]] and wf_data["wait_minutes"] == 10
    with p3_db.connect() as conn:
        dump = "".join(str(tuple(r)) for t in ("shop_asks", "shop_shops")
                       for r in conn.execute(f"SELECT * FROM {t}"))
    assert not any(t in dump for t in tokens)
    assert "+910000000000" not in dump  # shop phone is not stored
    st = status(ctx, data["askID"])
    assert st["state"] == "waiting" and st["noReply"] is False and st["nextGroup"] == []
    assert [s["state"] for s in st["shops"]] == ["asked", "asked", "asked", "not_asked"]


@pytest.mark.parametrize("change", [
    {"shops": []}, {"items": []}, {"pickupBy": "2026-10-25T20:00:00"}, {"groupSize": 0},
    {"waitMinutes": "10"}, {"items": [{"itemID": "i", "name": "x", "quantity": 0}]},
])
def test_ask_validation(ctx, change):
    assert ctx.client.post("/shop/ask", headers=ctx.h, json=ask_body(**change)).status_code == 422


def test_ask_max_nine_shops(ctx):
    assert ctx.client.post("/shop/ask", headers=ctx.h, json=ask_body(10)).status_code == 422
    assert ctx.client.post("/shop/ask", headers=ctx.h, json=ask_body(9)).status_code == 201


def test_quantity_ceiling_is_999_the_same_number_the_app_uses(ctx):
    """K29: the app's Add sheet, its clamp and its ask body all stop at 999."""
    def with_quantity(n):
        body = ask_body(1)
        body["items"][0]["quantity"] = n
        return ctx.client.post("/shop/ask", headers=ctx.h, json=body).status_code
    assert with_quantity(999) == 201
    assert with_quantity(1000) == 422


def test_apple_maps_shop_is_stored_only_as_opaque_id_and_generic_name(ctx, isolated_db):
    """K29: the phone sends `map-` + 12 hex, "Shop near you N" and no distance for a shop found on Apple Maps."""
    body = ask_body(2)
    body["shops"] = [{"shopID": "map-0a1b2c3d4e5f", "name": "Shop near you 1"},
                     {"shopID": "map-ffeeddccbbaa", "name": "Shop near you 2", "phone": "+910000000000"}]
    response = ctx.client.post("/shop/ask", headers=ctx.h, json=body)
    assert response.status_code == 201
    assert [l["shopID"] for l in response.json()["replyLinks"]] == ["map-0a1b2c3d4e5f", "map-ffeeddccbbaa"]
    with p3_db.connect() as conn:
        rows = [tuple(r) for r in conn.execute("SELECT shop_id, name, distance_m FROM shop_shops ORDER BY position")]
    assert rows == [("map-0a1b2c3d4e5f", "Shop near you 1", None), ("map-ffeeddccbbaa", "Shop near you 2", None)]
    st = status(ctx, response.json()["askID"])
    assert [s["shopID"] for s in st["shops"]] == ["map-0a1b2c3d4e5f", "map-ffeeddccbbaa"]


def test_ask_rolled_back_when_temporal_is_down(ctx):
    ctx.temporal.fail_start = True
    assert ctx.client.post("/shop/ask", headers=ctx.h, json=ask_body()).status_code == 503
    with p3_db.connect() as conn:
        assert conn.execute("SELECT count(*) FROM shop_asks").fetchone()[0] == 0


def test_default_install_dependency_uses_the_install_key(isolated_db):
    import auth
    auth.limiter.clear()
    _, key = auth.issue_key("phone")
    temporal = FakeTemporal()
    app = FastAPI()

    async def get_temporal():
        return temporal

    shop.register(app, get_temporal)
    client = TestClient(app)
    assert client.post("/shop/ask", json=ask_body()).status_code == 401
    assert client.post("/shop/ask", headers={"X-Install-Key": "wrong"}, json=ask_body()).status_code == 401
    assert client.post("/shop/ask", headers={"X-Install-Key": key}, json=ask_body()).status_code == 201
    auth.limiter.clear()


def test_reply_page_is_small_bilingual_and_hardened(ctx):
    data = make_ask(ctx)
    response = ctx.client.get(data["replyLinks"][0]["url"].replace("http://testserver", ""))
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert len(response.content) < 20_000
    for text in ("Available / उपलब्ध", "Not available / उपलब्ध नहीं", "Ready by", "Send / भेजें",
                 "Metformin", "500 mg", "exact brand and strength as written"):
        assert text in response.text
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["cache-control"] == "no-store"
    assert "script-src" not in response.headers["content-security-policy"]
    assert "default-src 'none'" in response.headers["content-security-policy"]


def test_xss_payloads_are_escaped(ctx):
    body = ask_body()
    body["items"][0].update(name=XSS, strength='"><img src=x onerror=alert(1)>')
    body["shops"][0]["name"] = "<b onmouseover=alert(2)>Shop</b>"
    data = ctx.client.post("/shop/ask", headers=ctx.h, json=body).json()
    page = ctx.client.get("/shop/reply/" + token_of(data["replyLinks"][0])).text
    assert XSS not in page and "<script>" not in page
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in page
    assert "<img" not in page and "&lt;img src=x onerror=alert(1)&gt;" in page
    assert "<b onmouseover" not in page and "&lt;b onmouseover=alert(2)&gt;" in page


def test_unknown_token_is_404(ctx):
    assert ctx.client.get("/shop/reply/nope-nope-nope-nope-nope").status_code == 404
    assert ctx.client.post("/shop/reply/nope-nope-nope-nope-nope", json=reply_body()).status_code == 404


def test_first_complete_reply_wins_and_others_not_needed(ctx):
    data = make_ask(ctx)
    t1, t2 = (token_of(l) for l in data["replyLinks"][:2])
    ok = ctx.client.post("/shop/reply/" + t2, json=reply_body(price=1000))
    assert ok.status_code == 200
    assert ok.json()["totalPaise"] == 1000 + 500  # price is for the whole quantity asked (Offer.price semantics)
    st = status(ctx, data["askID"])
    assert st["state"] == "replied" and st["winnerShopID"] == "s2"
    winner = shop_state(ctx, data["askID"], "s2")
    assert winner["state"] == "replied" and winner["readyBy"] == READY
    assert winner["items"][0] == {"itemID": "i1", "available": True, "pricePaise": 1000}
    assert winner["totalPaise"] == 1500
    assert [s["state"] for s in st["shops"]] == ["not_needed", "replied", "not_needed", "not_asked"]
    # the other shop's page and POST now say it is no longer needed
    assert "no longer needed" in ctx.client.get("/shop/reply/" + t1).text
    late = ctx.client.post("/shop/reply/" + t1, json=reply_body())
    assert late.status_code == 409
    form = ctx.client.post("/shop/reply/" + t1, content="a0=1&p0=5",
                           headers={"content-type": "application/x-www-form-urlencoded"})
    assert form.status_code == 409 and "no longer needed" in form.text
    assert ctx.temporal.handles["shop-" + data["askID"]].signals == [("shop_reply", ["s2"])]


def test_a_shop_may_answer_only_once(ctx):
    data = make_ask(ctx)
    t1 = token_of(data["replyLinks"][0])
    assert ctx.client.post("/shop/reply/" + t1, json=reply_body()).status_code == 200
    again = ctx.client.post("/shop/reply/" + t1, json=reply_body(price=1))
    assert again.status_code == 409
    assert shop_state(ctx, data["askID"], "s1")["totalPaise"] == 1500
    assert len(ctx.temporal.handles["shop-" + data["askID"]].signals) == 1


def test_incomplete_or_bad_reply_is_rejected_and_can_be_retried(ctx):
    data = make_ask(ctx)
    t1 = token_of(data["replyLinks"][0])
    bad = [
        {"items": reply_body()["items"][:1], "readyBy": READY},                    # missing item
        {"items": [{"itemID": "i1", "available": True, "pricePaise": 1},
                   {"itemID": "zzz", "available": False}], "readyBy": READY},     # unknown item
        {"items": [{"itemID": "i1", "available": True, "pricePaise": 1},
                   {"itemID": "i1", "available": False}], "readyBy": READY},      # duplicate
        {"items": [{"itemID": "i1", "available": True},
                   {"itemID": "i2", "available": False}], "readyBy": READY},      # no price
        {"items": [{"itemID": "i1", "available": True, "pricePaise": -5},
                   {"itemID": "i2", "available": False}], "readyBy": READY},      # negative price
        {"items": [{"itemID": "i1", "available": True, "pricePaise": 1.5},
                   {"itemID": "i2", "available": False}], "readyBy": READY},      # not integer paise
        {"items": reply_body()["items"], "readyBy": "18:30"},                       # no offset
        {"items": reply_body()["items"]},                                           # no ready-by
    ]
    for body in bad:
        assert ctx.client.post("/shop/reply/" + t1, json=body).status_code == 422, body
    assert shop_state(ctx, data["askID"], "s1")["state"] == "asked"
    assert ctx.client.post("/shop/reply/" + t1, json=reply_body()).status_code == 200


def test_html_form_post_converts_rupees_to_paise(ctx):
    data = make_ask(ctx)
    t1 = token_of(data["replyLinks"][0])
    # a form with an unanswered item is refused and stores nothing
    bad = ctx.client.post("/shop/reply/" + t1, content="a0=1&p0=3",
                          headers={"content-type": "application/x-www-form-urlencoded"})
    assert bad.status_code == 422 and "Could not send" in bad.text
    assert shop_state(ctx, data["askID"], "s1")["state"] == "asked"
    form = "a0=1&p0=12.50&a1=0&p1=&readyBy=18%3A30"
    response = ctx.client.post("/shop/reply/" + t1, content=form,
                               headers={"content-type": "application/x-www-form-urlencoded"})
    assert response.status_code == 200 and "Thanks" in response.text
    row = shop_state(ctx, data["askID"], "s1")
    assert row["items"] == [{"itemID": "i1", "available": True, "pricePaise": 1250},
                            {"itemID": "i2", "available": False}]
    assert row["totalPaise"] == 1250 and row["readyBy"].endswith("+05:30")


def test_all_unavailable_reply_is_complete_and_needs_no_ready_by(ctx):
    data = make_ask(ctx)
    t1 = token_of(data["replyLinks"][0])
    body = reply_body(available=False)
    body.pop("readyBy")
    assert ctx.client.post("/shop/reply/" + t1, json=body).status_code == 200
    row = shop_state(ctx, data["askID"], "s1")
    assert row["totalPaise"] == 0 and "readyBy" not in row


def test_oversized_body_is_refused(ctx):
    data = make_ask(ctx)
    response = ctx.client.post("/shop/reply/" + token_of(data["replyLinks"][0]),
                               content="x=" + "a" * 40_000,
                               headers={"content-type": "application/x-www-form-urlencoded"})
    assert response.status_code == 413


def test_reply_after_the_ask_is_closed_is_rejected(ctx):
    data = make_ask(ctx, shops=[{"shopID": "only", "name": "Only"}])
    t1 = token_of(data["replyLinks"][0])
    assert p3_db.close_ask(data["askID"]) is None
    assert status(ctx, data["askID"])["state"] == "closed"
    assert "closed" in ctx.client.get("/shop/reply/" + t1).text
    assert ctx.client.post("/shop/reply/" + t1, json=reply_body()).status_code == 409
    assert shop_state(ctx, data["askID"], "only")["state"] == "asked"


def test_no_reply_then_next_opens_group_two(ctx):
    data = make_ask(ctx)
    ask_id = data["askID"]
    assert p3_db.shop_mark_no_reply(ask_id, 1)       # what the workflow does after waitMinutes
    st = status(ctx, ask_id)
    assert st["noReply"] is True and st["nextGroup"] == ["s4"]
    assert [s["state"] for s in st["shops"]] == ["no_reply"] * 3 + ["not_asked"]
    opened = ctx.client.post(f"/shop/{ask_id}/next", headers=ctx.h)
    assert opened.status_code == 200
    assert opened.json()["round"] == 2
    assert [l["shopID"] for l in opened.json()["replyLinks"]] == ["s4"]
    st = status(ctx, ask_id)
    assert st["round"] == 2 and st["noReply"] is False and st["nextGroup"] == []
    assert shop_state(ctx, ask_id, "s4")["state"] == "asked"
    assert ctx.temporal.handles["shop-" + ask_id].signals == [("next_round", [2])]
    # nothing left to open
    assert ctx.client.post(f"/shop/{ask_id}/next", headers=ctx.h).status_code == 409


def test_next_conflicts_when_replied_or_nothing_left(ctx):
    data = make_ask(ctx, shops=[{"shopID": "a", "name": "A"}])
    assert ctx.client.post(f"/shop/{data['askID']}/next", headers=ctx.h).status_code == 409
    data = make_ask(ctx)
    ctx.client.post("/shop/reply/" + token_of(data["replyLinks"][0]), json=reply_body())
    assert ctx.client.post(f"/shop/{data['askID']}/next", headers=ctx.h).status_code == 409


def test_late_reply_from_a_no_reply_shop_still_counts(ctx):
    data = make_ask(ctx)
    p3_db.shop_mark_no_reply(data["askID"], 1)
    assert ctx.client.post("/shop/reply/" + token_of(data["replyLinks"][2]), json=reply_body()).status_code == 200
    assert status(ctx, data["askID"])["winnerShopID"] == "s3"


def test_status_and_next_belong_to_the_owner(ctx):
    data = make_ask(ctx)
    other = {"X-Test-Install": "inst-b"}
    assert ctx.client.get(f"/shop/{data['askID']}/status", headers=other).status_code == 404
    assert ctx.client.post(f"/shop/{data['askID']}/next", headers=other).status_code == 404
    assert ctx.client.get("/shop/unknown/status", headers=ctx.h).status_code == 404


def test_judge_reply_needs_admin_and_simulates_a_shop(ctx):
    data = make_ask(ctx)
    url = f"/judge/shop/{data['askID']}/reply"
    body = {"shopID": "s2", **reply_body()}
    assert ctx.client.post(url, json=body).status_code == 401
    assert ctx.client.post(url, json=body, headers=ctx.h).status_code == 401
    assert ctx.client.post(url, json=body, headers=ctx.admin).status_code == 200
    assert status(ctx, data["askID"])["winnerShopID"] == "s2"
    assert ctx.temporal.handles["shop-" + data["askID"]].signals == [("shop_reply", ["s2"])]
    assert ctx.client.post(url, json={"shopID": "s1", **reply_body()}, headers=ctx.admin).status_code == 409


def test_judge_cannot_reply_for_a_shop_not_asked_yet(ctx):
    data = make_ask(ctx)
    response = ctx.client.post(f"/judge/shop/{data['askID']}/reply", headers=ctx.admin,
                               json={"shopID": "s4", **reply_body()})
    assert response.status_code == 409
    assert ctx.client.post(f"/judge/shop/{data['askID']}/reply", headers=ctx.admin,
                           json={"shopID": "nope", **reply_body()}).status_code == 404


def test_delete_install_clears_that_installs_rows(ctx):
    mine = make_ask(ctx)
    theirs = ctx.client.post("/shop/ask", headers={"X-Test-Install": "inst-b"}, json=ask_body()).json()
    p3_db.delete_install("inst-a")
    assert p3_db.get_ask(mine["askID"]) is None
    assert p3_db.get_ask(theirs["askID"]) is not None
    with p3_db.connect() as conn:
        assert conn.execute("SELECT count(*) FROM shop_shops").fetchone()[0] == 4


# ---- workflow (time skipping) ----

@pytest.fixture(scope="module")
def temporal_env():
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


async def until(handle, predicate):
    last = None
    for _ in range(500):
        last = await handle.query("snapshot")
        if predicate(last):
            return last
        await asyncio.sleep(0.01)
    raise AssertionError(f"workflow did not reach expected state: {last}")


def start_ask(env, n_shops=4, wait=10, group=3):
    """Create the ask rows, run a worker, start the workflow. Returns (ask_id, handle, worker)."""
    body = shop.validate_ask(ask_body(n_shops, groupSize=group, waitMinutes=wait))
    ask_id, _ = p3_db.create_ask("inst-a", body)
    ids = [s["shopID"] for s in body["shops"]]
    queue = "shop-" + uuid4().hex
    worker = Worker(env.client, task_queue=queue, workflows=shop_workflows.WORKFLOWS,
                    activities=shop_workflows.ACTIVITIES)
    return ask_id, ids, queue, worker


def test_workflow_first_reply_wins(temporal_env, isolated_db):
    async def scenario(env):
        ask_id, ids, queue, worker = start_ask(env, 4, 10, 3)
        async with worker:
            handle = await env.client.start_workflow(
                "ShopAskWorkflow", {"ask_id": ask_id, "wait_minutes": 10, "time_scale": 1,
                                    "groups": p3_db.chunks(ids, 3)},
                id="shop-" + ask_id, task_queue=queue)
            first = p3_db.submit_reply(ask_id=ask_id, shop_id="s2", items=reply_body()["items"],
                                       ready_by=READY, via="judge")
            with pytest.raises(p3_db.ReplyError) as raised:
                p3_db.submit_reply(ask_id=ask_id, shop_id="s1", items=reply_body()["items"],
                                   ready_by=READY, via="judge")
            assert raised.value.code == "not_needed"
            await handle.signal("shop_reply", args=[first["shopID"]])
            result = await handle.result()
        assert result["state"] == "replied" and result["winnerShopID"] == "s2"
        states = {s["shopID"]: s["state"] for s in p3_db.ask_status(ask_id)["shops"]}
        assert states == {"s1": "not_needed", "s2": "replied", "s3": "not_needed", "s4": "not_asked"}
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_no_reply_in_wait_minutes_then_next_group(temporal_env, isolated_db):
    async def scenario(env):
        ask_id, ids, queue, worker = start_ask(env, 4, 10, 3)
        async with worker:
            handle = await env.client.start_workflow(
                "ShopAskWorkflow", {"ask_id": ask_id, "wait_minutes": 10, "time_scale": 1,
                                    "groups": p3_db.chunks(ids, 3)},
                id="shop-" + ask_id, task_queue=queue)
            await env.sleep(timedelta(minutes=9))
            assert (await handle.query("snapshot"))["noReply"] is False
            assert p3_db.ask_status(ask_id)["noReply"] is False
            await env.sleep(timedelta(minutes=2))
            snap = await until(handle, lambda s: s["noReply"])
            assert snap["nextGroup"] == ["s4"] and snap["round"] == 1 and snap["state"] == "waiting"
            st = p3_db.ask_status(ask_id)
            assert st["noReply"] is True and st["nextGroup"] == ["s4"]
            assert [s["state"] for s in st["shops"]] == ["no_reply"] * 3 + ["not_asked"]
            # POST /next: SQLite opens group 2, then the workflow is told
            round_no, links = p3_db.open_next(ask_id, "inst-a")
            assert round_no == 2 and [l["shopID"] for l in links] == ["s4"]
            await handle.signal("next_round", args=[2])
            snap = await until(handle, lambda s: s["round"] == 2)
            assert snap["noReply"] is False and snap["nextGroup"] == []
            reply = p3_db.submit_reply(token=links[0]["token"], items=reply_body()["items"], ready_by=READY)
            await handle.signal("shop_reply", args=[reply["shopID"]])
            result = await handle.result()
        assert result["winnerShopID"] == "s4" and result["state"] == "replied"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_closes_when_every_group_stays_silent(temporal_env, isolated_db):
    async def scenario(env):
        ask_id, ids, queue, worker = start_ask(env, 2, 5, 2)
        async with worker:
            handle = await env.client.start_workflow(
                "ShopAskWorkflow", {"ask_id": ask_id, "wait_minutes": 5, "time_scale": 1,
                                    "groups": p3_db.chunks(ids, 2)},
                id="shop-" + ask_id, task_queue=queue)
            result = await handle.result()  # time skipping runs the 5 minute timer
        assert result["state"] == "closed" and result["noReply"] is True and result["nextGroup"] == []
        st = p3_db.ask_status(ask_id)
        assert st["state"] == "closed" and st["noReply"] is True and "winnerShopID" not in st
        with pytest.raises(p3_db.ReplyError) as raised:
            p3_db.submit_reply(ask_id=ask_id, shop_id="s1", items=reply_body()["items"],
                               ready_by=READY, via="judge")
        assert raised.value.code == "closed"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_time_scale_shrinks_the_wait(temporal_env, isolated_db):
    async def scenario(env):
        ask_id, ids, queue, worker = start_ask(env, 4, 10, 3)
        async with worker:
            handle = await env.client.start_workflow(
                "ShopAskWorkflow", {"ask_id": ask_id, "wait_minutes": 10, "time_scale": 0.1,
                                    "groups": p3_db.chunks(ids, 3)},
                id="shop-" + ask_id, task_queue=queue)
            await env.sleep(timedelta(minutes=1, seconds=5))
            snap = await until(handle, lambda s: s["noReply"])
            assert snap["nextGroup"] == ["s4"]
            await handle.terminate("test cleanup")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_form_reposted_after_reply_says_already_sent_not_error(ctx):
    # K20: a phone reload of the thank-you page re-posts the form; the user must not see "Could not send".
    data = make_ask(ctx)
    t1 = token_of(data["replyLinks"][0])
    form = "a0=1&p0=12.50&a1=0&p1=&readyBy=18%3A30"
    headers = {"content-type": "application/x-www-form-urlencoded"}
    assert ctx.client.post("/shop/reply/" + t1, content=form, headers=headers).status_code == 200
    again = ctx.client.post("/shop/reply/" + t1, content=form, headers=headers)
    assert again.status_code == 409 and "already sent" in again.text and "Could not send" not in again.text
    assert shop_state(ctx, data["askID"], "s1")["items"][0]["pricePaise"] == 1250   # first reply untouched


def test_inputs_cannot_push_the_phone_page_sideways():
    # K20: a datetime-local input stuck out of its card at 390 px; labels wrap and inputs may shrink.
    assert "flex-wrap:wrap" in shop.CSS and "min-width:0" in shop.CSS
    assert "overflow-wrap:anywhere" in shop.CSS   # a 100-letter name without spaces was 1200 px wide
