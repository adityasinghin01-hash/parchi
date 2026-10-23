# Phase 3 server: shop ask + lab booking (CONTRACT_P3.md)

Files: `p3_db.py` (own tables, `CREATE TABLE IF NOT EXISTS`), `shop.py` + `shop_workflows.py`, `lab.py` + `lab_workflows.py`.

Mount (api.py) and worker (worker.py):
```python
import shop, lab
shop.register(app, get_temporal, auth.require_install)   # get_install_id optional; defaults to auth.require_install
lab.register(app, get_temporal, auth.require_install)
# worker: workflows += shop_workflows.WORKFLOWS + lab_workflows.WORKFLOWS
#         activities += shop_workflows.ACTIVITIES + lab_workflows.ACTIVITIES
```
- Register BEFORE the 501 stubs: `POST /shop/{shop_id}` and `POST /lab/{lab_id}` in api.py would shadow `POST /shop/ask` and `POST /lab/book`. Remove those two stubs (and their 501 test cases).
- Reset: call `p3_db.delete_install(install_id)` / `p3_db.delete_all()` from `/reset` so "delete everything" also clears shop/lab rows.
- Env: `PARCHI_PUBLIC_URL` (base of reply links; default is the request's base URL, so set it to `http://<iMac-LAN-ip>:8000` behind a proxy), `PARCHI_TIME_SCALE`, `PARCHI_TASK_QUEUE`.

Design: SQLite is the truth for replies/states (first reply wins inside `BEGIN IMMEDIATE`); workflows own the timers and are signalled after SQLite accepted the change (signal failures are logged, never lose a reply).
Signals: shop `shop_reply(shopID)`, `next_round(round)`; lab `lab_event(kind, reportDueAt|None)`; both have query `snapshot`. Reply tokens: `secrets.token_urlsafe(16)`, only the sha256 is stored.
