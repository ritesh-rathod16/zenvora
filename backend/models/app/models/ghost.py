from typing import Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class GhostIdentity(Document):
    user_id: Indexed(str, unique=True)
    alias: str
    avatar_url: str
    expires_at: Indexed(datetime)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "ghost_identities"
