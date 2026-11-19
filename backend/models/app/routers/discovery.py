from fastapi import APIRouter, HTTPException, Depends, Query
from ..models.user import User
from ..models.swipe import Swipe
from ..models.social import Follow, FollowRequest
from ..core.security import get_current_user
from typing import List, Optional
import random
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone

router = APIRouter()

class DiscoverUserResponse(BaseModel):
    id: str
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    profile_photo_url: Optional[str] = None
    bio: Optional[str] = None
    trust_score: int
    interests: List[str]
    overlap_interests: List[str] = []
    mutual_connections_count: int = 0
    country: Optional[str] = "Global"
    age: Optional[int] = None
    gender: Optional[str] = None
    language: Optional[str] = "English"
    personality_type: Optional[str] = "The Adventurer"
    is_private: bool = False
    is_online: bool = False
    compatibility_score: int = 85

def _clean_photo(url: Optional[str]) -> Optional[str]:
    if not url or "dicebear.com" in url:
        return None
    return url

@router.get("/swipe-discovery", response_model=List[DiscoverUserResponse])
async def swipe_discovery(
    interest: Optional[str] = Query(None),
    country: Optional[str] = Query(None),
    gender: Optional[str] = Query(None),
    language: Optional[str] = Query(None),
    min_age: Optional[int] = Query(None),
    max_age: Optional[int] = Query(None),
    current_user: User = Depends(get_current_user)
):
    """
    Advanced Tinder-inspired Discovery Algorithm.
    Strictly excludes:
    - Current user
    - Banned or shadow-banned users
    - Admins/super_admins
    - Users blocked by current user or users who blocked current user
    - Users already followed by current user
    - Users with existing pending follow requests
    - Recently skipped profiles (unless reset)
    """
    me = current_user.anonymous_username

    # Fetch users already followed
    follows = await Follow.find({"follower_id": me}).to_list()
    followed_usernames = {f.following_id for f in follows}

    # Fetch pending follow requests (sent or received)
    pending_reqs = await FollowRequest.find({
        "$or": [
            {"from_user_id": me, "status": "pending"},
            {"to_user_id": me, "status": "pending"}
        ]
    }).to_list()
    pending_usernames = {r.to_user_id if r.from_user_id == me else r.from_user_id for r in pending_reqs}

    # Fetch user's swipes (likes & passes)
    swipes = await Swipe.find({"user_id": me}).to_list()
    swiped_usernames = {s.target_user_id for s in swipes}

    # Blocked users
    blocked_by_me = set(current_user.blocked_users)

    # Combine all exclusions
    excluded_usernames = {me} | followed_usernames | pending_usernames | swiped_usernames | blocked_by_me

    # Base query
    query = {
        "anonymous_username": {"$nin": list(excluded_usernames)},
        "blocked_users": {"$ne": me},
        "is_banned": False,
        "shadow_banned": False,
        "role": {"$nin": ["admin", "super_admin"]}
    }

    if interest and interest.strip():
        query["interests"] = interest.strip()

    if country and country.strip():
        query["country"] = country.strip()

    if gender and gender.strip() and gender.lower() != "everyone":
        query["gender"] = gender.strip()

    if language and language.strip():
        query["language"] = language.strip()

    if min_age or max_age:
        age_filter = {}
        if min_age:
            age_filter["$gte"] = min_age
        if max_age:
            age_filter["$lte"] = max_age
        query["age"] = age_filter

    potential_pool = await User.find(query).limit(100).to_list()

    if not potential_pool:
        return []

    scored_users = []
    now = datetime.now(timezone.utc)

    for u in potential_pool:
        score = 50.0

        # Interest similarity (40%)
        if current_user.interests and u.interests:
            common = set(current_user.interests) & set(u.interests)
            score += (len(common) / max(len(current_user.interests), 1)) * 40.0

        # Same country (15%)
        if u.country and current_user.country and u.country.lower() == current_user.country.lower():
            score += 15.0

        # Trust score (15%)
        score += (u.trust_score / 100.0) * 15.0

        # Online / Recently active (15%)
        if u.last_active:
            delta_mins = (now - u.last_active.replace(tzinfo=timezone.utc)).total_seconds() / 60.0
            if delta_mins < 15:
                score += 15.0
            elif delta_mins < 120:
                score += 10.0

        # Random jitter for freshness
        score += random.random() * 5.0

        scored_users.append((score, u))

    scored_users.sort(key=lambda x: x[0], reverse=True)
    top_candidates = scored_users[:30]

    my_following = {f.following_id for f in await Follow.find({"follower_id": me}).to_list()}

    response_list = []
    for score, user in top_candidates:
        user_interests = set(user.interests or [])
        my_interests = set(current_user.interests or [])
        overlap = list(my_interests & user_interests)

        user_following = {f.following_id for f in await Follow.find({"follower_id": user.anonymous_username}).to_list()}
        mutuals = len(my_following & user_following)

        response_list.append(
            DiscoverUserResponse(
                id=str(user.id),
                username=user.anonymous_username,
                display_name=user.display_name or user.anonymous_username,
                avatar_url=_clean_photo(user.profile_photo_url or user.avatar_url),
                profile_photo_url=_clean_photo(user.profile_photo_url or user.avatar_url),
                bio=user.bio or "Exploring Zenvora ✨",
                trust_score=user.trust_score,
                interests=user.interests or [],
                overlap_interests=overlap,
                mutual_connections_count=mutuals,
                country=user.country or "Global",
                age=user.age,
                gender=user.gender,
                language=user.language or "English",
                personality_type=user.personality_type or "The Adventurer",
                is_private=user.is_private,
                is_online=True if user.last_active and (datetime.utcnow() - user.last_active).total_seconds() < 300 else False,
                compatibility_score=min(99, max(65, int(score)))
            )
        )

    return response_list

@router.post("/reset-swipes")
async def reset_swipes(current_user: User = Depends(get_current_user)):
    """Reset passed profiles so user can rediscover people."""
    await Swipe.find({"user_id": current_user.anonymous_username, "action": "pass"}).delete()
    return {"success": True, "message": "Discovery history reset successfully!"}
