from datetime import datetime
from typing import List, Optional

import pymongo
from beanie import Document
from pydantic import Field


class Vibe(Document):
    """Backend-managed category used by the vibe matcher."""

    vibe_id: str = Field(..., min_length=2, max_length=48)
    label: str = Field(..., min_length=2, max_length=48)
    emoji: str = Field(default="✨", max_length=8)
    description: str = Field(default="", max_length=160)
    compatible_vibes: List[str] = Field(default_factory=list)
    allow_fallback: bool = True
    fallback_group: Optional[str] = Field(default="social", max_length=32)
    minimum_age: int = Field(default=13, ge=13, le=120)
    is_active: bool = True
    display_order: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "vibes"
        indexes = [
            pymongo.IndexModel([("vibe_id", pymongo.ASCENDING)], unique=True, name="idx_vibes_id"),
            pymongo.IndexModel([("is_active", pymongo.ASCENDING), ("display_order", pymongo.ASCENDING)], name="idx_vibes_active_order"),
        ]


class UserVibe(Document):
    """A user's private, expiring active vibe and optional match preferences."""

    user_id: str
    vibe_id: str
    preferred_vibes: List[str] = Field(default_factory=list)
    expires_at: datetime
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "user_vibes"
        indexes = [
            pymongo.IndexModel([("user_id", pymongo.ASCENDING)], unique=True, name="idx_user_vibes_user_id"),
            pymongo.IndexModel([("expires_at", pymongo.ASCENDING)], expireAfterSeconds=0, name="idx_user_vibes_expiry_ttl"),
        ]


DEFAULT_VIBES = [
    {"vibe_id": "chill", "label": "Chill", "emoji": "😌", "description": "Easygoing conversation", "compatible_vibes": ["bored", "want-to-talk", "deep-conversations", "music", "funny-memes", "late-night-talks", "making-friends"], "display_order": 10},
    {"vibe_id": "bored", "label": "Bored", "emoji": "🥱", "description": "Find something fun to do", "compatible_vibes": ["chill", "funny-memes", "making-friends", "adventure"], "display_order": 20},
    {"vibe_id": "want-to-talk", "label": "Want to Talk", "emoji": "💬", "description": "Meet someone up for a conversation", "compatible_vibes": ["chill", "deep-conversations", "making-friends", "late-night-talks", "vent-listening"], "display_order": 30},
    {"vibe_id": "deep-conversations", "label": "Deep Conversations", "emoji": "🌙", "description": "Talk about the things that matter", "compatible_vibes": ["chill", "want-to-talk", "late-night-talks", "vent-listening"], "display_order": 40},
    {"vibe_id": "gaming", "label": "Gaming", "emoji": "🎮", "description": "Talk games or find a player", "compatible_vibes": ["gaming"], "fallback_group": "gaming", "display_order": 50},
    {"vibe_id": "music", "label": "Music", "emoji": "🎵", "description": "Share what you are listening to", "compatible_vibes": ["chill", "music"], "display_order": 60},
    {"vibe_id": "funny-memes", "label": "Funny / Memes", "emoji": "😂", "description": "Keep it light and funny", "compatible_vibes": ["chill", "bored", "making-friends"], "display_order": 70},
    {"vibe_id": "study-buddy", "label": "Study Buddy", "emoji": "📚", "description": "Find a focused study companion", "compatible_vibes": ["study-buddy"], "allow_fallback": False, "fallback_group": "study", "display_order": 80},
    {"vibe_id": "making-friends", "label": "Making Friends", "emoji": "🤝", "description": "Meet someone new", "compatible_vibes": ["chill", "bored", "want-to-talk", "funny-memes", "adventure"], "display_order": 90},
    {"vibe_id": "late-night-talks", "label": "Late Night Talks", "emoji": "🌌", "description": "A conversation for the quiet hours", "compatible_vibes": ["chill", "want-to-talk", "deep-conversations"], "display_order": 100},
    {"vibe_id": "vent-listening", "label": "Vent / Need Someone to Listen", "emoji": "🫶", "description": "Find someone willing to listen", "compatible_vibes": ["want-to-talk", "deep-conversations", "vent-listening"], "display_order": 110},
    {"vibe_id": "adventure", "label": "Adventure", "emoji": "🧭", "description": "Plan, share, or talk about adventures", "compatible_vibes": ["bored", "making-friends", "adventure"], "display_order": 120},
    {"vibe_id": "flirting", "label": "Flirting", "emoji": "💜", "description": "Flirty conversation for adults", "compatible_vibes": ["flirting"], "allow_fallback": False, "fallback_group": "adult", "minimum_age": 18, "display_order": 130},
]
