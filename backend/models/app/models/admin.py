from typing import Optional, Any
from beanie import Document
from pydantic import Field
from datetime import datetime

class AdminLog(Document):
    admin_email: str
    action: str
    target: Optional[str] = None
    details: Optional[Any] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "admin_logs"

class PlatformSettings(Document):
    registrations_enabled: bool = True
    posting_enabled: bool = True
    video_chat_enabled: bool = True
    image_uploads_enabled: bool = True
    maintenance_mode: bool = False
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "platform_settings"
