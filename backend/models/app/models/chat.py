from typing import List, Optional
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Message(Document):
    chat_id: Indexed(str)
    sender_id: str
    content: str
    message_type: str = "text" # text, voice, photo, video, gif, sticker
    is_read: bool = False
    
    # Privacy features
    view_once: bool = False
    delete_after: Optional[int] = None # Seconds
    
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "messages"

class Chat(Document):
    participants: List[str] # anonymous_usernames
    last_message: Optional[str] = None
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Chat privacy setting
    auto_delete_mode: str = "none" # none, read, 24h, 7d

    class Settings:
        name = "chats"
