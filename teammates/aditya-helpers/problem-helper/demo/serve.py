"""Local-only demo. No outgoing calls, automatic sending or persistent storage."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"src"))
from problem_helper import generate,load_contacts

class Handler(BaseHTTPRequestHandler):
    def respond(self,code,payload,ctype="application/json; charset=utf-8"):
        self.send_response(code);self.send_header("Content-Type",ctype)
        self.send_header("Cache-Control","no-store");self.send_header("X-Content-Type-Options","nosniff");self.end_headers();self.wfile.write(payload)
    def do_GET(self):
        if self.path=="/": self.respond(200,Path(__file__).with_name("index.html").read_bytes(),"text/html; charset=utf-8")
        elif self.path=="/companies": self.respond(200,json.dumps([{"name":r["company"],"kind":r["kind"]} for r in load_contacts()]).encode())
        else: self.respond(404,b'{}')
    def do_POST(self):
        if self.path!="/generate": return self.respond(404,b'{}')
        # No cross-origin callers; drafts stay on this machine.
        if self.headers.get("Origin") not in (None,"http://127.0.0.1:8040","http://localhost:8040"):
            return self.respond(403,b'{}')
        try:
            length=int(self.headers.get("Content-Length","0"))
            if not 0 < length <= 65536: raise ValueError("Invalid request size")
            result=generate(json.loads(self.rfile.read(length)))
            self.respond(200,json.dumps(result,ensure_ascii=False).encode())
        except (ValueError,TypeError,KeyError) as exc:
            self.respond(400,json.dumps({"error":str(exc)}).encode())
if __name__=="__main__":
    print("Open http://127.0.0.1:8040 — synthetic demonstration only")
    HTTPServer(("127.0.0.1",8040),Handler).serve_forever()
