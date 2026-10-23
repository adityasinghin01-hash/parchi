"""eval_reader_claude: spend gate, scoring through ai/score_rx.py, results.json. Uses the local stub, no network."""
import json
import subprocess
import sys
import time
from pathlib import Path

import httpx
import pytest

SERVER = Path(__file__).resolve().parents[1]
CATALOGUE = Path.home() / "dev" / "parchi-research" / "data" / "medlex" / "indian_medicine_data.csv"


def wait_up(url):
    for _ in range(60):
        try:
            return httpx.get(url, timeout=1)
        except httpx.HTTPError:
            time.sleep(0.25)
    raise AssertionError(url)


@pytest.fixture
def chain(tmp_path):
    env = {"PATH": "/usr/bin:/bin", "ANTHROPIC_API_KEY": "fake-test-key", "PARCHI_ANTHROPIC_BASE_URL": "http://127.0.0.1:18199"}
    stub = subprocess.Popen([sys.executable, str(SERVER / "tests" / "stub_anthropic.py"), "18199"], env=env)
    reader = subprocess.Popen([sys.executable, "-m", "uvicorn", "reader_claude:app", "--host", "127.0.0.1", "--port", "18100",
                               "--log-level", "warning"], cwd=SERVER, env=env)
    try:
        wait_up("http://127.0.0.1:18199/last"); wait_up("http://127.0.0.1:18100/health")
        yield tmp_path
    finally:
        for proc in (reader, stub):
            proc.terminate(); proc.wait(5)


def make_set(tmp_path, n):
    img = tmp_path / "img"; img.mkdir()
    labels = {}
    for i in range(n):
        (img / f"rx{i:03d}.jpg").write_bytes(b"\xff\xd8\xff\xe0" + b"x" * 100)
        labels[f"rx{i:03d}.jpg"] = None if i == 2 else "TELMA 40MG TAB, DOLO TAB 650MG"
    (tmp_path / "labels.json").write_text(json.dumps(labels))
    return img


def run(tmp_path, img, *extra):
    return subprocess.run([sys.executable, str(SERVER / "eval_reader_claude.py"), "--images", str(img), "--labels",
                           str(tmp_path / "labels.json"), "--url", "http://127.0.0.1:18100", "--out", str(tmp_path / "results.json"),
                           *extra], capture_output=True, text=True, cwd=SERVER)


@pytest.mark.skipif(not CATALOGUE.exists(), reason="medicine catalogue CSV (parchi-research) not on this machine")
def test_refuses_over_five_then_scores(chain):
    img = make_set(chain, 7)
    refused = run(chain, img)
    assert refused.returncode == 2 and "REFUSING" in refused.stdout and not (chain / "results.json").exists()
    assert httpx.get("http://127.0.0.1:18100/usage").json()["calls"] == 0

    ok = run(chain, img, "--limit", "5")
    assert ok.returncode == 0, ok.stdout + ok.stderr
    assert "estimated cost INR" in ok.stdout and "real cost INR" in ok.stdout
    r = json.loads((chain / "results.json").read_text())
    # stub always answers Telma + Glimy: 4 scored pages x gold {TELMA, DOLO}; 1 blank page (rx002) gets 2 false medicines
    assert (r["tp"], r["fp"], r["fn"]) == (4, 4, 4)
    assert r["recall"] == 0.5 and r["precision"] == 0.5
    assert r["blankPages"] == 1 and r["blankPageFalseMedicines"] == 2 and r["blankPagesWithFalseMedicines"] == 1
    assert r["secondsPerImage"] >= 0 and r["failed"] == [] and r["images"] == 5
    assert r["tokensIn"] == 5 * 1900 and r["costInr"] > 0 and "scorerRows" in r

    allowed = run(chain, img, "--yes-spend")
    assert allowed.returncode == 0 and json.loads((chain / "results.json").read_text())["images"] == 7
