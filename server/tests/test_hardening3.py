"""Round 3 (Codex review of shop/lab): retry after a lost order signal, chunked-body cap."""
from test_lab import book, ctx, judge, status  # noqa: F401  (fixture + helpers reused)


def test_retry_after_a_lost_order_signal_resends_instead_of_409(ctx):
    ctx.db.reserve_order("order1", "inst-a")
    bid = book(ctx, orderID="order1", sellerID="lab-seller")["bookingID"]
    judge(ctx, bid, "confirmed")
    judge(ctx, bid, "collected")
    ctx.temporal.handles["order-order1"].broken = True            # the order workflow cannot be signalled right now
    first = judge(ctx, bid, "sample_rejected")
    assert first.status_code == 502                               # state committed, order not told
    assert status(ctx, bid)["state"] == "rejected"
    ctx.temporal.handles["order-order1"].broken = False           # it recovers; the judge presses the button again
    again = judge(ctx, bid, "sample_rejected")
    assert again.status_code == 200 and again.json()["retried"] is True and again.json()["orderSignalled"] is True
    assert ctx.temporal.handles["order-order1"].signals == [("seller_event", ["lab-seller", "sampleRejected"])]


def test_other_conflicts_are_still_409(ctx):
    bid = book(ctx)["bookingID"]
    assert judge(ctx, bid, "phlebotomist_late").status_code == 409   # not confirmed yet: a real conflict, not a retry


def test_chunked_body_is_capped_without_content_length():
    import asyncio

    import pytest
    from fastapi import HTTPException
    from starlette.requests import Request

    import shop

    async def run():
        chunks = [{"type": "http.request", "body": b"x" * 4096, "more_body": True} for _ in range(40)]
        chunks.append({"type": "http.request", "body": b"", "more_body": False})
        it = iter(chunks)

        async def receive():
            return next(it)

        scope = {"type": "http", "method": "POST", "headers": [(b"content-type", b"application/json")], "path": "/x"}
        await shop.read_body(Request(scope, receive))

    with pytest.raises(HTTPException) as caught:
        asyncio.run(run())
    assert caught.value.status_code == 413
