"""R8/10: count received bytes even for chunked or falsely small bodies."""
import json

import pytest

from conftest import plan, sellers
from test_api import api_client, create, headers  # noqa: F401


@pytest.mark.parametrize("path", ["/order", "/lab/book"])
@pytest.mark.parametrize("declared", [None, "3"])
def test_streamed_json_cannot_bypass_cap(api_client, path, declared):
    body = json.dumps({"padding": "x" * 1_100_000}).encode()
    chunks = (body[n:n + 65536] for n in range(0, len(body), 65536))
    h = {**headers(api_client), "Content-Type": "application/json"}
    if declared is not None:
        h["Content-Length"] = declared
    response = api_client.client.post(path, headers=h, content=chunks)
    assert response.status_code == 413
    assert response.json() == {"detail": "request body too large"}
    assert api_client.temporal.handles == {}


def test_streamed_order_within_cap_works(api_client):
    body = json.dumps({"plan": plan(), "sellers": sellers()}).encode()
    response = api_client.client.post("/order", headers={**headers(api_client), "Content-Type": "application/json"},
                                      content=iter([body[:20], body[20:]]))
    assert response.status_code == 201
