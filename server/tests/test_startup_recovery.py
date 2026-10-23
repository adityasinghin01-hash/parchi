"""R8/12: invoking run.sh repairs just the missing component."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

import pytest


@pytest.mark.parametrize("existing", ["api", "worker"])
def test_run_repairs_missing_component_without_restarting_healthy_one(tmp_path, existing):
    shutil.copy(Path(__file__).resolve().parents[1] / "run.sh", tmp_path / "run.sh")
    (tmp_path / "data").mkdir()
    (tmp_path / "data/admin.key").write_text("fake-test-key")
    (tmp_path / ".venv/bin").mkdir(parents=True)
    py = tmp_path / ".venv/bin/python"
    py.write_text('#!/bin/bash\necho "$*" >> calls\nif [[ "$1" == service_ready.py ]]; then exit 0; fi\nexec sleep 120\n')
    py.chmod(0o755)
    alive = subprocess.Popen(["sleep", "120"])
    (tmp_path / f"data/{existing}.pid").write_text(str(alive.pid))
    try:
        result = subprocess.run(["bash", "run.sh"], cwd=tmp_path, capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, result.stderr
        missing = "worker" if existing == "api" else "api"
        pidfile = tmp_path / f"data/{missing}.pid"
        assert pidfile.exists(), f"healthy {existing} prevented recovery of {missing}"
        os.kill(int(pidfile.read_text()), 0)
        assert (tmp_path / f"data/{existing}.pid").read_text() == str(alive.pid)
        assert "service_ready.py" in (tmp_path / "calls").read_text()
    finally:
        for file in (tmp_path / "data").glob("*.pid"):
            try:
                os.kill(int(file.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass
        alive.wait(timeout=5)
