import logging
import asyncio
import uuid
import random
from datetime import datetime, timedelta, timezone
from typing import Awaitable, Callable, List, Optional
from pymongo import ReturnDocument
from pymongo.errors import PyMongoError
from ..core.database import get_database
from ..models.match import Match

logger = logging.getLogger(__name__)

def _get_utc_now():
    return datetime.now(timezone.utc)

class MatchmakingService:
    """
    High-Concurrency Matchmaking Engine backed by MongoDB Atlas.
    Features atomic state transitions, session-based claiming, lease recovery,
    exponential backoff during database outages, and clean worker shutdown.
    """
    def __init__(self):
        self._stop_worker = False
        self.claim_timeout_seconds = 10

    def stop(self):
        self._stop_worker = True
        logger.info("Matchmaking: Worker stop signal received.")

    def _get_collection(self):
        db = get_database()
        if db is None:
            return None
        return db.get_collection("match_queue")

    async def add_to_queue(
        self,
        user_id: str,
        interests: Optional[List[str]] = None,
        region: str = "Global",
        trust_score: int = 100
    ) -> bool:
        collection = self._get_collection()
        if collection is None:
            logger.warning("Matchmaking: Database not ready for add_to_queue.")
            return False

        now = _get_utc_now()
        try:
            await collection.update_one(
                {"user_id": user_id},
                {
                    "$set": {
                        "interests": interests or [],
                        "region": region or "Global",
                        "trust_score": trust_score if trust_score is not None else 100,
                        "status": "waiting",
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "updated_at": now
                    },
                    "$setOnInsert": {
                        "created_at": now
                    }
                },
                upsert=True
            )
            logger.info(f"Matchmaking: User {user_id} joined queue.")
            return True
        except Exception:
            logger.error("Matchmaking add-to-queue operation failed.")
            return False

    async def remove_from_queue(self, user_id: str) -> bool:
        collection = self._get_collection()
        if collection is None:
            return False

        try:
            user_doc = await collection.find_one_and_delete({"user_id": user_id})
            if user_doc and user_doc.get("matching_session_id"):
                session_id = user_doc["matching_session_id"]
                now = _get_utc_now()
                await collection.update_many(
                    {"matching_session_id": session_id, "status": "claimed"},
                    {
                        "$set": {
                            "status": "waiting",
                            "matched_with": None,
                            "matching_session_id": None,
                            "lease_expires_at": None,
                            "updated_at": now
                        }
                    }
                )
            logger.info("Matchmaking: User removed from queue.")
            return True
        except Exception:
            logger.error("Matchmaking remove-from-queue operation failed.")
            return False

    async def recover_expired_leases(self) -> int:
        collection = self._get_collection()
        if collection is None:
            return 0

        now = _get_utc_now()
        try:
            result = await collection.update_many(
                {
                    "status": "claimed",
                    "lease_expires_at": {"$lt": now}
                },
                {
                    "$set": {
                        "status": "waiting",
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "updated_at": now
                    }
                }
            )
            if result.modified_count > 0:
                logger.info(f"Matchmaking: Recovered {result.modified_count} expired claim leases.")
            return result.modified_count
        except PyMongoError:
            logger.warning("Matchmaking lease recovery database operation failed.")
            return 0
        except Exception:
            logger.error("Matchmaking lease recovery failed.")
            return 0

    async def find_match(
        self,
        current_user_id: str,
        eligibility_check: Optional[Callable[[str, str], Awaitable[bool]]] = None,
    ) -> Optional[str]:
        collection = self._get_collection()
        if collection is None:
            return None

        if eligibility_check and not await eligibility_check(current_user_id, current_user_id):
            return None

        now = _get_utc_now()
        session_id = str(uuid.uuid4())
        lease_expires = now + timedelta(seconds=self.claim_timeout_seconds)

        try:
            # Step 1: Claim Caller
            caller = await collection.find_one_and_update(
                {
                    "user_id": current_user_id,
                    "$or": [
                        {"status": "waiting"},
                        {"status": "claimed", "lease_expires_at": {"$lt": now}}
                    ]
                },
                {
                    "$set": {
                        "status": "claimed",
                        "matching_session_id": session_id,
                        "lease_expires_at": lease_expires,
                        "updated_at": now
                    }
                },
                return_document=ReturnDocument.AFTER
            )

            if not caller:
                return None

            caller_interests = set(caller.get("interests", []))
            caller_region = caller.get("region", "Global")

            # Step 2: Query candidate pool
            query = {
                "user_id": {"$ne": current_user_id},
                "$or": [
                    {"status": "waiting"},
                    {"status": "claimed", "lease_expires_at": {"$lt": now}}
                ]
            }

            if caller_region != "Global":
                query["region"] = {"$in": [caller_region, "Global"]}

            cursor = collection.find(query).sort([
                ("trust_score", -1),
                ("created_at", 1)
            ]).limit(15)

            candidates = await cursor.to_list(length=15)

            def candidate_sort_key(c):
                c_interests = set(c.get("interests", []))
                overlap = len(caller_interests & c_interests)
                return (overlap, c.get("trust_score", 100))

            candidates.sort(key=candidate_sort_key, reverse=True)

            partner_id = None

            # Step 3: Attempt atomic claim on the best candidate
            for cand in candidates:
                cand_user_id = cand["user_id"]
                if eligibility_check and not await eligibility_check(current_user_id, cand_user_id):
                    continue
                claimed_candidate = await collection.find_one_and_update(
                    {
                        "user_id": cand_user_id,
                        "$or": [
                            {"status": "waiting"},
                            {"status": "claimed", "lease_expires_at": {"$lt": now}}
                        ]
                    },
                    {
                        "$set": {
                            "status": "claimed",
                            "matched_with": current_user_id,
                            "matching_session_id": session_id,
                            "lease_expires_at": lease_expires,
                            "updated_at": now
                        }
                    },
                    return_document=ReturnDocument.AFTER
                )

                if claimed_candidate:
                    partner_id = cand_user_id
                    break

            # Step 4: Finalize or Rollback
            if not partner_id:
                await collection.update_one(
                    {"user_id": current_user_id, "matching_session_id": session_id},
                    {
                        "$set": {
                            "status": "waiting",
                            "matched_with": None,
                            "matching_session_id": None,
                            "lease_expires_at": None,
                            "updated_at": _get_utc_now()
                        }
                    }
                )
                return None

            match_time = _get_utc_now()
            await collection.update_one(
                {"user_id": current_user_id, "matching_session_id": session_id},
                {"$set": {"status": "matched", "matched_with": partner_id, "updated_at": match_time}}
            )
            await collection.update_one(
                {"user_id": partner_id, "matching_session_id": session_id},
                {"$set": {"status": "matched", "matched_with": current_user_id, "updated_at": match_time}}
            )

            new_match = Match(user1=current_user_id, user2=partner_id, created_at=match_time)
            await new_match.insert()

            logger.info("Matchmaking: Pair established.")
            return partner_id

        except Exception:
            logger.error("Matchmaking find-match operation failed.")
            return None

    async def run_adaptive_worker(self, sio, on_match=None, eligibility_check=None):
        logger.info("Matchmaking: Adaptive worker started on MongoDB Atlas.")
        consecutive_errors = 0

        while not self._stop_worker:
            try:
                collection = self._get_collection()
                if collection is None:
                    await asyncio.sleep(3)
                    continue

                await self.recover_expired_leases()

                q_size = await collection.count_documents({"status": "waiting"})
                if q_size > 1:
                    cursor = collection.find({"status": "waiting"}).sort("created_at", 1).limit(10)
                    waiting_users = await cursor.to_list(length=10)

                    for user_doc in waiting_users:
                        uid = user_doc["user_id"]
                        partner = await self.find_match(uid, eligibility_check=eligibility_check)
                        if partner:
                            if on_match:
                                on_match(uid, partner)
                            await sio.emit('match_found', {'partner_id': partner, 'role': 'caller'}, room=uid)
                            await sio.emit('match_found', {'partner_id': uid, 'role': 'receiver'}, room=partner)

                # Reset error counter on successful loop execution
                consecutive_errors = 0
                sleep_time = 0.5 if q_size >= 4 else (1.5 if q_size > 0 else 3.0)
                await asyncio.sleep(sleep_time)

            except asyncio.CancelledError:
                logger.info("Matchmaking worker task cancelled.")
                break
            except (PyMongoError, TimeoutError):
                consecutive_errors += 1
                backoff = min(30.0, (2.0 ** min(consecutive_errors, 5)) + random.uniform(0, 1))
                logger.warning(f"Matchmaking worker database delay (attempt {consecutive_errors}, retrying in {backoff:.1f}s).")
                await asyncio.sleep(backoff)
            except Exception:
                consecutive_errors += 1
                logger.error("Matchmaking worker operation failed.")
                await asyncio.sleep(5)

matchmaker = MatchmakingService()
