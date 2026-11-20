import asyncio
import logging
import random
from datetime import datetime, timedelta, timezone
from pymongo.errors import PyMongoError
from ..models.chat import Message

logger = logging.getLogger(__name__)

class DisappearingMessagesWorker:
    def __init__(self):
        self._running = False
        self._task = None

    def start(self):
        if not self._running:
            self._running = True
            self._task = asyncio.create_task(self._run_loop())
            logger.info("Disappearing Messages Worker started.")

    def stop(self):
        if self._running:
            self._running = False
            if self._task:
                self._task.cancel()
            logger.info("Disappearing Messages Worker stopped.")

    async def _run_loop(self):
        consecutive_errors = 0
        while self._running:
            try:
                await self.cleanup_expired_messages()
                consecutive_errors = 0
                await asyncio.sleep(30)
            except asyncio.CancelledError:
                logger.info("Disappearing messages cleanup loop cancelled.")
                break
            except (PyMongoError, TimeoutError) as e:
                consecutive_errors += 1
                backoff = min(60.0, (2.0 ** min(consecutive_errors, 5)) + random.uniform(0, 1))
                logger.warning(f"Disappearing messages worker db delay (attempt {consecutive_errors}, retrying in {backoff:.1f}s): {e}")
                await asyncio.sleep(backoff)
            except Exception as e:
                consecutive_errors += 1
                logger.error(f"Disappearing messages worker unexpected error: {e}")
                await asyncio.sleep(15)

    async def cleanup_expired_messages(self):
        now = datetime.now(timezone.utc)

        # 1. Mode: delete_24h (24 hours after creation)
        cutoff_24h = now - timedelta(hours=24)
        expired_24h = await Message.find({
            "deletion_mode": "delete_24h",
            "created_at": {"$lte": cutoff_24h},
            "deleted_at": None
        }).to_list()

        for msg in expired_24h:
            msg.deleted_at = now
            msg.content = "[Message expired]"
            msg.attachment_url = None
            await msg.save()

        # 2. Mode: immediately_delete (after recipient has viewed it)
        # Give 3 seconds grace period after viewed_at to ensure UI renders receipt before removal
        grace_cutoff = now - timedelta(seconds=3)
        viewed_immediate = await Message.find({
            "deletion_mode": "immediately_delete",
            "viewed_at": {"$ne": None, "$lte": grace_cutoff},
            "deleted_at": None
        }).to_list()

        for msg in viewed_immediate:
            msg.deleted_at = now
            msg.content = "[Message disappeared]"
            msg.attachment_url = None
            await msg.save()

disappearing_worker = DisappearingMessagesWorker()
