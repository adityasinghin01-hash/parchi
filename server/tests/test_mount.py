import api


def openapi_paths():
    # include_router() wraps routes, so read the generated OpenAPI document instead of app.routes
    return api.app.openapi()["paths"]


def test_v2_routes_are_mounted():
    p = openapi_paths()
    for path in ["/shop/ask", "/lab/book", "/reliability", "/judge/reliability/record", "/refill/watch", "/true_price"]:
        assert path in p, path
    assert any(k.startswith("/refill/") and k.endswith("/status") for k in p)
    assert any(k.startswith("/orders/") and k.endswith("/paid") for k in p)


def test_order_routes_still_there():
    p = openapi_paths()
    assert "/order" in p and "/status/{order_id}" in p and "/judge/{order_id}/event" in p and "/judge/orders" in p
