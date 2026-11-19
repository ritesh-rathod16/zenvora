from typing import List, Optional, Dict, Any
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Reel(Document):
    author_id: str # anonymous_username
    video_url: str
    thumbnail_url: Optional[str] = None
    caption: str = ""
    hashtags: List[str] = []
    likes: List[str] = [] # List of anonymous_usernames who liked
    reposts: List[str] = [] # List of anonymous_usernames who reposted
    shares_count: int = 0
    comments: List[Dict[str, Any]] = [] # [{id, author_id, content, created_at}]
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "reels"
        indexes = ["author_id", "created_at"]
