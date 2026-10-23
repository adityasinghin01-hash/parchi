"""A rejected commit-time approval must not lock a newer proposal on the same plan."""
from test_api import api_client, create, headers  # noqa: F401


def test_new_proposal_after_target_became_unavailable_can_be_approved(api_client):
    oid = create(api_client).json()["orderID"]
    handle = api_client.temporal.handles["order-" + oid]
    handle.data.update(state="awaiting_approval", proposal={"proposalID": "1-1"})

    def approve(pid, key):
        return api_client.client.post(f"/order/{oid}/approve", headers=headers(api_client, key),
                                      json={"planVersion": 1, "proposalID": pid})

    assert approve("1-1", "first").status_code == 200
    # The workflow's reroute re-check discards this proposal without changing planVersion.
    handle.data.update(state="needs_proposal", proposal=None)
    handle.data.update(state="awaiting_approval", proposal={"proposalID": "1-2"})
    assert approve("1-2", "second").status_code == 200
    assert approve("1-2", "third").status_code == 409
    assert approve("1-1", "first").status_code == 200  # exact old retry still returns its first answer
    assert [name for name, _ in handle.signals] == ["approve", "approve"]
