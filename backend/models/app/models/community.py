from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Community(Document):
    name: str
    description: str
    category: str = "General"
    is_private: bool = False
    admin_ids: List[str] = [] # Usernames
    members: List[str] = [] # Usernames
    cover_url: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "communities"
        indexes = [
            [("name", 1)],
            "category",
            "members"
        ]

class StoryHighlight(Document):
    user_id: Indexed(str)
    title: str
    cover_url: Optional[str] = None
    story_ids: List[str] = []
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "story_highlights"
        indexes = ["user_id"]
