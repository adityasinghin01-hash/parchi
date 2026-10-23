"""K31 item 1: the judge key leaves the URL. Login form, opaque session cookie, header-or-cookie auth, CSRF guard,
the one-time ?k= bridge, logout and expiry."""
import re
import time

import pytest

import auth
from test_api import api_client, create, headers  # noqa: F401

KEY = "judge-secret"
PAGES = ["/judge", "/judge/scan"]
JSON_GET = ["/judge/orders", "/judge/shop/asks", "/judge/lab/bookings"]


@pytest.fixture(autouse=True)
def clean_sessions():
    auth.clear_sessions()
    yield
    auth.clear_sessions()


def login(ctx, key=KEY, **extra):
    return ctx.client.post("/judge/login", data={"key": key, **extra}, follow_redirects=False)


def cookie_of(response):
    return response.headers.get("set-cookie", "")


def test_login_form_is_plain_html_without_external_assets(api_client):
    r = api_client.client.get("/judge/login")
    assert r.status_code == 200 and "text/html" in r.headers["content-type"]
    assert 'type="password"' in r.text and 'method="post"' in r.text
    assert not re.search(r'(src|href)="https?://', r.text) and "<script" not in r.text
    assert "default-src 'none'" in r.headers["content-security-policy"]
    assert r.headers["cache-control"] == "no-store"


def test_good_key_sets_a_session_cookie_and_303s(api_client):
    r = login(api_client)
    assert r.status_code == 303 and r.headers["location"] == "/judge"
    c = cookie_of(r)
    assert c.startswith("parchi_judge=")
    for flag in ("HttpOnly", "SameSite=Strict", "Path=/judge", "Max-Age=43200"):
        assert flag in c
    token = c.split(";")[0].split("=", 1)[1]
    assert len(token) >= 32 and KEY not in c and auth.digest(KEY) not in c  # opaque, never the key
    assert login(api_client).headers["set-cookie"].split(";")[0] != c.split(";")[0]  # random per login


def test_next_is_limited_to_the_judge_pages(api_client):
    assert login(api_client, next="/judge/scan").headers["location"] == "/judge/scan"
    for evil in ("https://evil.example/", "//evil.example", "/reset", "/judge/../x"):
        assert login(api_client, next=evil).headers["location"] == "/judge"


def test_wrong_key_is_401_with_no_cookie(api_client):
    for bad in ("wrong", "", "judge-secre", "ключ"):
        r = login(api_client, bad)
        assert r.status_code == 401 and "set-cookie" not in r.headers and "Wrong key" in r.text
    assert api_client.client.post("/judge/login", data={}, follow_redirects=False).status_code == 401
    assert api_client.client.post("/judge/login", json={"key": KEY}, follow_redirects=False).status_code == 401
    assert "parchi_judge" not in api_client.client.cookies


def test_login_failures_are_rate_limited_like_failed_auth(api_client):
    codes = [login(api_client, f"bad{n}").status_code for n in range(auth.FAIL_LIMIT + 3)]
    assert codes[:auth.FAIL_LIMIT] == [401] * auth.FAIL_LIMIT and codes[-1] == 429
    assert login(api_client, "still wrong").status_code == 429  # more guesses are refused until the minute is over
    assert login(api_client).status_code == 303                # the right key is never locked out (as for install keys)


def test_cookie_opens_every_judge_route_header_still_works(api_client):
    c = api_client.client
    assert login(api_client).status_code == 303
    for path in PAGES + JSON_GET:
        assert c.get(path).status_code == 200, path
    c.cookies.clear()
    for path in PAGES + JSON_GET:
        assert c.get(path, headers={"X-Admin-Key": KEY}).status_code == 200, path


def test_no_credentials_wrong_header_and_install_key_are_refused(api_client):
    c = api_client.client
    for path in JSON_GET + PAGES:
        assert c.get(path).status_code == 401
        assert c.get(path, headers={"X-Admin-Key": "wrong"}).status_code == 401
        assert c.get(path, headers={"X-Install-Key": api_client.key}).status_code == 401
    login(api_client)
    # A wrong header does not fall back to the (valid) cookie.
    assert c.get("/judge/shop/asks", headers={"X-Admin-Key": "wrong"}).status_code == 401
    # A made-up cookie is not a session.
    c.cookies.clear()
    c.cookies.set("parchi_judge", "A" * 43, path="/judge")
    assert c.get("/judge/shop/asks").status_code == 401


def test_a_browser_without_a_session_is_sent_to_the_login_form(api_client):
    r = api_client.client.get("/judge", headers={"Accept": "text/html,application/xhtml+xml"}, follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == "/judge/login?next=%2Fjudge"
    r = api_client.client.get("/judge/scan", headers={"Accept": "text/html"}, follow_redirects=False)
    assert r.headers["location"] == "/judge/login?next=%2Fjudge%2Fscan"
    # scripts keep the plain 401; JSON routes never redirect
    assert api_client.client.get("/judge", headers={"Accept": "text/html", "X-Admin-Key": "wrong"}).status_code == 401
    assert api_client.client.get("/judge/orders", headers={"Accept": "text/html"}, follow_redirects=False).status_code == 401


@pytest.mark.parametrize("path", PAGES)
def test_k_in_the_url_is_a_one_time_bridge(api_client, path):
    r = api_client.client.get(f"{path}?k={KEY}", follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == path and "k=" not in r.headers["location"]
    assert cookie_of(r).startswith("parchi_judge=") and KEY not in cookie_of(r)
    assert api_client.client.get(path).status_code == 200  # the cookie now does the work
    # other query parameters survive, k does not
    r = api_client.client.get(f"{path}?k={KEY}&x=1", follow_redirects=False)
    assert r.headers["location"] == f"{path}?x=1"


@pytest.mark.parametrize("path", PAGES)
def test_a_wrong_k_is_401_and_sets_nothing(api_client, path):
    r = api_client.client.get(f"{path}?k=wrong", follow_redirects=False)
    assert r.status_code == 401 and "set-cookie" not in r.headers
    assert api_client.client.get(path).status_code == 401


def test_k_never_authenticates_the_json_routes(api_client):
    for path in JSON_GET:
        assert api_client.client.get(f"{path}?k={KEY}", follow_redirects=False).status_code == 401


def test_bad_k_attempts_are_throttled(api_client):
    codes = [api_client.client.get(f"/judge?k=bad{n}", follow_redirects=False).status_code
             for n in range(auth.FAIL_LIMIT + 2)]
    assert codes[0] == 401 and codes[-1] == 429


def test_cookie_posts_need_the_csrf_header(api_client):
    oid = create(api_client).json()["orderID"]
    login(api_client)
    c, body = api_client.client, {"sellerID": "s1", "kind": "confirmed"}
    r = c.post(f"/judge/{oid}/event", json=body)
    assert r.status_code == 403 and "X-Parchi-Judge" in r.json()["detail"]
    assert api_client.temporal.handles["order-" + oid].signals == []
    assert c.post(f"/judge/{oid}/event", json=body, headers={"X-Parchi-Judge": "0"}).status_code == 403
    assert c.post(f"/judge/{oid}/event", json=body, headers={"X-Parchi-Judge": "1"}).status_code == 200
    assert api_client.temporal.handles["order-" + oid].signals == [("seller_event", ["s1", "confirmed"])]
    # shop reply, lab event and the scan upload are guarded the same way
    assert c.post("/judge/shop/x/reply", json={}).status_code == 403
    assert c.post("/judge/lab/x/event", json={}).status_code == 403
    assert c.post("/judge/scan/read", content=b"x").status_code == 403


def test_header_posts_do_not_need_the_csrf_header(api_client):
    oid = create(api_client).json()["orderID"]
    r = api_client.client.post(f"/judge/{oid}/event", json={"sellerID": "s1", "kind": "confirmed"},
                               headers={"X-Admin-Key": KEY})
    assert r.status_code == 200


def test_logout_ends_the_session_and_clears_the_cookie(api_client):
    c = api_client.client
    login(api_client)
    assert c.get("/judge/shop/asks").status_code == 200
    token = c.cookies.get("parchi_judge")
    assert c.post("/judge/logout").status_code == 403           # the cookie needs the header here too
    r = c.post("/judge/logout", headers={"X-Parchi-Judge": "1"})
    assert r.status_code == 200 and "Max-Age=0" in cookie_of(r)
    c.cookies.set("parchi_judge", token, path="/judge")         # a copy of the old cookie is dead now
    assert c.get("/judge/shop/asks").status_code == 401
    assert c.post("/judge/logout", headers={"X-Parchi-Judge": "1"}).status_code == 200  # idempotent


def test_sessions_expire_after_twelve_hours(api_client, monkeypatch):
    c = api_client.client
    login(api_client)
    assert c.get("/judge/shop/asks").status_code == 200
    real = time.time
    monkeypatch.setattr(auth.time, "time", lambda: real() + auth.SESSION_SECONDS - 5)
    assert c.get("/judge/shop/asks").status_code == 200
    monkeypatch.setattr(auth.time, "time", lambda: real() + auth.SESSION_SECONDS + 5)
    assert c.get("/judge/shop/asks").status_code == 401
    assert auth.SESSION_SECONDS == 12 * 3600


def test_a_restart_forgets_every_session(api_client):
    login(api_client)
    assert api_client.client.get("/judge/shop/asks").status_code == 200
    auth.clear_sessions()  # what a new process starts with
    assert api_client.client.get("/judge/shop/asks").status_code == 401


def test_session_table_is_bounded(api_client):
    for _ in range(auth.SESSION_MAX + 20):
        auth.create_session()
    assert len(auth._sessions) <= auth.SESSION_MAX


def test_judge_page_scripts_never_read_the_key_from_the_url(api_client):
    login(api_client)
    page = api_client.client.get("/judge").text
    assert "location.search" not in page and "X-Admin-Key" not in page and "'k'" not in page
    assert "X-Parchi-Judge" in page and 'id="logout"' in page
    scan = api_client.client.get("/judge/scan").text
    assert "location.search" not in scan and "X-Admin-Key" not in scan and "X-Parchi-Judge" in scan
    assert api_client.client.get("/judge").headers["referrer-policy"] == "no-referrer"


def test_install_endpoints_ignore_the_judge_cookie(api_client):
    login(api_client)
    assert api_client.client.post("/reset?scope=demo").status_code == 401   # path /reset gets no cookie, header only
    assert api_client.client.get("/status/abc").status_code == 401
