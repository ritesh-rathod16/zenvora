from beanie import Document
from datetime import datetime
from pydantic import Field
import pymongo

class Match(Document):
    user1: str # anonymous_username
    user2: str # anonymous_username
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "matches"
        indexes = [
            pymongo.IndexModel([("user1", pymongo.ASCENDING), ("created_at", pymongo.DESCENDING)], name="idx_matches_user1_created"),
            pymongo.IndexModel([("user2", pymongo.ASCENDING), ("created_at", pymongo.DESCENDING)], name="idx_matches_user2_created"),
        ]
