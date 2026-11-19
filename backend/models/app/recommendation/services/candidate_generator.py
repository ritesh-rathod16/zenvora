from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta, timezone
from ...models.user import User
from ...models.post import Post
from ...models.reel import Reel
from ...models.social import Follow

class CandidateGenerator:
    @staticmethod
    async def get_feed_candidates(user: User, limit: int = 40) -> List[Post]:
        me = user.anonymous_username
        now = datetime.now(timezone.utc)

        # Exclude blocked users and user's own posts
        blocked = set(user.blocked_users or [])
        blocked.add(me)

        # 1. Posts from followed users
        following = {f.following_id for f in await Follow.find({"follower_id": me}).to_list()}
        followed_posts = await Post.find({
            "author_id": {"$in": list(following - blocked)},
            "expires_at": {"$gt": now}
        }).sort(-Post.created_at).limit(limit // 2).to_list()

        # 2. General high-quality posts
        other_posts = await Post.find({
            "author_id": {"$nin": list(blocked | following)},
            "expires_at": {"$gt": now}
        }).sort(-Post.likes).limit(limit // 2).to_list()

        # Deduplicate candidates
        seen_ids = set()
        candidates = []
        for p in followed_posts + other_posts:
            pid = str(p.id)
            if pid not in seen_ids:
                seen_ids.add(pid)
                candidates.append(p)

        return candidates

    @staticmethod
    async def get_reels_candidates(user: User, limit: int = 30) -> List[Reel]:
        me = user.anonymous_username
        blocked = set(user.blocked_users or [])

        # Fetch recent reels excluding blocked creators
        reels = await Reel.find({
            "author_id": {"$nin": list(blocked)}
        }).sort(-Reel.created_at).limit(limit).to_list()

        return reels

    @staticmethod
    async def get_people_candidates(user: User, limit: int = 20) -> List[User]:
        me = user.anonymous_username
        blocked = set(user.blocked_users or [])

        following = {f.following_id for f in await Follow.find({"follower_id": me}).to_list()}
        exclude_set = blocked | following | {me}

        candidates = await User.find({
            "anonymous_username": {"$nin": list(exclude_set)},
            "is_banned": False,
            "role": {"$nin": ["admin", "super_admin"]}
        }).limit(limit).to_list()

        return candidates
