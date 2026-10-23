"""R8/15: absurd supply/date horizons return 422 instead of overflowing."""
import pytest
from test_api import api_client, headers  # noqa: F401


@pytest.mark.parametrize("quantity,doses,start", [
    (100000, .000000001, "2026-10-24"), (367, 1, "2026-10-24"),
    (1, 1, "9999-12-31"), (0, 1, "0001-01-01"),
])
def test_overflowing_or_overlong_refill_is_cleanly_rejected(api_client, quantity, doses, start):
    response = api_client.client.post("/refill/watch", headers=headers(api_client), json={
        "startDate": start, "items": [{"name": "A", "quantity": quantity, "dosesPerDay": doses}]})
    assert response.status_code == 422
    assert not api_client.temporal.handles
