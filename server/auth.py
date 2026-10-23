import hashlib
import hmac
import math
import os
import secrets
import sys
import threading
import time
from collections import deque

from fastapi import HTTPException, Request

import db

LIMIT = 120   # requests per minute per install key: the app polls order (2 s), shop ask (3 s) and lab status at once
FAIL_LIMIT = 30  # bad keys per minute per client address
WINDOW = 60.0


class RateLimiter:
    """Sliding window per key, in memory (resets on restart, not shared across processes)."""

    def __init__(self) -> None:
        self.hits: dict[str, deque[float]] = {}
        self.lock = threading.Lock()

    def clear(self) -> None:
        with self.lock:
            self.hits.clear()

    def hit(self, name: str, limit: int = LIMIT) -> int | None:
        """Record a request; return Retry-After seconds if over the limit."""
        now = time.monotonic()
        with self.lock:
            window = self.hits.setdefault(name, deque())
            while window and now - window[0] >= WINDOW:
                window.popleft()
            if len(window) >= limit:
                return max(1, min(int(WINDOW), math.ceil(window[0] + WINDOW - now)))
            window.append(now)
            return None


limiter = RateLimiter()


def digest(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


def throttle(name: str, limit: int = LIMIT) -> None:
    retry = limiter.hit(name, limit)
    if retry is not None:
        raise HTTPException(429, "rate limit exceeded", headers={"Retry-After": str(retry)})


def issue_key(label: str) -> tuple[str, str]:
    """Create an install and return (install_id, key). The key is never stored in clear."""
    install_id = "inst-" + secrets.token_hex(8)
    key = "pk-" + secrets.token_urlsafe(32)
    with db.connect() as conn:
        conn.execute("INSERT INTO keys(install_id,key_hash,label) VALUES (?,?,?)",
                     (install_id, digest(key), label))
    return install_id, key


def require_install(request: Request) -> str:
    key = request.headers.get("X-Install-Key", "")
    hashed = digest(key)
    with db.connect() as conn:
        row = conn.execute("SELECT install_id,key_hash FROM keys WHERE key_hash=?", (hashed,)).fetchone()
    if not key or row is None or not hmac.compare_digest(row["key_hash"], hashed):
        # Bad keys are throttled per client address, so guessing cannot run unlimited database lookups.
        throttle("authfail:" + (request.client.host if request.client else "?"), FAIL_LIMIT)
        raise HTTPException(401, "invalid install key")
    throttle("install:" + hashed)
    return row["install_id"]


def admin_key_ok(given: str) -> bool:
    """Constant-time check of an admin key (digests, so length and non-ASCII input cannot leak or raise)."""
    expected = os.environ.get("PARCHI_ADMIN_KEY", "")
    return bool(expected) and hmac.compare_digest(digest(given), digest(expected))


# ---- judge browser sessions (K31): the admin key never lives in a URL or a cookie ----
# A random opaque token in memory (only its digest is kept), so a server restart logs every browser out.
SESSION_COOKIE = "parchi_judge"
SESSION_SECONDS = 12 * 3600
SESSION_MAX = 200
CSRF_HEADER = "X-Parchi-Judge"
SAFE_METHODS = ("GET", "HEAD", "OPTIONS")
_sessions: dict[str, float] = {}   # digest(token) -> expiry (time.time())
_sessions_lock = threading.Lock()


def create_session() -> str:
    token = secrets.token_urlsafe(32)
    now = time.time()
    with _sessions_lock:
        for name in [n for n, expiry in _sessions.items() if expiry <= now]:
            del _sessions[name]
        while len(_sessions) >= SESSION_MAX:   # oldest first; a judge desk has a handful of browsers
            del _sessions[min(_sessions, key=_sessions.get)]
        _sessions[digest(token)] = now + SESSION_SECONDS
    return token


def session_ok(token: str | None) -> bool:
    if not token:
        return False
    name = digest(token)
    with _sessions_lock:
        expiry = _sessions.get(name)
        if expiry is not None and expiry <= time.time():
            del _sessions[name]
            return False
        return expiry is not None


def drop_session(token: str | None) -> None:
    if token:
        with _sessions_lock:
            _sessions.pop(digest(token), None)


def clear_sessions() -> None:
    with _sessions_lock:
        _sessions.clear()


def session_cookie(token: str, max_age: int = SESSION_SECONDS) -> str:
    """Set-Cookie value. No Secure flag: the lab LAN speaks plain http (documented limit)."""
    return f"{SESSION_COOKIE}={token}; Max-Age={max_age}; Path=/judge; HttpOnly; SameSite=Strict"


def fail_login(request: Request) -> None:
    """A wrong admin key from the login form or the ?k= bridge: counted per client address like a bad install key."""
    throttle("authfail:" + (request.client.host if request.client else "?"), FAIL_LIMIT)


def require_admin(request: Request) -> None:
    """Admin = the X-Admin-Key header (scripts, tests) OR a live judge session cookie (browsers).

    A cookie is sent by the browser on its own, so a state-changing request authenticated by it must also carry
    X-Parchi-Judge: 1, which a cross-site page cannot add. A wrong header never falls back to the cookie."""
    header = request.headers.get("X-Admin-Key")
    if header is not None:
        if not admin_key_ok(header):
            raise HTTPException(401, "invalid admin key")
    elif session_ok(request.cookies.get(SESSION_COOKIE)):
        if request.method not in SAFE_METHODS and request.headers.get(CSRF_HEADER) != "1":
            raise HTTPException(403, "missing X-Parchi-Judge header")
    else:
        raise HTTPException(401, "invalid admin key")
    throttle("admin")


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] != "issue":
        print("usage: python -m auth issue <label>", file=sys.stderr)
        return 2
    db.init_db()
    install_id, key = issue_key(argv[2])
    print(f"install id: {install_id}", file=sys.stderr)
    print(key)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
