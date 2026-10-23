"""Codex review R8 row 9: a retried POST /lab/book (response lost) must return the SAME booking, never a second booking and workflow."""
import pytest

import p3_db
from test_lab import book_body, ctx, status  # noqa: F401  (reused fixture and helpers)


def post(ctx, headers=None, **extra):
    return ctx.client.post("/lab/book", headers={**ctx.h, **(headers or {})}, json=book_body(**extra))


def count_bookings():
    with p3_db.connect() as conn:
        return conn.execute("SELECT COUNT(*) FROM lab_bookings").fetchone()[0]


def test_same_key_returns_the_same_booking_and_link(ctx):
    first = post(ctx, {"Idempotency-Key": "k-1"})
    second = post(ctx, {"Idempotency-Key": "k-1"})
    assert first.status_code == 201 and second.status_code == 200
    assert first.json() == second.json()
    assert count_bookings() == 1 and len(ctx.temporal.started) == 1, "no second booking, token or workflow"
    token = first.json()["replyLink"].rsplit("/", 1)[1]
    assert ctx.client.get("/lab/reply/" + token).status_code == 200, "the link from the retry works"


def test_same_key_different_booking_is_refused(ctx):
    assert post(ctx, {"Idempotency-Key": "k-2"}).status_code == 201
    other = post(ctx, {"Idempotency-Key": "k-2"}, labName="Another Lab")
    assert other.status_code == 409 and count_bookings() == 1


def test_different_keys_and_different_installs_are_separate_bookings(ctx):
    a = post(ctx, {"Idempotency-Key": "k-3"}).json()["bookingID"]
    b = post(ctx, {"Idempotency-Key": "k-4"}).json()["bookingID"]
    c = ctx.client.post("/lab/book", headers={"X-Test-Install": "inst-b", "Idempotency-Key": "k-3"}, json=book_body()).json()["bookingID"]
    assert len({a, b, c}) == 3 and count_bookings() == 3


def test_old_clients_without_a_key_are_protected_too(ctx):
    first, second = post(ctx), post(ctx)
    assert first.json() == second.json() and second.status_code == 200 and count_bookings() == 1


def test_after_the_lab_answered_a_retry_returns_the_booking_without_a_link(ctx):
    first = post(ctx, {"Idempotency-Key": "k-5"}).json()
    token = first["replyLink"].rsplit("/", 1)[1]
    p3_db.lab_reply(token, "confirm")
    again = post(ctx, {"Idempotency-Key": "k-5"})
    assert again.status_code == 200 and again.json() == {"bookingID": first["bookingID"], "replyLink": None}
    assert status(ctx, first["bookingID"])["state"] == "confirmed"


def test_the_database_still_stores_only_a_hash_of_the_link(ctx):
    token = post(ctx, {"Idempotency-Key": "k-6"}).json()["replyLink"].rsplit("/", 1)[1]
    with p3_db.connect() as conn:
        dump = str(tuple(conn.execute("SELECT * FROM lab_bookings").fetchone()))
    assert token not in dump
