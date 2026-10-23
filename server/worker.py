import asyncio
import os

from temporalio.client import Client
from temporalio.worker import Worker

import activities
import db
from workflows import OrderWorkflow


async def main() -> None:
    db.init_db()
    client = await Client.connect(os.environ.get("PARCHI_TEMPORAL", "localhost:7233"))
    worker = Worker(client, task_queue=os.environ.get("PARCHI_TASK_QUEUE", "parchi"),
                    workflows=[OrderWorkflow],
                    activities=[activities.place_order, activities.audit, activities.store_approval])
    await worker.run()


if __name__ == "__main__":
    asyncio.run(main())
