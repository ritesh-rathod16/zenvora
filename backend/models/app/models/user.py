from typing import Optional, List, Annotated
from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime

class User(Document):
    real_name: str # Private
    email: Annotated[EmailStr, Indexed(unique=True)]
    anonymous_username: Annotated[str, Indexed(unique=True, sparse=True)] # Public anonymous ID
    password_hash: str
    age: int
    country: str
    interests: List[str] = []
    bio: Optional[str] = ""
    
    avatar_url: Optional[str] = None
    profile_photo_url: Optional[str] = None 
    
    # Feature 4: Star System
    weekly_star_count: int = 0
    weekly_star_reset: datetime = Field(default_factory=datetime.utcnow)
    
    # Emotional & Ghost Identity System
    current_mood: str = "neutral" # lonely, anxious, chaotic, sleepy, etc.
    social_battery: int = 100
    voice_aura: str = "Cyber Purple" # Cyber Purple, Ghost Blue, Dreamcore, etc.
    ghost_mode: bool = False
    invisible_listening: bool = False
    alias_rotation_enabled: bool = True
    last_alias_rotation: datetime = Field(default_factory=datetime.utcnow)
    
    gender: Optional[str] = "unknown"
    interested_in: Optional[str] = "everyone" # male, female, everyone
    age_min: int = 18
    age_max: int = 35
    
    trust_score: int = 100
    activity_score: int = 0
    is_active: bool = False
    is_admin: bool = False
    role: str = "user" # user, moderator, admin, super_admin
    is_banned: bool = False
    shadow_banned: bool = False
    ban_reason: Optional[str] = None
    
    # Social Features (Counts only, arrays moved to separate collections)
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0
    
    verification_token: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_active: datetime = Field(default_factory=datetime.utcnow)

    # Personality & Matching
    personality_type: Optional[str] = "The Adventurer"
    interest_cluster: Optional[str] = None
    compatibility_vector: List[float] = []

    class Settings:
        name = "users"
