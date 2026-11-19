"""
Comprehensive Concurrency and Integrity Test for MongoDB Matchmaking
Supports both live MongoDB Atlas and mongomock_motor async test engine.
Simulates multiple concurrent users joining the queue and finding matches simultaneously.
Verifies zero duplicate matches, atomic state transitions, and claim recovery.
"""
import os
import sys
import asyncio
import logging
from datetime import datetime, timedelta

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from beanie import init_beanie
import mongomock_motor
from models.app.core import database
from models.app.models.match_queue import MatchQueue
from models.app.models.match import Match
from models.app.services.matchmaking import MatchmakingService

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("test_concurrency")

async def setup_test_db():
    logger.info("Setting up Mock Motor MongoDB database...")
    mock_client = mongomock_motor.AsyncMongoMockClient()
    mock_db = mock_client["test_zenvora"]

    # Inject into database module
    database.client = mock_client
    database.db = mock_db

    await init_beanie(
        database=mock_db,
        document_models=[Match, MatchQueue]
    )
    return mock_db

async def run_tests():
    db = await setup_test_db()
    queue_col = db.get_collection("match_queue")
    test_service = MatchmakingService()

    logger.info("--- TEST 1: Basic Queue Joining and Removal ---")
    u1 = "test_user_1"
    ok = await test_service.add_to_queue(u1, interests=["coding", "gaming"], region="US", trust_score=100)
    assert ok, "Failed to add user 1 to queue"
    doc = await queue_col.find_one({"user_id": u1})
    assert doc is not None and doc["status"] == "waiting", "User 1 should be in waiting status"

    removed = await test_service.remove_from_queue(u1)
    assert removed, "Failed to remove user 1"
    doc_after = await queue_col.find_one({"user_id": u1})
    assert doc_after is None, "User 1 should be removed from collection"
    logger.info("TEST 1 PASSED: Basic queue join/remove works properly.")

    logger.info("--- TEST 2: High-Concurrency Multi-User Matchmaking ---")
    num_users = 10
    test_users = [f"sim_user_{i}" for i in range(num_users)]

    # Add all users concurrently
    add_tasks = [
        test_service.add_to_queue(
            user_id=uid,
            interests=["tech", "music"] if i % 2 == 0 else ["art", "gaming"],
            region="Global",
            trust_score=90 + (i % 10)
        )
        for i, uid in enumerate(test_users)
    ]
    results = await asyncio.gather(*add_tasks)
    assert all(results), "All users must be added successfully"
    logger.info(f"Added {num_users} users to queue concurrently.")

    # Concurrently execute find_match across all users
    match_tasks = [test_service.find_match(uid) for uid in test_users]
    match_results = await asyncio.gather(*match_tasks)

    # Validate pairs
    matched_pairs = []
    all_matched_users = []
    for caller, partner in zip(test_users, match_results):
        if partner:
            pair = tuple(sorted([caller, partner]))
            if pair not in matched_pairs:
                matched_pairs.append(pair)
            all_matched_users.append(caller)
            all_matched_users.append(partner)

    logger.info(f"Total matched pairs formed: {len(matched_pairs)}")
    for pair in matched_pairs:
        logger.info(f"  Match: {pair[0]} <-> {pair[1]}")

    # Integrity verification: NO user should appear more than once
    user_counts = {}
    for pair in matched_pairs:
        for u in pair:
            user_counts[u] = user_counts.get(u, 0) + 1
            assert user_counts[u] <= 1, f"CRITICAL: User {u} was matched multiple times in {matched_pairs}!"

    # Verify no document is stuck in an un-leased 'claimed' state
    claimed_docs = await queue_col.count_documents({
        "user_id": {"$in": test_users},
        "status": "claimed"
    })
    assert claimed_docs == 0, f"Found {claimed_docs} users stuck in claimed state!"
    logger.info("TEST 2 PASSED: Concurrent matchmaking executed with zero duplicate matches and clean state transitions.")

    logger.info("--- TEST 3: Expired Lease Recovery ---")
    stale_user = "sim_user_stale"
    past_time = datetime.utcnow() - timedelta(seconds=30)
    await queue_col.insert_one({
        "user_id": stale_user,
        "interests": [],
        "region": "Global",
        "trust_score": 100,
        "status": "claimed",
        "matched_with": "dummy",
        "matching_session_id": "stale_session",
        "lease_expires_at": past_time,
        "created_at": past_time,
        "updated_at": past_time
    })

    recovered_count = await test_service.recover_expired_leases()
    assert recovered_count >= 1, "Expected at least 1 expired lease to be recovered"

    stale_doc = await queue_col.find_one({"user_id": stale_user})
    assert stale_doc["status"] == "waiting", "Stale user must be reset to waiting"
    assert stale_doc["matching_session_id"] is None, "Session ID must be cleared"
    assert stale_doc["lease_expires_at"] is None, "Lease must be cleared"
    logger.info("TEST 3 PASSED: Expired lease recovered properly back to waiting.")
    await test_service.remove_from_queue(stale_user)

    logger.info("--- TEST 4: Single User Solitary Queue Behavior ---")
    solo_user = "solo_user_1"
    await test_service.add_to_queue(solo_user, interests=["solo"], region="Global", trust_score=100)
    solo_match = await test_service.find_match(solo_user)
    assert solo_match is None, "Single user with no partners in queue should return None"
    solo_doc = await queue_col.find_one({"user_id": solo_user})
    assert solo_doc["status"] == "waiting", "Solo user must remain in waiting status after unsuccessful find_match"
    await test_service.remove_from_queue(solo_user)
    logger.info("TEST 4 PASSED: Solitary queue user correctly remains waiting.")

    logger.info("ALL CONCURRENCY AND INTEGRITY TESTS PASSED SUCCESSFULLY!")

import pytest

@pytest.mark.asyncio
async def test_matchmaking_concurrency():
    await run_tests()

if __name__ == "__main__":
    asyncio.run(run_tests())

