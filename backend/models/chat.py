from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Message(Document):
    chat_id: Indexed(str)
    sender_id: str
    content: str
    message_type: str = "text" # text, voice, photo, video, gif
    is_read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Privacy features
    delete_after: Optional[int] = None # seconds
    view_once: bool = False

    class Settings:
        name = "messages"

class Chat(Document):
    participants: List[str] # List of anonymous_usernames
    last_message: Optional[str] = None
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "chats"
