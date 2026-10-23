"""R8/13: private/unknown fields never enter persisted Temporal inputs or signals."""
import copy

from conftest import plan, sellers, proposal
from test_api import api_client, headers, create  # noqa: F401


def test_order_workflow_input_drops_unrecognised_fields(api_client, monkeypatch):
    received = []
    start = api_client.temporal.start_workflow

    async def capture(name, data, **kwargs):
        received.append(copy.deepcopy(data))
        return await start(name, data, **kwargs)

    monkeypatch.setattr(api_client.temporal, "start_workflow", capture)
    p, s = plan(), sellers()
    p["patientName"] = "PRIVATE-MARKER"
    p["lines"][0]["phone"] = "PRIVATE-MARKER"
    s[0]["address"] = "PRIVATE-MARKER"
    response = api_client.client.post("/order", headers=headers(api_client), json={"plan": p, "sellers": s})
    assert response.status_code == 201
    assert "PRIVATE-MARKER" not in repr(received)
    assert received[0]["plan"] == plan()
    assert received[0]["sellers"] == sellers()


def test_proposal_signal_drops_unrecognised_nested_fields(api_client):
    oid = create(api_client).json()["orderID"]
    handle = api_client.temporal.handles["order-" + oid]
    handle.data.update(state="needs_proposal", pending={"sellerID": "s1", "failure": "cancelled"})
    p = proposal()
    p["patientName"] = "PRIVATE-MARKER"
    p["rerouted"][0]["phone"] = "PRIVATE-MARKER"
    p["newPlan"]["lines"][0]["address"] = "PRIVATE-MARKER"
    response = api_client.client.post(f"/order/{oid}/proposal", headers=headers(api_client),
                                      json={"planVersion": 1, "proposal": p})
    assert response.status_code == 200
    assert "PRIVATE-MARKER" not in repr(handle.signals)
