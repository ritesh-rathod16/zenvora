from typing import Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class StarRequest(Document):
    sender: Indexed(str) # anonymous_username
    receiver: Indexed(str) # anonymous_username
    message: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "star_requests"
