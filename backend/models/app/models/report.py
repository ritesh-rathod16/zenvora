from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime
from typing import Optional

class Report(Document):
    reporter_id: str # anonymous_username
    reported_id: str # anonymous_username
    reason: str
    content_id: Optional[str] = None # ID of the post or message reported
    status: str = "pending" # pending, reviewed, resolved
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "reports"
