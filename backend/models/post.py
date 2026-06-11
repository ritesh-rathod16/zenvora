from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Post(Document):
    author_id: str # anonymous_username
    content: str
    media_url: Optional[str] = None
    likes: List[str] = [] # List of anonymous_usernames
    replies_count: int = 0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime # Posts disappear after 24 hours

    class Settings:
        name = "posts"
