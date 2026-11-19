from typing import Optional, List
from beanie import Document
from pydantic import Field
from datetime import datetime, timedelta

class UserNote(Document):
    user_id: str # username of note creator
    content: str # text/emoji note up to 60 chars
    visibility: str = "followers" # followers or close_friends
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(default_factory=lambda: datetime.utcnow() + timedelta(hours=24))

    class Settings:
        name = "user_notes"
        indexes = [
            [("user_id", 1)],
            [("expires_at", 1)],
            "created_at"
        ]
