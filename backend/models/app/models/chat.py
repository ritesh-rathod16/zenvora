from typing import List, Optional, Dict, Any
from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime

class Message(Document):
    chat_id: Indexed(str)
    sender_id: str
    content: str
    message_type: str = "text" # text, voice, photo, video, gif, sticker, post_share, story_reply, story_reaction, system
    attachment_url: Optional[str] = None
    is_read: bool = False
    
    # Receipt & Disappearing message timestamps
    delivered_at: Optional[datetime] = None
    viewed_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None
    deletion_mode: str = "never_delete" # immediately_delete, delete_24h, never_delete
    
    # Interactions
    reply_to_message_id: Optional[str] = None
    reactions: List[Dict[str, str]] = [] # [{"username": "alice", "emoji": "❤️"}]
    
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "messages"
        indexes = ["chat_id", "created_at", "expires_at", "deleted_at", "deletion_mode"]

class Chat(Document):
    participants: List[str] # anonymous_usernames
    last_message: Optional[str] = None
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Disappearing message mode: immediately_delete, delete_24h, never_delete
    auto_delete_mode: str = "never_delete"
    custom_theme: Optional[str] = None
    muted_by: List[str] = [] # Usernames who muted this chat
    
    # Group chat support
    is_group: bool = False
    group_name: Optional[str] = None
    group_admin_ids: List[str] = []

    class Settings:
        name = "chats"
        indexes = ["participants", "updated_at"]
