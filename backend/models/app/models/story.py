from typing import List, Optional, Dict, Any
from beanie import Document
from pydantic import Field
from datetime import datetime, timedelta

class Story(Document):
    author_id: str
    media_url: str
    media_type: str = "image"
    caption: Optional[str] = None
    stickers: List[Dict[str, Any]] = []
    poll: Optional[Dict[str, Any]] = None
    question_box: Optional[Dict[str, Any]] = None
    location_tag: Optional[str] = None
    music_track: Optional[Dict[str, Any]] = None

    is_close_friends_only: bool = False
    save_to_archive: bool = True

    likes: List[str] = []
    views: List[Dict[str, Any]] = []
    reactions: List[Dict[str, Any]] = []

    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(default_factory=lambda: datetime.utcnow() + timedelta(hours=24))

    class Settings:
        name = "stories"
        indexes = [
            [("author_id", 1)],
            [("expires_at", 1)],
            "created_at"
        ]
