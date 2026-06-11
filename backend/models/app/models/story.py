from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime, timedelta

class Story(Document):
    author_id: str # anonymous_username
    media_url: str
    views: List[str] = [] # List of anonymous_usernames
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(default_factory=lambda: datetime.utcnow() + timedelta(hours=24))

    class Settings:
        name = "stories"
        indexes = ["expires_at"]
