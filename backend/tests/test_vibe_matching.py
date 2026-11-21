import os
import sys
import asyncio
from datetime import datetime, timedelta, timezone

import mongomock_motor
import pytest
from beanie import init_beanie
from fastapi import HTTPException

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.app.core import database
from models.app.models.match import Match
from models.app.models.match_queue import MatchQueue
from models.app.models.report import Report
from models.app.models.user import User
from models.app.models.vibe import DEFAULT_VIBES, UserVibe, Vibe
from models.app.routers.vibes import SetActiveVibeRequest, set_active_vibe
from models.app.services.matchmaking import MatchmakingService


async def setup_test_db():
    client = mongomock_motor.AsyncMongoMockClient()
    db = client["test_zenvora_vibes"]
    database.client = client
    database.db = db
    await init_beanie(
        database=db,
        document_models=[User, Report, Match, MatchQueue, Vibe, UserVibe],
    )
    now = datetime.now(timezone.utc)
    for definition in DEFAULT_VIBES:
        await Vibe(**definition, is_active=True, created_at=now, updated_at=now).insert()
    return db


async def add_user(username: str, age: int = 22, interests=None, blocked_users=None):
    user = User(
        email=f"{username.lower()}@example.com",
        anonymous_username=username,
        normalized_username=username.lower(),
        password_hash="test-password-hash",
        age=age,
        interests=interests or [],
        blocked_users=blocked_users or [],
        is_active=True,
    )
    await user.insert()
    return user


async def add_vibe_user(service, username, socket_id, vibe_id, age=22, interests=None, preferences=None, blocked_users=None):
    now = datetime.now(timezone.utc)
    user = await add_user(username, age, interests, blocked_users)
    expires_at = now + timedelta(hours=1)
    await UserVibe(
        user_id=username,
        vibe_id=vibe_id,
        preferred_vibes=preferences or [],
        expires_at=expires_at,
    ).insert()
    assert await service.add_to_queue(
        socket_id,
        interests=interests or [],
        owner_id=username,
        match_mode="vibe",
        vibe_id=vibe_id,
        preferred_vibes=preferences or [],
        vibe_expires_at=expires_at,
    )
    return user


@pytest.mark.asyncio
async def test_exact_vibe_match_prefers_compatible_vibe_and_shared_interests():
    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "caller", "socket-caller", "gaming", interests=["co-op", "indie"])
    await add_vibe_user(service, "fallback", "socket-fallback", "chill", interests=["co-op"])
    await add_vibe_user(service, "exact", "socket-exact", "gaming", interests=["co-op"])

    assert await service.find_match("socket-caller") == "socket-exact"


@pytest.mark.asyncio
async def test_social_fallback_works_but_unrelated_focus_vibes_do_not_match():
    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "music_user", "socket-music", "music")
    await add_vibe_user(service, "bored_user", "socket-bored", "bored")
    assert await service.find_match("socket-music") == "socket-bored"

    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "study_user", "socket-study", "study-buddy")
    await add_vibe_user(service, "gaming_user", "socket-gaming", "gaming")
    assert await service.find_match("socket-study") is None
    queue = await database.db.get_collection("match_queue").find_one({"user_id": "socket-study"})
    assert queue["status"] == "waiting"


@pytest.mark.asyncio
async def test_concurrent_vibe_requests_never_match_a_user_twice():
    await setup_test_db()
    service = MatchmakingService()
    sockets = []
    for index in range(8):
        socket_id = f"socket-{index}"
        sockets.append(socket_id)
        await add_vibe_user(service, f"person-{index}", socket_id, "chill", interests=["music"])

    await asyncio.gather(*(service.find_match(socket_id) for socket_id in sockets))
    matches = await database.db.get_collection("matches").find({}).to_list(length=20)
    matched_users = [user for match in matches for user in (match["user1"], match["user2"])]
    assert len(matches) == 4
    assert len(matched_users) == len(set(matched_users)) == 8


@pytest.mark.asyncio
async def test_blocked_or_reported_users_are_excluded():
    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "blocked_caller", "socket-blocked-caller", "chill")
    await add_vibe_user(service, "blocked_peer", "socket-blocked-peer", "chill", blocked_users=["blocked_caller"])
    assert await service.find_match("socket-blocked-caller") is None

    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "reporter", "socket-reporter", "chill")
    await add_vibe_user(service, "reported", "socket-reported", "chill")
    await Report(reporter_id="reporter", reported_id="reported", reason="Safety report").insert()
    assert await service.find_match("socket-reporter") is None


@pytest.mark.asyncio
async def test_changing_or_clearing_vibe_updates_presence_and_cancels_waiting_queue():
    await setup_test_db()
    service = MatchmakingService()
    user = await add_user("vibe_changer", age=24)
    await UserVibe(
        user_id=user.anonymous_username,
        vibe_id="gaming",
        expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
    ).insert()
    await service.add_to_queue(
        "socket-vibe-changer",
        owner_id=user.anonymous_username,
        match_mode="vibe",
        vibe_id="gaming",
        vibe_expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
    )

    await set_active_vibe(SetActiveVibeRequest(vibe_id="music"), user)
    active = await UserVibe.find_one({"user_id": user.anonymous_username})
    assert active.vibe_id == "music"
    assert await database.db.get_collection("match_queue").find_one({"user_id": "socket-vibe-changer"}) is None

    await set_active_vibe(SetActiveVibeRequest(vibe_id=None), user)
    assert await UserVibe.find_one({"user_id": user.anonymous_username}) is None


@pytest.mark.asyncio
async def test_age_safety_expiry_and_disconnect_cleanup():
    await setup_test_db()
    service = MatchmakingService()
    minor = await add_user("minor_user", age=17)
    adult = await add_user("adult_user", age=21)
    with pytest.raises(HTTPException) as error:
        await set_active_vibe(SetActiveVibeRequest(vibe_id="flirting"), minor)
    assert error.value.status_code == 403

    await add_vibe_user(service, "minor_pair", "socket-minor", "chill", age=17)
    await add_vibe_user(service, "adult_pair", "socket-adult", "chill", age=21)
    assert await service.find_match("socket-minor") is None

    await service.add_to_queue("expired-socket", owner_id="minor_user", match_mode="vibe", vibe_id="chill")
    await database.db.get_collection("match_queue").update_one(
        {"user_id": "expired-socket"},
        {"$set": {
            "queue_expires_at": datetime.now(timezone.utc) - timedelta(seconds=1),
            "vibe_expires_at": datetime.now(timezone.utc) - timedelta(seconds=1),
        }},
    )
    assert await service.cleanup_expired_vibe_queue() == 1

    await service.add_to_queue("disconnected-socket", interests=["music"])
    assert await service.remove_from_queue("disconnected-socket")
    assert await database.db.get_collection("match_queue").find_one({"user_id": "disconnected-socket"}) is None


@pytest.mark.asyncio
async def test_random_queue_stays_separate_and_existing_random_matching_works():
    await setup_test_db()
    service = MatchmakingService()
    await add_vibe_user(service, "vibe_person", "socket-vibe-person", "chill")
    await add_user("random_one")
    await add_user("random_two")
    await service.add_to_queue("socket-random-one", interests=["art"])
    assert await service.find_match("socket-random-one") is None

    await service.add_to_queue("socket-random-two", interests=["art"])
    assert await service.find_match("socket-random-one") == "socket-random-two"
    vibe_queue = await database.db.get_collection("match_queue").find_one({"user_id": "socket-vibe-person"})
    assert vibe_queue["status"] == "waiting"
