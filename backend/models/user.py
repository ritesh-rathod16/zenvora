from typing import Optional, List
from beanie import Document, Indexed
from pydantic import EmailStr, Field
from datetime import datetime

class User(Document):
    real_name: str
    email: Indexed(EmailStr, unique=True)
    password_hash: str
    age: int
    country: str
    interests: List[str] = []
    
    anonymous_username: Indexed(str, unique=True)
    avatar_url: Optional[str] = None
    trust_score: int = 100
    is_active: bool = False
    is_admin: bool = False
    verification_token: Optional[str] = None
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Settings:
        name = "users"
