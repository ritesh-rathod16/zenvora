from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..core.security import get_current_user
from typing import List, Optional
import random
from pydantic import BaseModel
from datetime import datetime, timedelta

router = APIRouter()

class DiscoverUserResponse(BaseModel):
    id: str
    username: str
    avatar_url: str
    trust_score: int
    interests: List[str]
    country: str
    personality_type: Optional[str] = "The Adventurer"
    is_online: bool = False

@router.get("/swipe-discovery", response_model=List[DiscoverUserResponse])
async def swipe_discovery(current_user: User = Depends(get_current_user)):
    """
    Advanced discovery algorithm for real user profiles from MongoDB.
    Excludes admins and current user.
    """
    
    # Base Pool Query: Exclude current user, only active users, not banned, EXCLUDE ADMINS
    query = {
        "anonymous_username": {"$ne": current_user.anonymous_username},
        "is_banned": False,
        "role": {"$nin": ["admin", "super_admin"]} # Filter out admins
    }
    
    potential_pool = await User.find(query).limit(100).to_list()
    
    if not potential_pool:
        return []

    scored_users = []
    
    for user in potential_pool:
        score = 0.0
        
        # Interest similarity (40%)
        if current_user.interests and user.interests:
            common_interests = set(current_user.interests) & set(user.interests)
            if common_interests:
                score += (len(common_interests) / max(len(current_user.interests), 1)) * 40
            
        # Trust score (25%)
        score += (user.trust_score / 100) * 25
        
        # Activity/Active (20%) 
        if user.is_active:
            score += 20
        
        # Same country (10%)
        if user.country == current_user.country:
            score += 10
            
        # Randomness (5%)
        score += random.random() * 5
        
        scored_users.append((score, user))

    scored_users.sort(key=lambda x: x[0], reverse=True)
    top_users = [u[1] for u in scored_users[:30]]
    
    return [
        DiscoverUserResponse(
            id=str(user.id),
            username=user.anonymous_username or "Stranger",
            avatar_url=user.avatar_url or user.profile_photo_url or f"https://api.dicebear.com/7.x/avataaars/svg?seed={user.anonymous_username}",
            trust_score=user.trust_score,
            interests=user.interests or [],
            country=user.country or "Global",
            personality_type=user.personality_type or "The Adventurer",
            is_online=True if user.last_active and (datetime.utcnow() - user.last_active).total_seconds() < 300 else False
        ) for user in top_users
    ]
