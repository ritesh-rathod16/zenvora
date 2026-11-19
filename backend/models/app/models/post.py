from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Post(Document):
    author_id: str # anonymous_username
    content: str
    media_url: Optional[str] = None
    likes: List[str] = [] # List of anonymous_usernames
    replies_count: int = 0 # Comments count
    reposts: List[str] = [] # Usernames who reposted
    shares_count: int = 0
    is_repost: bool = False
    original_author_id: Optional[str] = None
    original_post_id: Optional[str] = None
    expires_at: datetime # Lifespan
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "posts"
        indexes = ["author_id", "created_at", "original_post_id"]
