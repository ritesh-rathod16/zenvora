from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from ...models.user import User
from ...models.post import Post
from ...models.reel import Reel
from ..models.interaction import UserInterestProfile

class RankingEngine:
    @staticmethod
    def score_post(post: Post, user: User, interest_profile: Optional[UserInterestProfile] = None) -> float:
        score = 50.0

        # Recency boost
        now = datetime.now(timezone.utc)
        created = post.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)

        hours_old = max(0.1, (now - created).total_seconds() / 3600.0)
        recency_score = max(0.0, 30.0 - (hours_old * 1.5))
        score += recency_score

        # Engagement popularity score
        score += min(20.0, len(post.likes) * 1.5 + post.replies_count * 2.0)

        # Creator affinity boost
        if interest_profile and post.author_id in interest_profile.creator_affinities:
            score += interest_profile.creator_affinities[post.author_id] * 10.0

        return score

    @staticmethod
    def rank_posts(posts: List[Post], user: User, interest_profile: Optional[UserInterestProfile] = None) -> List[Post]:
        scored = [(RankingEngine.score_post(p, user, interest_profile), p) for p in posts]
        scored.sort(key=lambda x: x[0], reverse=True)

        # Apply Diversity Re-ranking (prevent >2 consecutive posts from same author)
        ranked = []
        author_counts = {}
        for s, p in scored:
            author = p.author_id
            if author_counts.get(author, 0) < 3:
                ranked.append(p)
                author_counts[author] = author_counts.get(author, 0) + 1

        return ranked

    @staticmethod
    def rank_reels(reels: List[Reel], user: User, interest_profile: Optional[UserInterestProfile] = None) -> List[Reel]:
        scored = []
        for r in reels:
            s = 50.0 + min(30.0, len(r.likes) * 2.0 + len(r.reposts) * 3.0)
            if interest_profile and r.author_id in interest_profile.creator_affinities:
                s += interest_profile.creator_affinities[r.author_id] * 15.0
            scored.append((s, r))

        scored.sort(key=lambda x: x[0], reverse=True)
        return [r for s, r in scored]
