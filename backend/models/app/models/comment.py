from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Comment(Document):
    post_id: Indexed(str)
    author_id: str # anonymous_username
    content: str
    parent_comment_id: Optional[str] = None # For threaded replies
    likes: List[str] = [] # Usernames who liked this comment
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "comments"
        indexes = ["post_id", "author_id", "created_at"]
