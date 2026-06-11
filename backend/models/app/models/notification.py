from typing import Optional, List
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Notification(Document):
    user_id: Indexed(str) # anonymous_username of recipient
    type: str # match, message, star, like, follow, announcement
    actor_ids: List[str] = [] # anonymous_usernames of users who triggered this (for grouping)
    message: str
    priority_score: int = 0 # higher is more important
    read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: Optional[dict] = {} # e.g. chat_id, post_id, request_id

    class Settings:
        name = "notifications"
        indexes = [
            "user_id",
            "created_at",
            "priority_score",
            [("user_id", 1), ("read", 1)]
        ]
