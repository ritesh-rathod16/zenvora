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
    expires_at: datetime # 24 hours from creation
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "posts"
