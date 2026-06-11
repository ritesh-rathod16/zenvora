from fastapi import APIRouter, HTTPException, Depends
from models.user import User
from routers.users import get_current_user
from typing import List
import random

router = APIRouter()

@router.get("/random-match")
async def get_random_match(
    current_user: User = Depends(get_current_user),
    country: str = None,
    interest: str = None
):
    query = {"anonymous_username": {"$ne": current_user.anonymous_username}, "is_active": True}
    
    if country:
        query["country"] = country
    if interest:
        query["interests"] = interest
        
    # Get a pool of potential matches
    potential_matches = await User.find(query).limit(50).to_list()
    
    if not potential_matches:
        raise HTTPException(status_code=404, detail="No matches found")
    
    match = random.choice(potential_matches)
    return {
        "anonymous_username": match.anonymous_username,
        "avatar_url": match.avatar_url,
        "country": match.country,
        "interests": match.interests,
        "trust_score": match.trust_score
    }

@router.get("/swipe-discovery")
async def swipe_discovery(current_user: User = Depends(get_current_user)):
    # Simple algorithm: find users with similar interests
    query = {
        "anonymous_username": {"$ne": current_user.anonymous_username},
        "is_active": True,
        "interests": {"$in": current_user.interests}
    }
    
    matches = await User.find(query).limit(10).to_list()
    
    if len(matches) < 5:
        # If not enough interest matches, just get random active users
        matches = await User.find({
            "anonymous_username": {"$ne": current_user.anonymous_username},
            "is_active": True
        }).limit(10).to_list()
        
    return [{
        "anonymous_username": m.anonymous_username,
        "avatar_url": m.avatar_url,
        "interests": m.interests,
        "country": m.country,
        "trust_score": m.trust_score
    } for m in matches]
