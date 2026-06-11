from typing import Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class CallSession(Document):
    caller_id: str # anonymous_username
    receiver_id: str # anonymous_username
    chat_id: str
    call_type: str # "video" or "voice"
    status: str = "ringing" # "ringing", "active", "ended", "rejected"
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "call_sessions"
