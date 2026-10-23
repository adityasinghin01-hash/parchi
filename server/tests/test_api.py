import copy
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from temporalio.exceptions import WorkflowAlreadyStartedError
from temporalio.service import RPCError, RPCStatusCode

from conftest import line, plan, sellers


class FakeHandle:
    def __init__(self, data):
        self.data = data
        self.terminated = False
        self.signals = []

    async def query(self, name):
        return copy.deepcopy(self.data)

    async def signal(self, name, *, args):
        self.signals.append((name, args))

    async def terminate(self, reason):
        self.terminated = True


class MissingHandle:
    async def _gone(self, *args, **kwargs):
        raise RPCError("workflow not found", RPCStatusCode.NOT_FOUND, b"")

    query = signal = terminate = _gone


class FakeTemporal:
    def __init__(self):
        self.handles = {}
        self.service_client = SimpleNamespace(check_health=self.check_health)
        self.namespace = "default"
        self.deleted = []  # K30: workflow ids whose history was deleted
        self.workflow_service = SimpleNamespace(delete_workflow_execution=self.delete_workflow_execution)

    async def delete_workflow_execution(self, request):
        wid = request.workflow_execution.workflow_id
        if wid not in self.handles:
            raise RPCError("not found", RPCStatusCode.NOT_FOUND, b"")
        assert self.handles[wid].terminated, "Temporal refuses to delete a running workflow"
        self.deleted.append(wid)
        del self.handles[wid]

    async def check_health(self):
        return True

    async def start_workflow(self, name, data, *, id, **kwargs):
        if id in self.handles:
            raise WorkflowAlreadyStartedError(id, "OrderWorkflow")
        self.handles[id] = FakeHandle({
            "orderID": data["order_id"], "state": "placed", "planVersion": 1,
            "sellers": [{"id": sid, "status": "placed", "etaMinutes": 60}
                        for sid in dict.fromkeys(row["sellerID"] for row in data["plan"]["lines"])],
            "pending": None, "proposal": None, "nothingAvailable": False,
            "needsCheck": [], "waitingSince": None, "plan": data["plan"], "queue": [],
        })
        return self.handles[id]

    def get_workflow_handle(self, id):
        if id not in self.handles:  # like Temporal: the handle exists, every call on it says NOT_FOUND
            return MissingHandle()
        return self.handles[id]

    async def list_workflows(self, query):
        # Only refill watches are listed (the reset route asks for RefillWorkflow executions).
        for wid, handle in list(self.handles.items()):
            if wid.startswith("refill-") and not (handle.terminated and "Running" in query):
                yield SimpleNamespace(id=wid)


@pytest.fixture
def api_client(isolated_db, monkeypatch):
    import api
    import auth
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    install, key = auth.issue_key("phone one")
    other_install, other_key = auth.issue_key("phone two")
    temporal = FakeTemporal()
    api.app.state.temporal = temporal
    api.app.dependency_overrides[api.get_temporal] = lambda: temporal
    with TestClient(api.app) as client:
        yield SimpleNamespace(client=client, db=isolated_db, temporal=temporal,
                              install=install, key=key, other_install=other_install,
                              other_key=other_key)
    api.app.dependency_overrides.clear()
    auth.limiter.clear()


def headers(ctx, idem="request-1"):
    return {"X-Install-Key": ctx.key, "Idempotency-Key": idem}


def create(ctx, idem="request-1"):
    return ctx.client.post("/order", headers=headers(ctx, idem),
                           json={"plan": plan(), "sellers": sellers()})


@pytest.mark.parametrize("key", [None, "wrong"])
def test_missing_or_wrong_key(api_client, key):
    h = {} if key is None else {"X-Install-Key": key}
    assert api_client.client.post("/order", headers=h, json={}).status_code == 401


def test_rate_limit_request_121(api_client):
    for _ in range(120):
        assert api_client.client.get("/reliability?area=meerut", headers=headers(api_client)).status_code == 200
    response = api_client.client.get("/reliability?area=meerut", headers=headers(api_client))
    assert response.status_code == 429
    assert 1 <= int(response.headers["Retry-After"]) <= 60


def test_idempotent_order_even_after_completion(api_client):
    first = create(api_client)
    second = create(api_client)
    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json() == first.json()
    assert len(api_client.db.list_orders(api_client.install)) == 1


def test_idempotency_is_scoped_to_install(api_client):
    first = create(api_client).json()["orderID"]
    second = api_client.client.post("/order", headers={
        "X-Install-Key": api_client.other_key, "Idempotency-Key": "request-1"},
        json={"plan": plan(), "sellers": sellers()})
    assert second.status_code == 201
    assert second.json()["orderID"] != first


def test_owner_and_version_checks(api_client):
    oid = create(api_client).json()["orderID"]
    assert api_client.client.get(f"/status/{oid}", headers={
        "X-Install-Key": api_client.other_key}).status_code == 404
    for action in ("approve", "reject", "proposal"):
        body = {"planVersion": 0}
        if action == "proposal":
            body["proposal"] = {}
        response = api_client.client.post(f"/order/{oid}/{action}",
                                          headers=headers(api_client), json=body)
        assert response.status_code == 409
    assert api_client.client.get(f"/status/{oid}", headers=headers(api_client)).json()["audit"] == []


@pytest.mark.parametrize("path", ["/judge", "/judge/o/event", "/reset?scope=demo"])
def test_admin_rejects_install_key(api_client, path):
    if path == "/judge":
        response = api_client.client.get(path, headers=headers(api_client))
    else:
        response = api_client.client.post(path, headers=headers(api_client), json={})
    assert response.status_code == 401


def test_read_without_reader_is_503(api_client, monkeypatch):
    monkeypatch.delenv("PARCHI_READER_URL", raising=False)
    response = api_client.client.post("/read", headers=headers(api_client))
    assert response.status_code == 503
    assert response.json() == {"detail": "reader not connected"}


def test_reset_only_this_install(api_client):
    oid = create(api_client).json()["orderID"]
    other = api_client.client.post("/order", headers={
        "X-Install-Key": api_client.other_key, "Idempotency-Key": "r"},
        json={"plan": plan(), "sellers": sellers()}).json()["orderID"]
    for order in (oid, other):
        api_client.db.place_order(order, "s1", 1)
        api_client.db.add_audit(order, "test", "placed", {}, 1, 1)
        api_client.db.store_approval(order, 2, "test", "abc")
    response = api_client.client.post("/reset", headers=headers(api_client), json={})
    assert response.status_code == 200
    assert f"order-{oid}" in api_client.temporal.deleted  # terminated, then its history deleted
    assert f"order-{other}" in api_client.temporal.handles and not api_client.temporal.handles[f"order-{other}"].terminated
    assert api_client.db.list_orders(api_client.install) == []
    assert api_client.db.placements_for(oid) == []
    assert api_client.db.audit_for(oid) == []
    assert len(api_client.db.placements_for(other)) == 1
    assert len(api_client.db.audit_for(other)) == 1
    assert api_client.client.get(f"/status/{oid}", headers=headers(api_client)).status_code == 404
    with api_client.db.connect() as conn:
        assert conn.execute("SELECT count(*) FROM approvals").fetchone()[0] == 1


def test_reset_terminates_this_installs_refill_watches(api_client):
    """Codex R4: refill watches have no SQLite row, so reset must find and stop them in Temporal."""
    for wid, owner in (("refill-mine", api_client.install), ("refill-theirs", api_client.other_install)):
        api_client.temporal.handles[wid] = FakeHandle({"installID": owner, "state": "waiting"})
    assert api_client.client.post("/reset", headers=headers(api_client), json={}).status_code == 200
    assert "refill-mine" in api_client.temporal.deleted and "refill-mine" not in api_client.temporal.handles
    assert not api_client.temporal.handles["refill-theirs"].terminated
    assert api_client.client.post("/reset?scope=demo", headers={
        "X-Admin-Key": "judge-secret"}, json={}).status_code == 200
    assert "refill-theirs" in api_client.temporal.deleted


@pytest.mark.parametrize("price", [-1, 1.5, True, "100"])
def test_prices_are_strict_integer_paise(api_client, price):
    body = {"plan": plan(), "sellers": sellers()}
    body["plan"]["lines"][0]["price"] = price
    assert api_client.client.post("/order", headers=headers(api_client), json=body).status_code == 422


def test_order_validation(api_client):
    body = {"plan": plan(), "sellers": sellers()}
    assert api_client.client.post("/order", headers={"X-Install-Key": api_client.key},
                                  json=body).status_code == 422
    body["plan"] = plan([line(str(i)) for i in range(41)])
    assert api_client.client.post("/order", headers=headers(api_client), json=body).status_code == 422
    body["plan"] = plan([line(seller="missing")])
    assert api_client.client.post("/order", headers=headers(api_client), json=body).status_code == 422


def test_judge_and_demo_reset(api_client):
    oid = create(api_client).json()["orderID"]
    response = api_client.client.get("/judge", headers={"X-Admin-Key": "judge-secret"})
    assert response.status_code == 200
    assert "Test order" in response.text
    assert oid in response.text
    response = api_client.client.post(f"/judge/{oid}/event", headers={
        "X-Admin-Key": "judge-secret"}, json={"sellerID": "s1", "kind": "cancelled"})
    assert response.status_code == 200
    assert api_client.temporal.handles[f"order-{oid}"].signals == [
        ("seller_event", ["s1", "cancelled"])]
    assert api_client.client.post("/reset?scope=demo", headers={
        "X-Admin-Key": "judge-secret"}, json={}).status_code == 200
    assert api_client.db.list_orders() == []


def test_health(api_client):
    assert api_client.client.get("/health").json() == {"ok": True, "temporal": True}
