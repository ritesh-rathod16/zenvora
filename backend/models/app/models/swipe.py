from typing import Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Swipe(Document):
    user_id: Indexed(str) # The user who is swiping
    target_user_id: Indexed(str) # The user being swiped on
    action: str # "like", "pass", "super_like"
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "swipes"
        indexes = [
            [("user_id", 1), ("target_user_id", 1)]
        ]
