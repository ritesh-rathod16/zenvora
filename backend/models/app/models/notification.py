from typing import Optional, List, Dict, Any
from beanie import Document
from pydantic import Field, model_validator
from datetime import datetime

class Notification(Document):
    recipient_id: Optional[str] = None
    user_id: Optional[str] = None
    actor_id: Optional[str] = None
    actor_ids: List[str] = []
    type: str = "activity"
    category: str = "social"
    title: str = "Activity"
    message: str = ""
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    related_post_id: Optional[str] = None
    related_reel_id: Optional[str] = None
    related_story_id: Optional[str] = None
    conversation_id: Optional[str] = None
    read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: Dict[str, Any] = {}

    @model_validator(mode='before')
    @classmethod
    def set_recipient(cls, values: Any) -> Any:
        if isinstance(values, dict):
            if not values.get("recipient_id") and values.get("user_id"):
                values["recipient_id"] = values["user_id"]
            if not values.get("user_id") and values.get("recipient_id"):
                values["user_id"] = values["recipient_id"]
            if not values.get("title"):
                values["title"] = "Activity"
        return values

    class Settings:
        name = "notifications"
        indexes = [
            [("recipient_id", 1)],
            [("user_id", 1)],
            [("recipient_id", 1), ("read", 1)],
            [("recipient_id", 1), ("category", 1)],
            "created_at"
        ]
