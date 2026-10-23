"""A local stand-in for api.anthropic.com/v1/messages, for proving the chain without a key or money.
  .venv/bin/python tests/stub_anthropic.py 8199        (then PARCHI_ANTHROPIC_BASE_URL=http://127.0.0.1:8199)
GET /last shows what the reader sent (image data replaced by its length), so parameters can be inspected.
"""
import json
import sys

import uvicorn
from fastapi import FastAPI, Request

app = FastAPI()
LAST: dict = {}
LINES = {"lines": [
    {"kind": "medicine", "name": "Telma", "strength": "40", "quantity": 30, "schedule": "1-0-0"},
    {"kind": "medicine", "name": "Glimy", "strength": "4 mg", "quantity": None, "schedule": "OD"},
    {"kind": "test", "name": "HbA1c", "strength": None, "quantity": None, "schedule": None},
]}


@app.post("/v1/messages")
async def messages(request: Request) -> dict:
    body = await request.json()
    for block in body["messages"][0]["content"]:
        if block["type"] == "image":
            block["source"]["data"] = f'<{len(block["source"]["data"])} base64 chars>'
    LAST.clear()
    LAST.update({"headers_has_key": bool(request.headers.get("x-api-key") or request.headers.get("authorization")), "body": body})
    return {"id": "msg_stub", "type": "message", "role": "assistant", "model": body["model"],
            "content": [{"type": "text", "text": json.dumps(LINES)}], "stop_reason": "end_turn",
            "stop_sequence": None, "usage": {"input_tokens": 1900, "output_tokens": 120}}


@app.get("/last")
def last() -> dict:
    return LAST


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=int(sys.argv[1]) if len(sys.argv) > 1 else 8199, log_level="warning")
