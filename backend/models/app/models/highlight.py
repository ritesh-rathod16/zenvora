from typing import List, Optional
from beanie import Document
from pydantic import Field
from datetime import datetime

class StoryHighlight(Document):
    user_id: str # username of owner
    title: str # e.g. "Tokyo 2026"
    cover_url: Optional[str] = None
    story_ids: List[str] = []
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "story_highlights"
        indexes = [
            [("user_id", 1)],
            "created_at"
        ]
