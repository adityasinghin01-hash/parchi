"""K22: the phone-browser scan-and-read test page (GET /judge/scan, POST /judge/scan/read)."""
import logging
import re
from pathlib import Path

import httpx
import pytest

import api
import scan_page
from test_api import api_client  # noqa: F401  (reused fixture)

ADMIN = {"X-Admin-Key": "judge-secret"}
XSS = "<img src=x onerror=alert(1)>"
SECRET_BYTES = b"\xff\xd8SECRET-PHOTO-BYTES"


@pytest.fixture
def reader(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://user:pw@reader.test:9000/read?token=abc")
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(200, json={"lines": [
            {"kind": "medicine", "name": XSS, "strength": "40", "quantity": 30, "schedule": "1-0-0"},
            {"kind": "test", "name": "HbA1c"}]})

    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(handler))
    return calls


def post(ctx, data=SECRET_BYTES, ctype="image/jpeg", headers=ADMIN):
    return ctx.client.post("/judge/scan/read", headers=headers, files={"image": ("p.jpg", data, ctype)})


def test_page_needs_the_admin_key(api_client):
    c = api_client.client
    assert c.get("/judge/scan").status_code == 401
    assert c.get("/judge/scan?k=wrong").status_code == 401
    assert c.get("/judge/scan", headers=ADMIN).status_code == 200  # the header works too, as for /judge


def test_page_content(api_client):
    r = api_client.client.get("/judge/scan?k=judge-secret")
    assert r.status_code == 200 and r.headers["content-type"].startswith("text/html")
    t = r.text
    assert "TEST PAGE: use test parchis only. This page does NOT hide the patient's name (the app does)." in t
    assert 'accept="image/*" capture="environment"' in t
    assert re.search(r'<input id="gal" type="file" accept="image/\*">', t)
    assert "Read this parchi" in t and "Try another photo" in t and "Nothing was found" in t
    assert "The reader is not connected yet" in t
    assert "2000" in t and "0.7" in t and "canvas" in t
    assert "judge-secret" not in t  # the key is never written into the page; the script reads it from the address
    assert r.headers["cache-control"] == "no-store"


def test_page_script_never_builds_html_and_makes_no_external_requests(api_client):
    t = api_client.client.get("/judge/scan?k=judge-secret").text
    script = t[t.index("<script>"):]
    for banned in ("innerHTML", "outerHTML", "insertAdjacentHTML", "document.write", "eval(", "new Function"):
        assert banned not in script
    assert "textContent" in script
    assert not re.findall(r'(?:src|href|action)\s*=\s*["\']?(?:https?:)?//', t)
    assert re.findall(r"https?://", script) == []
    assert "default-src 'none'" in api_client.client.get("/judge/scan?k=judge-secret").headers["content-security-policy"]


def test_read_needs_the_admin_header(api_client, reader):
    assert post(api_client, headers={}).status_code == 401
    assert post(api_client, headers={"X-Admin-Key": "wrong"}).status_code == 401
    assert post(api_client, headers={"X-Install-Key": api_client.key}).status_code == 401  # an app key is not enough
    assert api_client.client.post("/judge/scan/read?k=judge-secret",
                                  files={"image": ("p.jpg", b"x", "image/jpeg")}).status_code == 401
    assert reader == []


def test_read_without_a_reader_is_503(api_client, monkeypatch):
    monkeypatch.delenv("PARCHI_READER_URL", raising=False)
    r = post(api_client)
    assert r.status_code == 503 and r.json() == {"detail": "reader not connected"}


def test_read_success_shape_and_forwarding(api_client, reader):
    r = post(api_client)
    assert r.status_code == 200
    body = r.json()
    assert set(body) == {"lines", "ms", "reader"}
    assert body["reader"] == "reader.test:9000"  # host:port only: no user, password, path or query
    assert isinstance(body["ms"], int) and body["ms"] >= 0
    assert body["lines"][1] == {"kind": "test", "name": "HbA1c"}
    assert len(reader) == 1 and SECRET_BYTES in reader[0].content
    assert reader[0].url.host == "reader.test" and reader[0].url.port == 9000


def test_xss_in_a_reader_name_is_returned_as_data(api_client, reader):
    assert post(api_client).json()["lines"][0]["name"] == XSS


def test_empty_lines_are_passed_through(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(200, json={"lines": []})))
    r = post(api_client)
    assert r.status_code == 200 and r.json()["lines"] == [] and r.json()["reader"] == "reader.test"


def test_oversize_is_413_and_nothing_reaches_the_reader(api_client, reader):
    assert post(api_client, data=b"x" * 2_000_001).status_code == 413
    assert reader == []
    assert post(api_client, data=b"\xff\xd8" + b"x" * 1_900_000).status_code == 200  # 1-2 MB photos are accepted
    assert post(api_client, data=b"x" * 2_000_000).status_code == 200


def test_oversize_by_declared_length_is_413(api_client, reader):
    r = api_client.client.post("/judge/scan/read", headers={**ADMIN, "Content-Type": "multipart/form-data; boundary=b"},
                               content=b"x" * 2_100_000)
    assert r.status_code == 413 and reader == []


def test_non_image_is_415(api_client, reader):
    assert post(api_client, ctype="text/plain").status_code == 415
    assert post(api_client, ctype="application/pdf").status_code == 415
    r = api_client.client.post("/judge/scan/read", headers=ADMIN, data={"image": "just text"})
    assert r.status_code == 415
    assert reader == []


def test_chunked_upload_without_a_length_is_411(api_client, reader):
    def chunks():
        yield b"--b\r\n"
        yield b"x" * 100

    r = api_client.client.post("/judge/scan/read", headers={**ADMIN, "Content-Type": "multipart/form-data; boundary=b"},
                               content=chunks())
    assert r.status_code == 411 and reader == []


def test_reader_down_is_503_and_reader_error_is_502(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")

    def boom(request):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(boom))
    assert post(api_client).json() == {"detail": "reader not connected"}
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(500, text="boom")))
    r = post(api_client)
    assert r.status_code == 502 and r.json() == {"detail": "reader error"}
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(200, text="not json")))
    assert post(api_client).status_code == 502
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(200, json=[1])))
    assert post(api_client).status_code == 502


def test_other_routes_keep_the_1_mb_limit_and_read_is_unchanged(api_client, reader):
    r = api_client.client.post("/judge/scan", content=b"x" * 1_100_000)
    assert r.status_code == 413
    r = api_client.client.post("/read", headers={"X-Install-Key": api_client.key},
                               files={"image": ("p.jpg", b"\xff\xd8x", "image/jpeg")})
    assert r.status_code == 200 and set(r.json()) == {"lines"}  # /read does not get ms/reader


def test_no_photo_lines_or_keys_in_the_logs(api_client, reader, caplog):
    with caplog.at_level(logging.DEBUG):
        assert post(api_client).status_code == 200
        api_client.client.get("/judge/scan?k=judge-secret")
        post(api_client, ctype="text/plain")
    # The httpx/httpx2 logger here is the TEST client's own request log (the real server runs with --no-access-log).
    text = "\n".join(r.getMessage() for r in caplog.records if r.name not in ("httpx", "httpx2"))
    assert "scan" not in text
    assert "SECRET-PHOTO-BYTES" not in text and "HbA1c" not in text and XSS not in text
    assert "judge-secret" not in text and "user:pw" not in text and "token=abc" not in text


def test_nothing_is_written_to_disk(api_client, reader, tmp_path, monkeypatch):
    import os
    work = tmp_path / "cwd"
    work.mkdir()
    monkeypatch.chdir(work)
    post(api_client)
    assert list(work.iterdir()) == []
    assert scan_page.reader_label("http://u:p@10.0.0.5:9000/x?y=1") == "10.0.0.5:9000"
    assert scan_page.reader_label("http://localhost/read") == "localhost"
    assert os.environ.get("PARCHI_READER_URL")


# ------------------------------------------------------------------ K28/17: stale answers are ignored
def test_script_guards_against_stale_answers(api_client):
    t = api_client.client.get("/judge/scan?k=judge-secret").text
    script = t[t.index("<script>"):]
    assert "var seq = 0" in script
    assert script.count("++seq") >= 3                       # chosen(), read(), "Try another photo"
    assert script.count("mine !== seq") >= 4 and "if (mine === seq) { inflight = null; busy = false;" in script   # prepare, reply, both catches, finally
    assert "inflight.abort()" in script                     # choosing another photo cancels the request in flight
    reply_at = script.index("raw = await r.text()")
    assert script.index("if (mine !== seq) return;", reply_at) < script.index("show(data", reply_at), \
        "the stale check must come before anything is shown"
    assert "fd.append('image', sent" in script              # the photo that was clicked is the photo that is sent


def test_scan_page_waits_65_seconds_and_server_60(api_client):
    t = api_client.client.get("/judge/scan?k=judge-secret").text
    assert "READ_WAIT_MS = 65000" in t and "no answer after 65 seconds" in t and "40000" not in t


def test_reader_wait_defaults_to_60_seconds_on_read_and_scan(api_client, monkeypatch):
    seen = []
    real = httpx.AsyncClient

    def spy(*args, **kwargs):
        seen.append(kwargs.get("timeout"))
        return real(*args, **kwargs)

    monkeypatch.delenv("PARCHI_READER_TIMEOUT", raising=False)
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(200, json={"lines": []})))
    monkeypatch.setattr(httpx, "AsyncClient", spy)
    assert post(api_client).status_code == 200
    r = api_client.client.post("/read", headers={"X-Install-Key": api_client.key},
                               files={"image": ("p.jpg", b"\xff\xd8x", "image/jpeg")})
    assert r.status_code == 200
    assert seen == [60.0, 60.0]
    monkeypatch.setenv("PARCHI_READER_TIMEOUT", "75")
    post(api_client)
    assert seen[-1] == 75.0


PW_PYTHON = Path.home() / "pw-venv2" / "bin" / "python"

PW_SCRIPT = r"""
import asyncio, json, struct, sys, zlib
from playwright.async_api import async_playwright

def png(w, h):
    raw = b"".join(b"\x00" + b"".join(bytes([(x * 7 + y) % 256, 90, 160]) for x in range(w)) for y in range(h))
    def chunk(t, d): c = struct.pack(">I", len(d)) + t + d; return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

async def main():
    html = open(sys.argv[1], encoding="utf8").read()
    headers = json.loads(sys.argv[2])
    requests = []
    async with async_playwright() as pw:
        browser = await pw.chromium.launch()
        page = await browser.new_page()
        async def route(r):
            url = r.request.url
            if url.endswith("/judge/scan/read"):
                n = len(requests); requests.append(n)
                if n == 0:
                    await asyncio.sleep(2.0)   # photo A: a slow reading
                    body = {"lines": [{"kind": "medicine", "name": "A-LIST-MEDICINE"}], "ms": 2000, "reader": "x"}
                else:
                    body = {"lines": [{"kind": "medicine", "name": "B-LIST-MEDICINE"}], "ms": 50, "reader": "x"}
                await r.fulfill(status=200, content_type="application/json", body=json.dumps(body))
            else:
                await r.fulfill(status=200, headers=headers, body=html)
        await page.route("**/*", route)
        await page.goto("http://scan.test/judge/scan?k=k")
        async def until(check, seconds=10):   # the page's CSP forbids eval, so no wait_for_function
            for _ in range(int(seconds * 20)):
                if await check():
                    return
                await asyncio.sleep(0.05)
            raise SystemExit("timed out")
        async def reading():
            return (await page.text_content("#status")).startswith("Reading")
        async def choose(w, h):
            await page.set_input_files("#gal", {"name": "p.png", "mimeType": "image/png", "buffer": png(w, h)})
            await until(lambda: page.locator("#read").is_enabled())
        await choose(40, 30)                                   # photo A
        await page.click("#read")                              # slow reading starts
        await until(lambda: reading())
        await choose(60, 45)                                   # photo B chosen while A is being read
        preview_b = await page.text_content("#size")
        await asyncio.sleep(2.6)                               # A's answer arrives now
        out = {"after_stale": await page.inner_text("#result"), "status": await page.text_content("#status"),
               "size_unchanged": preview_b == await page.text_content("#size"),
               "read_enabled": await page.eval_on_selector("#read", "e => !e.disabled")}
        await page.click("#read")                              # now read B
        await page.wait_for_selector("#result table")
        out["b_result"] = await page.inner_text("#result")
        out["requests"] = len(requests)
        await browser.close()
    print("RESULT" + json.dumps(out))

asyncio.run(main())
"""


@pytest.mark.skipif(not PW_PYTHON.exists(), reason="~/pw-venv2 (Playwright) is not on this computer")
def test_browser_slow_answer_for_photo_a_is_not_shown_under_photo_b(tmp_path):
    import json
    import subprocess
    (tmp_path / "page.html").write_text(scan_page.PAGE, encoding="utf-8")
    (tmp_path / "check.py").write_text(PW_SCRIPT, encoding="utf-8")
    done = subprocess.run([str(PW_PYTHON), str(tmp_path / "check.py"), str(tmp_path / "page.html"), json.dumps(scan_page.HEADERS)],
                          capture_output=True, text=True, timeout=120)
    line = next((ln for ln in done.stdout.splitlines() if ln.startswith("RESULT")), None)
    assert line, done.stdout + done.stderr
    out = json.loads(line[len("RESULT"):])
    assert "A-LIST-MEDICINE" not in out["after_stale"] and out["after_stale"].strip() == "", out
    assert not out["status"].startswith("Reading") and out["size_unchanged"] and out["read_enabled"], out
    assert "B-LIST-MEDICINE" in out["b_result"] and "A-LIST-MEDICINE" not in out["b_result"] and out["requests"] == 2, out
