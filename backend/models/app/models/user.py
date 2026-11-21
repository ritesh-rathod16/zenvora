from typing import Optional, List, Annotated
from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime

class User(Document):
    full_name: str = "Zenvora User" # Separate Display Name
    display_name: Optional[str] = None
    real_name: Optional[str] = None
    email: Annotated[EmailStr, Indexed(unique=True)]
    anonymous_username: str # Unique normalized handle
    normalized_username: str = "zenvora_user" # Lowercase for case-insensitive uniqueness
    password_hash: str
    date_of_birth: Optional[str] = None # YYYY-MM-DD
    age: Optional[int] = None
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    interested_in: Optional[str] = "everyone"
    gender: Optional[str] = "prefer_not_to_say"
    country: Optional[str] = "Global"
    city: Optional[str] = None
    interests: List[str] = []
    bio: Optional[str] = ""
    website: Optional[str] = None

    avatar_url: Optional[str] = None
    profile_photo_url: Optional[str] = None
    voice_intro_url: Optional[str] = None
    public_encryption_key: Optional[str] = None

    # Privacy & Visibility Settings
    is_private: bool = False
    visibility_settings: dict = Field(default_factory=lambda: {
        "show_age": True,
        "show_country": True,
        "show_interests": True
    })

    notifications_enabled: dict = Field(default_factory=lambda: {
        "likes": True,
        "comments": True,
        "follows": True,
        "messages": True,
        "stories": True
    })
    blocked_users: List[str] = []
    muted_users: List[str] = []
    close_friends: List[str] = []
    hide_story_from: List[str] = []
    saved_reels: List[str] = []
    saved_posts: List[str] = []
    chat_settings: dict = Field(default_factory=lambda: {
        "auto_delete_mode": "off",
        "theme": "default"
    })
    story_settings: dict = Field(default_factory=lambda: {
        "allow_story_likes": True,
        "allow_story_replies": True,
        "save_to_archive": True
    })
    language: Optional[str] = "English"
    theme_preference: str = "dark"
    current_mood: Optional[str] = "neutral"
    voice_aura: Optional[str] = "Default"
    social_battery: Optional[int] = 100
    personality_type: Optional[str] = "The Adventurer"

    # Social Counts
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0

    trust_score: int = 100
    activity_score: int = 0
    is_active: bool = False
    is_admin: bool = False
    role: str = "user"
    is_banned: bool = False
    shadow_banned: bool = False
    verification_token: Optional[str] = None
    verification_expires_at: Optional[datetime] = None
    token_version: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_active: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "users"
        indexes = [
            [("normalized_username", 1)],
            "anonymous_username",
            "country",
            "interests"
        ]
