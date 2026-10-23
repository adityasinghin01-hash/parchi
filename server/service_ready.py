"""Startup readiness: API health plus live local worker and Temporal pollers."""
import asyncio
import json
import os
from pathlib import Path
import time
from urllib.request import urlopen

from temporalio.api.enums.v1 import TaskQueueType
from temporalio.api.taskqueue.v1 import TaskQueue
from temporalio.api.workflowservice.v1 import DescribeTaskQueueRequest
from temporalio.client import Client


def alive(name: str) -> bool:
    try:
        pid = int(Path(f"data/{name}.pid").read_text())
        if pid <= 0:
            return False
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


async def check() -> bool:
    if not all(alive(name) for name in ("api", "worker")):
        return False
    try:
        with urlopen("http://127.0.0.1:8000/health", timeout=2) as response:
            health = json.load(response)
        if not health.get("ok") or not health.get("temporal"):
            return False
        client = await Client.connect(os.environ.get("PARCHI_TEMPORAL", "localhost:7233"))
        for kind in (TaskQueueType.TASK_QUEUE_TYPE_WORKFLOW, TaskQueueType.TASK_QUEUE_TYPE_ACTIVITY):
            result = await client.workflow_service.describe_task_queue(DescribeTaskQueueRequest(
                namespace=client.namespace,
                task_queue=TaskQueue(name=os.environ.get("PARCHI_TASK_QUEUE", "parchi")), task_queue_type=kind))
            if not result.pollers:
                return False
        return True
    except Exception:
        return False


async def main() -> int:
    for _ in range(30):
        try:
            if await asyncio.wait_for(check(), timeout=5):
                print("ready: API, Temporal workflow and activity pollers")
                return 0
        except asyncio.TimeoutError:
            pass
        await asyncio.sleep(1)
    print("not ready: check data/api.log and data/worker.log")
    return 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
