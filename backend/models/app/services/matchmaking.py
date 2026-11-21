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
from ..models.user import User
from ..models.vibe import UserVibe, Vibe

logger = logging.getLogger(__name__)

def _get_utc_now():
    return datetime.now(timezone.utc)


def _as_utc(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)

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
        trust_score: int = 100,
        *,
        owner_id: Optional[str] = None,
        match_mode: str = "random",
        vibe_id: Optional[str] = None,
        preferred_vibes: Optional[List[str]] = None,
        vibe_expires_at: Optional[datetime] = None,
    ) -> bool:
        if match_mode not in {"random", "vibe"}:
            return False
        vibe_expires_at = _as_utc(vibe_expires_at)
        if match_mode == "vibe" and (
            not owner_id
            or not vibe_id
            or not vibe_expires_at
            or vibe_expires_at <= _get_utc_now()
        ):
            return False
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
                        "owner_id": owner_id,
                        "match_mode": match_mode,
                        "vibe_id": vibe_id,
                        "preferred_vibes": preferred_vibes or [],
                        "vibe_expires_at": vibe_expires_at,
                        "queue_expires_at": now + timedelta(seconds=90) if match_mode == "vibe" else None,
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
            logger.info("Matchmaking: User joined queue.")
            return True
        except Exception:
            logger.error("Matchmaking add-to-queue operation failed.")
            return False

    async def heartbeat_vibe_queue(self, owner_id: str) -> bool:
        collection = self._get_collection()
        if collection is None:
            return False
        now = _get_utc_now()
        result = await collection.update_many(
            {"owner_id": owner_id, "match_mode": "vibe", "status": "waiting", "vibe_expires_at": {"$gt": now}},
            {"$set": {"queue_expires_at": now + timedelta(seconds=90), "updated_at": now}},
        )
        return result.modified_count > 0

    async def cancel_vibe_queue_for_owner(self, owner_id: str) -> int:
        """Remove only a user's waiting/claimed vibe requests, leaving active calls alone."""
        collection = self._get_collection()
        if collection is None:
            return 0
        now = _get_utc_now()
        cursor = collection.find({
            "owner_id": owner_id,
            "match_mode": "vibe",
            "status": {"$in": ["waiting", "claimed"]},
        })
        entries = await cursor.to_list(length=20)
        for entry in entries:
            session_id = entry.get("matching_session_id")
            await collection.delete_one({"user_id": entry["user_id"], "status": entry["status"]})
            if session_id:
                await collection.update_many(
                    {"matching_session_id": session_id, "status": "claimed"},
                    {"$set": {
                        "status": "waiting",
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "updated_at": now,
                    }},
                )
        return len(entries)

    async def cleanup_expired_vibe_queue(self) -> int:
        collection = self._get_collection()
        if collection is None:
            return 0
        now = _get_utc_now()
        result = await collection.delete_many({
            "match_mode": "vibe",
            "status": {"$in": ["waiting", "claimed"]},
            "$or": [
                {"queue_expires_at": {"$lte": now}},
                {"vibe_expires_at": {"$lte": now}},
            ],
        })
        return result.deleted_count

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

    async def _vibe_pair_is_safe(
        self,
        caller_owner: str,
        candidate_owner: str,
        caller_vibe: Vibe,
        candidate_vibe: Vibe,
        now: datetime,
        eligibility_check=None,
        caller_session: Optional[str] = None,
        candidate_session: Optional[str] = None,
    ) -> bool:
        caller = await User.find_one({"anonymous_username": caller_owner})
        candidate = await User.find_one({"anonymous_username": candidate_owner})
        if not caller or not candidate:
            return False
        if any((u.is_banned or u.shadow_banned or not u.is_active or u.role in {"admin", "super_admin"}) for u in (caller, candidate)):
            return False
        if caller.age is None or candidate.age is None or caller.age < 13 or candidate.age < 13:
            return False
        # Keep adult and under-18 users in separate pools for Vibe Matching.
        if (caller.age >= 18) != (candidate.age >= 18):
            return False
        caller_minimum_age = max(caller_vibe.minimum_age, 18 if caller_vibe.vibe_id == "flirting" else 13)
        candidate_minimum_age = max(candidate_vibe.minimum_age, 18 if candidate_vibe.vibe_id == "flirting" else 13)
        if caller.age < caller_minimum_age or candidate.age < candidate_minimum_age:
            return False
        if candidate_owner in (caller.blocked_users or []) or caller_owner in (candidate.blocked_users or []):
            return False

        db = get_database()
        if db is None:
            return False
        report = await db.get_collection("reports").find_one({
            "$or": [
                {"reporter_id": caller_owner, "reported_id": candidate_owner},
                {"reporter_id": candidate_owner, "reported_id": caller_owner},
            ]
        })
        if report:
            return False
        if eligibility_check and caller_session and candidate_session:
            if not await eligibility_check(caller_session, candidate_session):
                return False
        return True

    async def _find_vibe_match(self, current_user_id: str, caller: dict, collection, now: datetime, session_id: str, lease_expires: datetime, eligibility_check=None) -> Optional[str]:
        caller_owner = caller.get("owner_id")
        caller_vibe_id = caller.get("vibe_id")
        db = get_database()
        if not caller_owner or not caller_vibe_id or not db:
            await collection.delete_one({"user_id": current_user_id, "matching_session_id": session_id})
            return None

        caller_presence = await UserVibe.find_one({
            "user_id": caller_owner,
            "vibe_id": caller_vibe_id,
            "expires_at": {"$gt": now},
        })
        caller_vibe = await Vibe.find_one({"vibe_id": caller_vibe_id, "is_active": True})
        caller_user = await User.find_one({"anonymous_username": caller_owner})
        if not caller_presence or not caller_vibe or not caller_user or caller_user.age is None:
            await collection.delete_one({"user_id": current_user_id, "matching_session_id": session_id})
            return None
        if set(caller_presence.preferred_vibes or []) != set(caller.get("preferred_vibes", [])):
            await collection.delete_one({"user_id": current_user_id, "matching_session_id": session_id})
            return None
        caller_minimum_age = max(caller_vibe.minimum_age, 18 if caller_vibe.vibe_id == "flirting" else 13)
        if caller_user.age < caller_minimum_age:
            await collection.delete_one({"user_id": current_user_id, "matching_session_id": session_id})
            return None

        all_vibes = await Vibe.find({"is_active": True}).to_list()
        vibe_by_id = {v.vibe_id: v for v in all_vibes}
        statuses = [{"status": "waiting"}, {"status": "claimed", "lease_expires_at": {"$lt": now}}]
        query = {
            "user_id": {"$ne": current_user_id},
            "owner_id": {"$ne": caller_owner},
            "match_mode": "vibe",
            "status": {"$in": ["waiting", "claimed"]},
            "vibe_expires_at": {"$gt": now},
            "queue_expires_at": {"$gt": now},
            "vibe_id": {"$in": list(vibe_by_id)},
        }
        if caller.get("region") != "Global":
            query["region"] = {"$in": [caller.get("region"), "Global"]}
        cursor = collection.find(query).sort([("trust_score", -1), ("created_at", 1)]).limit(50)
        candidates = await cursor.to_list(length=50)

        eligible = []
        caller_interests = set(caller.get("interests", []))
        caller_preferences = set(caller.get("preferred_vibes", []))
        for candidate in candidates:
            candidate_owner = candidate.get("owner_id")
            candidate_vibe = vibe_by_id.get(candidate.get("vibe_id"))
            if not candidate_owner or not candidate_vibe:
                continue
            if caller_preferences and candidate_vibe.vibe_id not in caller_preferences:
                continue
            candidate_preferences = set(candidate.get("preferred_vibes", []))
            if candidate_preferences and caller_vibe_id not in candidate_preferences:
                continue

            if candidate_vibe.vibe_id == caller_vibe_id:
                compatibility = 2
            elif (
                candidate_vibe.vibe_id in caller_vibe.compatible_vibes
                and caller_vibe_id in candidate_vibe.compatible_vibes
            ):
                compatibility = 1
            elif (
                caller_vibe.allow_fallback
                and candidate_vibe.allow_fallback
                and caller_vibe.fallback_group
                and caller_vibe.fallback_group == candidate_vibe.fallback_group
            ):
                compatibility = 0
            else:
                continue

            safe = await self._vibe_pair_is_safe(
                caller_owner,
                candidate_owner,
                caller_vibe,
                candidate_vibe,
                now,
                eligibility_check,
                current_user_id,
                candidate["user_id"],
            )
            if not safe:
                continue
            presence = await UserVibe.find_one({
                "user_id": candidate_owner,
                "vibe_id": candidate_vibe.vibe_id,
                "expires_at": {"$gt": now},
            })
            if not presence or set(presence.preferred_vibes or []) != candidate_preferences:
                continue
            common_interests = len(caller_interests & set(candidate.get("interests", [])))
            eligible.append((candidate, candidate_vibe, compatibility, common_interests))

        cutoff = now - timedelta(days=14)
        recent_matches = await db.get_collection("matches").find({
            "created_at": {"$gte": cutoff},
            "$or": [{"user1": caller_owner}, {"user2": caller_owner}],
        }).to_list(length=1000)
        recently_matched = {
            row.get("user2") if row.get("user1") == caller_owner else row.get("user1")
            for row in recent_matches
        }
        if any(row[0].get("owner_id") not in recently_matched for row in eligible):
            eligible = [row for row in eligible if row[0].get("owner_id") not in recently_matched]
        eligible.sort(key=lambda row: (row[2], row[3], row[0].get("trust_score", 100)), reverse=True)

        partner_id = None
        partner_owner = None
        for candidate, candidate_vibe, _, _ in eligible:
            cand_id = candidate["user_id"]
            candidate_claim = await collection.find_one_and_update(
                {
                    "user_id": cand_id,
                    "owner_id": candidate.get("owner_id"),
                    "match_mode": "vibe",
                    "vibe_id": candidate_vibe.vibe_id,
                    "vibe_expires_at": {"$gt": now},
                    "queue_expires_at": {"$gt": now},
                    "$or": statuses,
                },
                {"$set": {
                    "status": "claimed",
                    "matched_with": current_user_id,
                    "matching_session_id": session_id,
                    "lease_expires_at": lease_expires,
                    "updated_at": now,
                }},
                return_document=ReturnDocument.AFTER,
            )
            if not candidate_claim:
                continue

            # Recheck after the atomic claim in case a block, report, or preference changed meanwhile.
            current_presence = await UserVibe.find_one({
                "user_id": caller_owner,
                "vibe_id": caller_vibe_id,
                "expires_at": {"$gt": now},
            })
            candidate_presence = await UserVibe.find_one({
                "user_id": candidate.get("owner_id"),
                "vibe_id": candidate_vibe.vibe_id,
                "expires_at": {"$gt": now},
            })
            safe = current_presence and candidate_presence and await self._vibe_pair_is_safe(
                caller_owner,
                candidate.get("owner_id"),
                caller_vibe,
                candidate_vibe,
                now,
                eligibility_check,
                current_user_id,
                cand_id,
            )
            safe = bool(
                safe
                and set(current_presence.preferred_vibes or []) == set(caller.get("preferred_vibes", []))
                and set(candidate_presence.preferred_vibes or []) == set(candidate.get("preferred_vibes", []))
            )
            if safe:
                partner_id = cand_id
                partner_owner = candidate.get("owner_id")
                break
            await collection.update_one(
                {"user_id": cand_id, "matching_session_id": session_id, "status": "claimed"},
                {"$set": {
                    "status": "waiting",
                    "matched_with": None,
                    "matching_session_id": None,
                    "lease_expires_at": None,
                    "updated_at": _get_utc_now(),
                }},
            )

        if not partner_id:
            caller_queue_expiry = caller.get("queue_expires_at")
            caller_queue_expiry = _as_utc(caller_queue_expiry)
            if caller_queue_expiry and caller_queue_expiry <= now:
                await collection.delete_one({"user_id": current_user_id, "matching_session_id": session_id})
            else:
                await collection.update_one(
                    {"user_id": current_user_id, "matching_session_id": session_id},
                    {"$set": {
                        "status": "waiting",
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "updated_at": _get_utc_now(),
                    }},
                )
            return None

        match_time = _get_utc_now()
        await collection.update_one(
            {"user_id": current_user_id, "matching_session_id": session_id},
            {"$set": {"status": "matched", "matched_with": partner_id, "updated_at": match_time}},
        )
        await collection.update_one(
            {"user_id": partner_id, "matching_session_id": session_id},
            {"$set": {"status": "matched", "matched_with": current_user_id, "updated_at": match_time}},
        )
        await Match(user1=caller_owner, user2=partner_owner, created_at=match_time).insert()
        logger.info("Vibe matchmaking established a pair.")
        return partner_id

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

            if caller.get("match_mode") == "vibe":
                return await self._find_vibe_match(
                    current_user_id,
                    caller,
                    collection,
                    now,
                    session_id,
                    lease_expires,
                    eligibility_check,
                )

            caller_interests = set(caller.get("interests", []))
            caller_region = caller.get("region", "Global")

            # Step 2: Query candidate pool
            query = {
                "user_id": {"$ne": current_user_id},
                "$and": [
                    {"$or": [
                        {"status": "waiting"},
                        {"status": "claimed", "lease_expires_at": {"$lt": now}}
                    ]},
                    {"$or": [
                        {"match_mode": "random"},
                        {"match_mode": {"$exists": False}},
                    ]},
                ],
            }
            if caller.get("owner_id"):
                query["owner_id"] = {"$ne": caller["owner_id"]}

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
                        "$and": [
                            {"$or": [
                                {"status": "waiting"},
                                {"status": "claimed", "lease_expires_at": {"$lt": now}}
                            ]},
                            {"$or": [
                                {"match_mode": "random"},
                                {"match_mode": {"$exists": False}},
                            ]},
                        ],
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
                await self.cleanup_expired_vibe_queue()

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
                            caller_doc = await collection.find_one({"user_id": uid}) or {}
                            await sio.emit('match_found', {
                                'partner_id': partner,
                                'role': 'caller',
                                'match_mode': caller_doc.get('match_mode', 'random'),
                            }, room=uid)
                            await sio.emit('match_found', {
                                'partner_id': uid,
                                'role': 'receiver',
                                'match_mode': caller_doc.get('match_mode', 'random'),
                            }, room=partner)

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
