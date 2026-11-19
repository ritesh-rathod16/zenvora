import asyncio
import logging
from datetime import datetime, timedelta, timezone
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
        while self._running:
            try:
                await self.cleanup_expired_messages()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in disappearing messages cleanup loop: {e}")
            await asyncio.sleep(30)

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
