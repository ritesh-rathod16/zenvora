from typing import List, Optional, Dict
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Follow(Document):
    follower_id: str # username or ID
    following_id: str # username or ID
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "follows"
        indexes = [
            [("follower_id", 1), ("following_id", 1)], # Compound index for fast queries and uniqueness
            "follower_id",
            "following_id"
        ]

class FollowRequest(Document):
    from_user_id: str
    to_user_id: str
    status: str = "pending" # pending, accepted, declined, cancelled
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "follow_requests"
        indexes = [
            [("from_user_id", 1), ("to_user_id", 1)],
            "to_user_id",
            "status"
        ]
