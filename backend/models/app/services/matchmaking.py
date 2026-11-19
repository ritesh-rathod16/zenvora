import logging
import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple
from pymongo import ReturnDocument
from ..core.database import get_database, get_client
from ..models.match import Match

logger = logging.getLogger(__name__)

def _get_utc_now():
    return datetime.now(timezone.utc)

class MatchmakingService:
    """
    High-Concurrency Matchmaking Engine backed by MongoDB Atlas.
    Replaces PostgreSQL FOR UPDATE SKIP LOCKED with atomic state transitions,
    session-based temporary candidate claiming, lease expiration recovery,
    and optional multi-document transactions.
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
        """
        Adds or updates a user in the match_queue atomically using UPSERT.
        Resets status to 'waiting' and clears any previous stale claims.
        """
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
            logger.info(f"Matchmaking: User {user_id} joined queue (region={region}, score={trust_score}).")
            return True
        except Exception as e:
            logger.error(f"Matchmaking add_to_queue error for {user_id}: {e}", exc_info=True)
            return False

    async def remove_from_queue(self, user_id: str) -> bool:
        """
        Removes a user from the queue. If the user was part of an active claim,
        safely releases the partner back to 'waiting' state.
        """
        collection = self._get_collection()
        if collection is None:
            return False

        try:
            user_doc = await collection.find_one_and_delete({"user_id": user_id})
            if user_doc and user_doc.get("matching_session_id"):
                session_id = user_doc["matching_session_id"]
                now = _get_utc_now()
                # Recover any claimed partner under the same matching session
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
            logger.info(f"Matchmaking: User {user_id} removed from queue.")
            return True
        except Exception as e:
            logger.error(f"Matchmaking remove_from_queue error for {user_id}: {e}", exc_info=True)
            return False

    async def recover_expired_leases(self) -> int:
        """
        Recovers users whose claims expired due to network timeouts or crashes,
        re-queueing them back to 'waiting'.
        """
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
        except Exception as e:
            logger.error(f"Matchmaking lease recovery error: {e}")
            return 0

    async def find_match(self, current_user_id: str) -> Optional[str]:
        """
        Atomic matchmaking algorithm.
        1. Atomically claims the caller (current_user_id) with a unique session ID and lease.
        2. Queries suitable candidates ordered by interest overlap, trust score, and arrival time.
        3. Atomically claims the best candidate using find_one_and_update.
        4. Finalizes both users to 'matched' and persists Match record in MongoDB.
        5. In case of conflict, releases caller back to 'waiting' without data loss.
        """
        collection = self._get_collection()
        client = get_client()
        if collection is None:
            return None

        now = _get_utc_now()
        session_id = str(uuid.uuid4())
        lease_expires = now + timedelta(seconds=self.claim_timeout_seconds)

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
            # Caller is already claimed, matched, or not in queue
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

        # Prefer candidates in same region or Global
        if caller_region != "Global":
            query["region"] = {"$in": [caller_region, "Global"]}

        cursor = collection.find(query).sort([
            ("trust_score", -1),
            ("created_at", 1)
        ]).limit(15)

        candidates = await cursor.to_list(length=15)

        # Sort candidates prioritizing interest overlap
        def candidate_sort_key(c):
            c_interests = set(c.get("interests", []))
            overlap = len(caller_interests & c_interests)
            return (overlap, c.get("trust_score", 100))

        candidates.sort(key=candidate_sort_key, reverse=True)

        partner_id = None

        # Step 3: Attempt atomic claim on the best available candidate
        for cand in candidates:
            cand_user_id = cand["user_id"]
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
            # No candidate claimed; release caller back to waiting
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

        # Finalize match: set status to 'matched' for both users
        try:
            match_time = _get_utc_now()
            await collection.update_one(
                {"user_id": current_user_id, "matching_session_id": session_id},
                {
                    "$set": {
                        "status": "matched",
                        "matched_with": partner_id,
                        "updated_at": match_time
                    }
                }
            )
            await collection.update_one(
                {"user_id": partner_id, "matching_session_id": session_id},
                {
                    "$set": {
                        "status": "matched",
                        "matched_with": current_user_id,
                        "updated_at": match_time
                    }
                }
            )

            # Persist record in matches collection
            new_match = Match(user1=current_user_id, user2=partner_id, created_at=match_time)
            await new_match.insert()

            logger.info(f"Matchmaking: SUCCESS paired {current_user_id} <-> {partner_id} (session={session_id}).")
            return partner_id

        except Exception as e:
            logger.error(f"Matchmaking: Error finalizing match between {current_user_id} and {partner_id}: {e}", exc_info=True)
            # Safe rollback
            rollback_time = _get_utc_now()
            await collection.update_many(
                {"matching_session_id": session_id},
                {
                    "$set": {
                        "status": "waiting",
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "updated_at": rollback_time
                    }
                }
            )
            return None

    async def run_adaptive_worker(self, sio, on_match=None):
        """
        Background adaptive matching worker.
        Periodically recovers expired claims, scans waiting users,
        performs atomic matchmaking, and dispatches Socket.IO signaling events.
        """
        logger.info("Matchmaking: Adaptive worker started on MongoDB Atlas.")
        while not self._stop_worker:
            try:
                collection = self._get_collection()
                if collection is None:
                    await asyncio.sleep(3)
                    continue

                # Recover expired leases first
                await self.recover_expired_leases()

                # Check queue size
                q_size = await collection.count_documents({"status": "waiting"})
                if q_size > 1:
                    cursor = collection.find({"status": "waiting"}).sort("created_at", 1).limit(10)
                    waiting_users = await cursor.to_list(length=10)

                    for user_doc in waiting_users:
                        uid = user_doc["user_id"]
                        partner = await self.find_match(uid)
                        if partner:
                            if on_match:
                                on_match(uid, partner)
                            # Signaling: Tell Caller to generate Offer, Receiver to wait
                            await sio.emit('match_found', {'partner_id': partner, 'role': 'caller'}, room=uid)
                            await sio.emit('match_found', {'partner_id': uid, 'role': 'receiver'}, room=partner)

                sleep_time = 0.5 if q_size >= 4 else (1.5 if q_size > 0 else 3.0)
                await asyncio.sleep(sleep_time)

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Matchmaking worker loop error: {e}", exc_info=True)
                await asyncio.sleep(3)

matchmaker = MatchmakingService()
