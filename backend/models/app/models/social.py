from typing import List, Optional, Dict
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Follow(Document):
    follower_id: Indexed(str)
    following_id: Indexed(str)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "follows"

class FollowRequest(Document):
    from_user_id: Indexed(str)
    to_user_id: Indexed(str)
    status: str = "pending" # pending, accepted, rejected
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "follow_requests"

class Post(Document):
    author: str # anonymous_username
    image_url: Optional[str] = None
    caption: str
    likes: List[str] = [] # List of anonymous_usernames
    comments: List[Dict] = [] # List of {username, text, timestamp}
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "posts"
        indexes = ["author", "created_at"]
