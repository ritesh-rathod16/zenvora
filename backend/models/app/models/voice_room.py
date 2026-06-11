from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class VoiceRoom(Document):
    title: str
    description: str
    category: str # Startup, Gaming, Music, etc.
    creator_id: str # anonymous_username
    livekit_room_id: Optional[str] = None
    listener_count: int = 0
    peak_listeners: int = 0
    recording_enabled: bool = False
    is_private: bool = False
    is_featured: bool = False
    tags: List[str] = []
    energy_score: float = 0.0 # Real-time activity score
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "voice_rooms"
