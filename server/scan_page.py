"""Phone-browser "scan and read" TEST page (K22): GET /judge/scan and POST /judge/scan/read. Admin key only.

A test tool on the lab iMac, like the judge page. It is not part of the app and does NOT hide the patient's name.
The page is plain HTML + JS, no external requests. Server-side values are never put into the page; the script
reads the admin key from its own address (?k=) and builds the result table with textContent only (no innerHTML).
The photo and the reader's lines are never logged or stored.
"""
import os
import time
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from starlette.datastructures import UploadFile
from fastapi.responses import HTMLResponse, JSONResponse

import auth

router = APIRouter()

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Parchi scan test</title>
<style>
body{font:17px/1.4 system-ui,sans-serif;margin:0;padding:12px;max-width:640px}
h1{font-size:1.3em;margin:.2em 0}
.warn{background:#fff3cd;border:2px solid #b58900;padding:10px;border-radius:8px;margin:8px 0}
.btn{display:block;box-sizing:border-box;width:100%;min-height:52px;margin:10px 0;padding:12px;font-size:1em;
 text-align:center;border:2px solid #1a56db;border-radius:10px;background:#fff;color:#1a56db;font-weight:600}
.btn.main{background:#1a56db;color:#fff}.btn[disabled]{opacity:.45}
input[type=file]{position:absolute;width:1px;height:1px;opacity:0;overflow:hidden}
label.btn{cursor:pointer}
#preview{max-width:100%;max-height:50vh;display:block;margin:8px auto;border:1px solid #888}
#status{min-height:1.4em;font-weight:600}.err{color:#b00020}
table{border-collapse:collapse;width:100%;margin:8px 0;font-size:.72em}
th,td{border:1px solid #888;padding:3px;text-align:left;vertical-align:top;overflow-wrap:anywhere}
th{background:#eee}
</style></head><body>
<h1>Parchi: scan and read (test)</h1>
<div class="warn">TEST PAGE: use test parchis only. This page does NOT hide the patient's name (the app does).</div>
<label class="btn main" for="cam">Take a photo</label>
<input id="cam" type="file" accept="image/*" capture="environment">
<label class="btn" for="gal">Choose from gallery</label>
<input id="gal" type="file" accept="image/*">
<img id="preview" alt="Preview of the chosen parchi" hidden>
<div id="size"></div>
<button id="read" class="btn main" type="button" disabled>Read this parchi</button>
<div id="status" role="status" aria-live="polite"></div>
<div id="result"></div>
<button id="again" class="btn" type="button" hidden>Try another photo</button>
<script>
(function () {
  var MAX_SIDE = 2000, QUALITY = 0.7, MAX_BYTES = 2000000;
  var key = new URLSearchParams(location.search).get('k') || '';
  var $ = function (id) { return document.getElementById(id); };
  var blob = null, previewURL = null, busy = false;

  function setStatus(text, isError) {
    var s = $('status'); s.textContent = text; s.className = isError ? 'err' : '';
  }
  function clearResult() { var r = $('result'); while (r.firstChild) r.removeChild(r.firstChild); }
  function cell(tag, text) { var c = document.createElement(tag); c.textContent = text; return c; }

  function toBlob(img, scale, quality) {
    return new Promise(function (resolve, reject) {
      var w = Math.max(1, Math.round(img.naturalWidth * scale)), h = Math.max(1, Math.round(img.naturalHeight * scale));
      var canvas = document.createElement('canvas'); canvas.width = w; canvas.height = h;
      var ctx = canvas.getContext('2d');
      ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, w, h); ctx.drawImage(img, 0, 0, w, h);
      canvas.toBlob(function (b) { b ? resolve(b) : reject(new Error('could not encode the image')); }, 'image/jpeg', quality);
    });
  }

  async function prepare(file) {
    var url = URL.createObjectURL(file);
    try {
      var img = new Image();
      await new Promise(function (ok, bad) { img.onload = ok; img.onerror = function () { bad(new Error('this file is not a picture this browser can open')); }; img.src = url; });
      var scale = Math.min(1, MAX_SIDE / Math.max(img.naturalWidth, img.naturalHeight));
      var out = await toBlob(img, scale, QUALITY);
      while (out.size > MAX_BYTES && scale > 0.2) { scale *= 0.8; out = await toBlob(img, scale, QUALITY); }
      if (out.size > MAX_BYTES) throw new Error('the picture is still over 2 MB after shrinking');
      return out;
    } finally { URL.revokeObjectURL(url); }
  }

  async function chosen(ev) {
    var file = ev.target.files && ev.target.files[0];
    ev.target.value = '';
    if (!file) return;
    blob = null; $('read').disabled = true; clearResult(); $('again').hidden = true;
    setStatus('Preparing the photo...');
    try {
      blob = await prepare(file);
      if (previewURL) URL.revokeObjectURL(previewURL);
      previewURL = URL.createObjectURL(blob);
      $('preview').src = previewURL; $('preview').hidden = false;
      $('size').textContent = 'Will send ' + Math.round(blob.size / 1024) + ' KB (JPEG, max 2000 px, quality 0.7).';
      $('read').disabled = false; setStatus('');
    } catch (e) { $('preview').hidden = true; $('size').textContent = ''; setStatus('Error: ' + e.message, true); }
  }

  function show(lines, seconds, reader) {
    clearResult();
    if (!Array.isArray(lines) || lines.length === 0) {
      var p = document.createElement('p'); p.textContent = 'Nothing was found'; $('result').appendChild(p);
    } else {
      var t = document.createElement('table'), head = document.createElement('tr');
      ['Kind', 'Name', 'Strength', 'Quantity', 'Schedule'].forEach(function (h) { head.appendChild(cell('th', h)); });
      t.appendChild(head);
      lines.forEach(function (l) {
        l = (l && typeof l === 'object') ? l : {};
        var tr = document.createElement('tr');
        ['kind', 'name', 'strength', 'quantity', 'schedule'].forEach(function (f) {
          var v = l[f]; if (f === 'kind' && (v === undefined || v === null)) v = 'medicine';
          tr.appendChild(cell('td', v === undefined || v === null ? '' : String(v)));
        });
        t.appendChild(tr);
      });
      $('result').appendChild(t);
    }
    var info = document.createElement('p'); info.id = 'time';
    info.textContent = 'Read in ' + seconds.toFixed(1) + ' s' + (reader ? ' (reader ' + reader + ')' : '');
    $('result').appendChild(info);
  }

  async function read() {
    if (!blob || busy) return;
    busy = true; $('read').disabled = true; clearResult(); setStatus('Reading... this can take a while.');
    var ctl = new AbortController(), timer = setTimeout(function () { ctl.abort(); }, 40000);
    try {
      var fd = new FormData(); fd.append('image', blob, 'parchi.jpg');
      var r = await fetch('/judge/scan/read', {method: 'POST', headers: {'X-Admin-Key': key}, body: fd, signal: ctl.signal});
      var data = null, raw = '';
      try { raw = await r.text(); data = JSON.parse(raw); } catch (e) { data = null; }
      if (!r.ok) {
        var detail = data && data.detail !== undefined ? (typeof data.detail === 'string' ? data.detail : JSON.stringify(data.detail)) : (raw || r.statusText);
        if (r.status === 503 && detail === 'reader not connected') setStatus('The reader is not connected yet.', true);
        else setStatus('Error ' + r.status + ': ' + detail, true);
      } else {
        setStatus(''); show(data && data.lines, (data && typeof data.ms === 'number' ? data.ms : 0) / 1000, data && data.reader);
      }
    } catch (e) {
      setStatus('Error: ' + (e.name === 'AbortError' ? 'no answer after 40 seconds' : e.message), true);
    } finally {
      clearTimeout(timer); busy = false; $('again').hidden = false; $('read').disabled = !blob;
    }
  }

  $('cam').addEventListener('change', chosen);
  $('gal').addEventListener('change', chosen);
  $('read').addEventListener('click', read);
  $('again').addEventListener('click', function () {
    blob = null; clearResult(); setStatus(''); $('preview').hidden = true; $('size').textContent = '';
    $('read').disabled = true; $('again').hidden = true; window.scrollTo(0, 0);
  });
})();
</script></body></html>
"""

HEADERS = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": ("default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
                                "img-src blob:; connect-src 'self'; base-uri 'none'; form-action 'none'"),
}


def admin_query(request: Request) -> None:
    auth.require_admin(request, allow_query=True)


def admin_header(request: Request) -> None:
    auth.require_admin(request)


def reader_label(url: str) -> str:
    """host:port only: no scheme, path, query or credentials."""
    parts = urlsplit(url)
    host = parts.hostname or ""
    return f"{host}:{parts.port}" if parts.port else host


@router.get("/judge/scan", response_class=HTMLResponse, dependencies=[Depends(admin_query)])
async def scan_page() -> HTMLResponse:
    return HTMLResponse(PAGE, headers=HEADERS)


@router.post("/judge/scan/read", dependencies=[Depends(admin_header)])
async def scan_read(request: Request) -> JSONResponse:
    """Forward the photo to the reader exactly as POST /read does. Nothing is logged or stored."""
    import api  # late import: api includes this router, and the tests swap api.READER_TRANSPORT
    started = time.perf_counter()
    reader = os.environ.get("PARCHI_READER_URL", "")
    if not reader:
        raise HTTPException(503, "reader not connected")
    try:
        image = (await request.form()).get("image")  # a text field or a broken body is just 'not an image'
    except Exception:
        image = None
    if not isinstance(image, UploadFile) or image.content_type not in api.READER_TYPES:
        raise HTTPException(415, "send one image (jpeg, png or heic) in the 'image' field")
    data = await image.read(api.READER_MAX_BYTES + 1)
    if len(data) > api.READER_MAX_BYTES:
        raise HTTPException(413, "image too large")
    try:
        async with httpx.AsyncClient(timeout=float(os.environ.get("PARCHI_READER_TIMEOUT", "20")), transport=api.READER_TRANSPORT) as client:
            reply = await client.post(reader, files={"image": ("parchi", data, image.content_type)})
    except httpx.HTTPError:
        raise HTTPException(503, "reader not connected")
    if reply.status_code >= 400:
        raise HTTPException(502, "reader error")
    try:
        body = reply.json()
    except ValueError:
        raise HTTPException(502, "reader error")
    if not isinstance(body, dict):
        raise HTTPException(502, "reader error")
    body = dict(body, ms=round((time.perf_counter() - started) * 1000), reader=reader_label(reader))
    return JSONResponse(body, headers={"Cache-Control": "no-store"})
