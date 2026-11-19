from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta, timezone
from ..models.interaction import InteractionEvent, UserInterestProfile
from ...models.user import User

class InterestService:
    @staticmethod
    async def get_or_create_profile(user: User) -> UserInterestProfile:
        uname = user.anonymous_username
        profile = await UserInterestProfile.find_one({"user_id": uname})
        if not profile:
            initial_weights = {interest: 1.0 for interest in (user.interests or [])}
            profile = UserInterestProfile(
                user_id=uname,
                category_weights=initial_weights,
                creator_affinities={},
                content_type_preferences={"post": 0.5, "reel": 0.8, "story": 0.6},
                negative_topics={},
                last_updated=datetime.now(timezone.utc)
            )
            await profile.insert()
        return profile

    @staticmethod
    async def record_interaction(
        user: User,
        content_id: str,
        content_type: str,
        event_type: str,
        watch_duration: float = 0.0,
        content_duration: float = 0.0,
        category: Optional[str] = None,
        author_id: Optional[str] = None,
        recommendation_source: Optional[str] = None
    ) -> InteractionEvent:
        completion_rate = (watch_duration / content_duration) if content_duration > 0 else 0.0

        event = InteractionEvent(
            user_id=user.anonymous_username,
            content_id=content_id,
            content_type=content_type,
            event_type=event_type,
            watch_duration=watch_duration,
            content_duration=content_duration,
            completion_rate=completion_rate,
            recommendation_source=recommendation_source,
            created_at=datetime.now(timezone.utc)
        )
        await event.insert()

        # Asynchronously update interest weights
        await InterestService.update_user_interest(user.anonymous_username, event_type, category, author_id, completion_rate)

        return event

    @staticmethod
    async def update_user_interest(
        user_id: str,
        event_type: str,
        category: Optional[str],
        author_id: Optional[str],
        completion_rate: float
    ):
        profile = await UserInterestProfile.find_one({"user_id": user_id})
        if not profile:
            return

        # Weight deltas based on engagement strength
        weight_delta = 0.0
        if event_type in ["like", "save", "share"]:
            weight_delta = 0.2
        elif event_type == "comment":
            weight_delta = 0.25
        elif event_type == "watch_complete" or completion_rate > 0.8:
            weight_delta = 0.15
        elif event_type in ["skip", "hide", "not_interested"]:
            weight_delta = -0.3

        if category and weight_delta != 0.0:
            cur = profile.category_weights.get(category, 0.5)
            profile.category_weights[category] = max(0.0, min(5.0, cur + weight_delta))

        if author_id and weight_delta > 0.0:
            cur_aff = profile.creator_affinities.get(author_id, 0.0)
            profile.creator_affinities[author_id] = max(0.0, min(5.0, cur_aff + weight_delta))

        profile.last_updated = datetime.now(timezone.utc)
        await profile.save()

    @staticmethod
    async def reset_user_interests(user: User) -> UserInterestProfile:
        uname = user.anonymous_username
        profile = await UserInterestProfile.find_one({"user_id": uname})
        if profile:
            profile.category_weights = {interest: 1.0 for interest in (user.interests or [])}
            profile.creator_affinities = {}
            profile.negative_topics = {}
            profile.last_updated = datetime.now(timezone.utc)
            await profile.save()
            return profile
        return await InterestService.get_or_create_profile(user)
