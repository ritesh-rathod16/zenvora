from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class LiveStream(Document):
    host_id: str
    title: str
    is_live: bool = True
    viewers_count: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "livestreams"
        indexes = [
            [("host_id", 1)],
            "is_live",
            "created_at"
        ]
