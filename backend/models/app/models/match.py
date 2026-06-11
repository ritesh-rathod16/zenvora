from beanie import Document
from datetime import datetime
from pydantic import Field

class Match(Document):
    user1: str # anonymous_username
    user2: str # anonymous_username
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "matches"
