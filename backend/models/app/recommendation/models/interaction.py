from typing import Optional, Dict, Any
from beanie import Document
from pydantic import Field
from datetime import datetime

class InteractionEvent(Document):
    user_id: str # recipient/actor username
    content_id: str
    content_type: str # post, reel, story, room, user, query
    event_type: str # impression, view, like, comment, save, share, watch_start, watch_complete, skip, hide, not_interested
    watch_duration: float = 0.0 # seconds watched
    content_duration: float = 0.0 # total media duration
    completion_rate: float = 0.0 # watch_duration / content_duration
    recommendation_source: Optional[str] = None # feed, explore, reels, search, people
    model_version: Optional[str] = "v1_hybrid"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: Dict[str, Any] = {}

    model_config = {"protected_namespaces": ()}

    class Settings:
        name = "interaction_events"
        indexes = [
            [("user_id", 1)],
            [("user_id", 1), ("event_type", 1)],
            [("content_id", 1)],
            "created_at"
        ]

class UserInterestProfile(Document):
    user_id: str
    category_weights: Dict[str, float] = {} # e.g. {"Technology": 0.85, "Music": 0.60}
    creator_affinities: Dict[str, float] = {} # e.g. {"CyberSamurai": 0.90}
    content_type_preferences: Dict[str, float] = {} # e.g. {"reel": 0.8, "post": 0.5}
    negative_topics: Dict[str, float] = {} # penalized topics/creators
    last_updated: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "user_interest_profiles"
        indexes = [
            [("user_id", 1)]
        ]
