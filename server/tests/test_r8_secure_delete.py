"""R8/16: deleting a booking removes its private text from SQLite and WAL bytes."""
from pathlib import Path
import os
import sqlite3

from test_api import api_client, FakeHandle, headers  # noqa: F401
from test_lab import book_body


def test_reset_erases_booking_text_from_database_and_wal(api_client, monkeypatch):
    marker = "PRIVATE-ADDRESS-ERASURE-MARKER-83c59f"

    async def start(name, data, *, id, **kwargs):
        api_client.temporal.handles[id] = FakeHandle({})

    monkeypatch.setattr(api_client.temporal, "start_workflow", start)
    path = Path(os.environ["PARCHI_DB"])
    # Keep a second connection open so SQLite does not auto-checkpoint away the WAL
    # when the request's short-lived connection closes.
    keeper = sqlite3.connect(path)
    try:
        assert api_client.client.post("/lab/book", headers=headers(api_client),
                                      json=book_body(addressText=marker)).status_code == 201
        before = b"".join(p.read_bytes() for p in (path, Path(str(path) + "-wal")) if p.exists())
        assert marker.encode() in before, "the test must first prove its marker was stored"
        assert api_client.client.post("/reset", headers=headers(api_client), json={}).status_code == 200
        after = b"".join(p.read_bytes() for p in (path, Path(str(path) + "-wal")) if p.exists())
        assert marker.encode() not in after
    finally:
        keeper.close()
