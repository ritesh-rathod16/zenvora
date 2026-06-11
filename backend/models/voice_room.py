from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class VoiceRoom(Document):
    title: str
    description: str
    creator_id: str # anonymous_username
    participants: List[str] = [] # anonymous_usernames
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    category: str # Startup, Gaming, Music, etc.

    class Settings:
        name = "voice_rooms"
