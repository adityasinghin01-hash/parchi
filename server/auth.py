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

LIMIT = 60
WINDOW = 60.0


class RateLimiter:
    """Sliding window per key, in memory (resets on restart, not shared across processes)."""

    def __init__(self) -> None:
        self.hits: dict[str, deque[float]] = {}
        self.lock = threading.Lock()

    def clear(self) -> None:
        with self.lock:
            self.hits.clear()

    def hit(self, name: str) -> int | None:
        """Record a request; return Retry-After seconds if over the limit."""
        now = time.monotonic()
        with self.lock:
            window = self.hits.setdefault(name, deque())
            while window and now - window[0] >= WINDOW:
                window.popleft()
            if len(window) >= LIMIT:
                return max(1, min(int(WINDOW), math.ceil(window[0] + WINDOW - now)))
            window.append(now)
            return None


limiter = RateLimiter()


def digest(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


def throttle(name: str) -> None:
    retry = limiter.hit(name)
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
        raise HTTPException(401, "invalid install key")
    throttle("install:" + hashed)
    return row["install_id"]


def require_admin(request: Request, allow_query: bool = False) -> None:
    expected = os.environ.get("PARCHI_ADMIN_KEY", "")
    given = request.headers.get("X-Admin-Key") or (request.query_params.get("k") if allow_query else "") or ""
    # Compare digests so length differences and non-ASCII input cannot leak or raise.
    ok = bool(expected) and hmac.compare_digest(digest(given), digest(expected))
    if not ok:
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
