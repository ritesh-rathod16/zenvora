from beanie import Document
from datetime import datetime
from typing import List, Optional
from pydantic import Field
import pymongo

class MatchQueue(Document):
    user_id: str = Field(..., description="Unique user identifier or socket session ID")
    interests: List[str] = Field(default_factory=list, description="User selected interests")
    region: str = Field(default="Global", description="User region/locale")
    trust_score: int = Field(default=100, description="Trust score of the user")
    status: str = Field(default="waiting", description="'waiting', 'claimed', 'matched', 'cancelled'")
    matched_with: Optional[str] = Field(default=None, description="Partner user ID if matched")
    matching_session_id: Optional[str] = Field(default=None, description="Session ID of the active claim")
    lease_expires_at: Optional[datetime] = Field(default=None, description="Expiration time for claim lease")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "match_queue"
        indexes = [
            pymongo.IndexModel([("user_id", pymongo.ASCENDING)], unique=True, name="idx_match_queue_user_id"),
            pymongo.IndexModel(
                [("status", pymongo.ASCENDING), ("trust_score", pymongo.DESCENDING), ("created_at", pymongo.ASCENDING)],
                name="idx_match_queue_status_trust_created"
            ),
            pymongo.IndexModel(
                [("status", pymongo.ASCENDING), ("region", pymongo.ASCENDING)],
                name="idx_match_queue_status_region"
            ),
            pymongo.IndexModel(
                [("status", pymongo.ASCENDING), ("lease_expires_at", pymongo.ASCENDING)],
                name="idx_match_queue_status_lease"
            ),
            pymongo.IndexModel([("matching_session_id", pymongo.ASCENDING)], name="idx_match_queue_session_id"),
        ]
