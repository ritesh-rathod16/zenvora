from typing import List, Optional, Dict, Any
from beanie import Document
from pydantic import Field
from datetime import datetime

class Reel(Document):
    author_id: str # anonymous_username
    video_url: str
    thumbnail_url: Optional[str] = None
    caption: str = ""
    hashtags: List[str] = []
    likes: List[str] = []
    reposts: List[str] = []
    shares_count: int = 0
    comments: List[Dict[str, Any]] = []

    # New management fields
    is_archived: bool = False
    is_pinned: bool = False
    comments_disabled: bool = False
    hide_like_count: bool = False
    collection_name: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "reels"
        indexes = ["author_id", "created_at", "is_archived", "is_pinned"]
