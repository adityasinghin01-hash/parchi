"""Judge login (K31): the admin key is typed into a form once and never appears in a URL again.

GET /judge/login      small HTML form (no external assets).
POST /judge/login     key from the form -> constant-time compare -> random server-side session cookie
                      (HttpOnly, SameSite=Strict, Path=/judge, 12 h, opaque token, kept in memory).
POST /judge/logout    drops the session and clears the cookie.
bridge (middleware)   an old bookmark GET /judge?k=<key> or /judge/scan?k=<key> sets the cookie and answers 303 to the
                      same path WITHOUT k, so the key leaves the address bar at once. Pages only: the JSON routes
                      under /judge take the X-Admin-Key header or the cookie, never ?k=.
admin_page            dependency for the two HTML pages: a browser without a session is sent to the login form.
"""
import html
from urllib.parse import urlencode

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse

import auth

router = APIRouter()

PAGES = ("/judge", "/judge/scan")   # the only places the ?k= bridge and the login redirect apply
HEADERS = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": ("default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; "
                                "form-action 'self'; frame-ancestors 'none'"),
}

LOGIN = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Parchi judge login</title>
<style>
body{font:17px/1.4 system-ui,sans-serif;margin:0;padding:16px;max-width:420px}
h1{font-size:1.3em}label{display:block;font-weight:600;margin:12px 0 4px}
input[type=password]{box-sizing:border-box;width:100%;font-size:1em;padding:12px;border:2px solid #888;border-radius:8px}
button{box-sizing:border-box;width:100%;min-height:48px;margin-top:14px;font-size:1em;font-weight:600;
 border:2px solid #1a56db;border-radius:10px;background:#1a56db;color:#fff}
.err{color:#b00020;font-weight:600}
</style></head><body>
<h1>Parchi judge login</h1>
<!--ERROR-->
<form method="post" action="/judge/login">
<input type="hidden" name="next" value="<!--NEXT-->">
<label for="key">Admin key</label>
<input id="key" name="key" type="password" autocomplete="off" required autofocus>
<button type="submit">Log in</button>
</form>
</body></html>
"""


def safe_next(value: object) -> str:
    return value if isinstance(value, str) and value in PAGES else "/judge"


def login_page(next_path: str, error: str = "", status: int = 200) -> HTMLResponse:
    body = LOGIN.replace("<!--NEXT-->", html.escape(next_path, quote=True))
    body = body.replace("<!--ERROR-->", f'<p class="err" role="alert">{html.escape(error)}</p>' if error else "")
    return HTMLResponse(body, status_code=status, headers=HEADERS)


def start_session(location: str) -> RedirectResponse:
    response = RedirectResponse(location, status_code=303, headers={"Cache-Control": "no-store",
                                                                    "Referrer-Policy": "no-referrer"})
    response.headers.append("Set-Cookie", auth.session_cookie(auth.create_session()))
    return response


def admin_page(request: Request) -> None:
    """Dependency for the HTML pages: header or session as everywhere; a browser without either goes to the form."""
    try:
        auth.require_admin(request)
    except HTTPException as error:
        if (error.status_code == 401 and request.headers.get("X-Admin-Key") is None
                and "text/html" in request.headers.get("accept", "")):
            raise HTTPException(303, "login required", headers={"Location": "/judge/login?" + urlencode(
                {"next": safe_next(request.url.path)})})
        raise


@router.get("/judge/login", response_class=HTMLResponse)
async def login_form(next: str = "/judge") -> HTMLResponse:
    return login_page(safe_next(next))


@router.post("/judge/login")
async def login(request: Request) -> HTMLResponse:
    try:
        form = await request.form()
    except Exception:
        form = {}
    key, next_path = form.get("key"), safe_next(form.get("next"))
    if not isinstance(key, str) or not auth.admin_key_ok(key):
        auth.fail_login(request)   # 429 after too many wrong keys from one address
        return login_page(next_path, "Wrong key.", 401)
    return start_session(next_path)


@router.post("/judge/logout")
async def logout(request: Request) -> JSONResponse:
    token = request.cookies.get(auth.SESSION_COOKIE)
    if auth.session_ok(token) and request.headers.get(auth.CSRF_HEADER) != "1":
        raise HTTPException(403, "missing X-Parchi-Judge header")
    auth.drop_session(token)
    return JSONResponse({"ok": True}, headers={"Set-Cookie": auth.session_cookie("", 0), "Cache-Control": "no-store"})


async def bridge(request: Request, call_next):
    """HTTP middleware: GET /judge?k=<key> -> cookie + 303 to /judge (same path, no k)."""
    if request.method == "GET" and request.url.path in PAGES and "k" in request.query_params:
        if not auth.admin_key_ok(request.query_params["k"]):
            try:
                auth.fail_login(request)
            except HTTPException as error:
                return JSONResponse({"detail": error.detail}, status_code=error.status_code, headers=error.headers)
            return JSONResponse({"detail": "invalid admin key"}, status_code=401)
        rest = [(n, v) for n, v in request.query_params.multi_items() if n != "k"]
        return start_session(request.url.path + ("?" + urlencode(rest) if rest else ""))
    return await call_next(request)
