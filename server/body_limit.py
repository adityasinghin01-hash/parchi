"""Bound actual request bytes before parsers or handlers can consume the body."""
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send


class BodySizeLimit:
    def __init__(self, app: ASGIApp, *, default_limit: int, photo_limit: int, photo_paths: tuple[str, ...]):
        self.app = app
        self.default_limit = default_limit
        self.photo_limit = photo_limit
        self.photo_paths = photo_paths

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        photo = scope["method"] == "POST" and scope["path"] in self.photo_paths
        limit = self.photo_limit if photo else self.default_limit
        declared = dict(scope["headers"]).get(b"content-length", b"")
        # Compare decimal strings: converting an untrusted, very long integer can itself raise.
        length = declared.lstrip(b"0") or b"0"
        over = declared.isdigit() and (len(length) > len(str(limit)) or
                                      (len(length) == len(str(limit)) and length > str(limit).encode()))
        if over:
            await JSONResponse({"detail": "request body too large"}, status_code=413)(scope, receive, send)
            return
        if photo and not declared.isdigit():
            await JSONResponse({"detail": "send the photo with a Content-Length"}, status_code=411)(scope, receive, send)
            return

        # Buffer only up to the cap. This rejects before JSON/multipart parsing, including
        # malformed bodies whose parser might otherwise translate a receive exception to 400.
        chunks = []
        size = 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            size += len(chunk)
            if size > limit:
                await JSONResponse({"detail": "request body too large"}, status_code=413)(scope, receive, send)
                return
            chunks.append(chunk)
            if not message.get("more_body", False):
                break

        replayed = False

        async def bounded_receive():
            nonlocal replayed
            if not replayed:
                replayed = True
                return {"type": "http.request", "body": b"".join(chunks), "more_body": False}
            return await receive()

        await self.app(scope, bounded_receive, send)
