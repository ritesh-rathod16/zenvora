from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime
from typing import Optional
import pymongo

class Report(Document):
    reporter_id: str # anonymous_username
    reported_id: str # anonymous_username
    reason: str
    content_id: Optional[str] = None # ID of the post or message reported
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    details: Optional[str] = None
    status: str = "pending" # pending, reviewed, resolved
    resolution: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "reports"
        indexes = [
            pymongo.IndexModel([("reporter_id", pymongo.ASCENDING), ("reported_id", pymongo.ASCENDING)], name="idx_reports_pair_direction"),
            pymongo.IndexModel([("reported_id", pymongo.ASCENDING), ("reporter_id", pymongo.ASCENDING)], name="idx_reports_reverse_pair"),
        ]
