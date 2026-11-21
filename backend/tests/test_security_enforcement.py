import os
import sys
import importlib
from types import SimpleNamespace
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.app.core import config
from models.app.websocket import signaling

stories = importlib.import_module("models.app.routers.stories")


def _user(username, gender="female", interested_in="everyone", age=25, age_min=18, age_max=40, blocked_users=None):
    return SimpleNamespace(
        anonymous_username=username,
        gender=gender,
        interested_in=interested_in,
        age=age,
        age_min=age_min,
        age_max=age_max,
        blocked_users=blocked_users or [],
    )


@pytest.mark.asyncio
async def test_matchmaking_requires_both_users_to_meet_preferences(monkeypatch):
    users = {
        "first": _user("first", gender="male", interested_in="female"),
        "second": _user("second", gender="female", interested_in="male"),
    }

    async def authenticated_user(sid):
        return users.get(sid)

    monkeypatch.setattr(signaling, "_authenticated_user", authenticated_user)
    assert await signaling.pair_is_eligible("first", "second")

    users["second"].age = 50
    assert not await signaling.pair_is_eligible("first", "second")


@pytest.mark.asyncio
async def test_matchmaking_rejects_blocked_pairs(monkeypatch):
    users = {
        "first": _user("first", gender="male"),
        "second": _user("second", gender="female", blocked_users=["first"]),
    }

    async def authenticated_user(sid):
        return users.get(sid)

    monkeypatch.setattr(signaling, "_authenticated_user", authenticated_user)
    assert not await signaling.pair_is_eligible("first", "second")


def test_production_configuration_requires_livekit_credentials(monkeypatch):
    monkeypatch.setattr(config, "SECRET_KEY", "s" * 40)
    monkeypatch.setattr(config, "ENVIRONMENT", "production")
    monkeypatch.setattr(config, "MONGODB_URL", "mongodb://example.invalid")
    monkeypatch.setattr(config, "ADMIN_EMAIL", "admin@example.invalid")
    monkeypatch.setattr(config, "ADMIN_PASSWORD", "a" * 20)
    monkeypatch.setattr(config, "LIVEKIT_URL", None)
    monkeypatch.setattr(config, "LIVEKIT_API_KEY", None)
    monkeypatch.setattr(config, "LIVEKIT_API_SECRET", None)

    with pytest.raises(RuntimeError, match="LIVEKIT_URL"):
        config.validate_production_config()


@pytest.mark.asyncio
@pytest.mark.parametrize("visibility", ["hidden", "close_friends"])
async def test_story_access_enforces_author_visibility(monkeypatch, visibility):
    viewer = _user("viewer")
    author = _user("author")
    author.hide_story_from = ["viewer"] if visibility == "hidden" else []
    author.close_friends = [] if visibility == "close_friends" else ["viewer"]

    async def find_author(query):
        return author

    monkeypatch.setattr(stories.User, "find_one", find_author)
    story = SimpleNamespace(
        author_id="author",
        is_close_friends_only=visibility == "close_friends",
        expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
    )

    with pytest.raises(HTTPException) as error:
        await stories._ensure_story_access(story, viewer)
    assert error.value.status_code == 404
