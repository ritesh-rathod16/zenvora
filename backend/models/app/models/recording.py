from beanie import Document
from pydantic import Field
from datetime import datetime
from typing import Optional

class Recording(Document):
    room_id: str
    livekit_room_id: str
    file_key: str
    url: str
    duration_seconds: Optional[int] = 0
    size_bytes: Optional[int] = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "recordings"
