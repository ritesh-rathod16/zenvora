from fastapi import APIRouter, HTTPException, Depends, status, UploadFile, File, Query
from ..models.user import User
from ..models.social import Follow, Post
from ..core.security import get_current_user
from ..utils.auth import get_password_hash, verify_password
from pydantic import BaseModel, Field
from typing import List, Optional
import re
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import io
from PIL import Image
from bson import ObjectId
import os
import logging
from ..core import database

router = APIRouter()
logger = logging.getLogger(__name__)

class UsernameCheck(BaseModel):
    username: str

class UserProfileResponse(BaseModel):
    username: str
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    age: Optional[int] = None
    country: Optional[str] = None
    gender: Optional[str] = None
    personality_type: Optional[str] = None
    interests: List[str] = []
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0
    trust_score: int = 100
    is_following: bool = False

class UserSearchResponse(BaseModel):
    username: str
    avatar_url: Optional[str] = None
    trust_score: int

def validate_username_format(username: str):
    if not 3 <= len(username) <= 20:
        return False
    if not re.match(r"^\w+$", username):
        return False
    return True

@router.post("/check-username")
async def check_username(data: UsernameCheck):
    """Checks if a username is available for registration."""
    if not validate_username_format(data.username):
        return {"available": False, "reason": "Invalid format"}
    
    user = await User.find_one({"anonymous_username": data.username})
    return {"available": user is None}

@router.get("/search", response_model=List[UserSearchResponse])
async def search_users(q: str = Query(..., min_length=1)):
    # Case-insensitive search + EXCLUDE ADMINS
    query = {
        "anonymous_username": {"$regex": q, "$options": "i"},
        "role": {"$nin": ["admin", "super_admin"]}
    }
    users = await User.find(query).limit(10).to_list()
    return [
        UserSearchResponse(
            username=u.anonymous_username,
            avatar_url=u.avatar_url,
            trust_score=u.trust_score
        ) for u in users
    ]

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    # Calculate counts dynamically from other collections
    try:
        followers_count = await Follow.find({"following_id": current_user.anonymous_username}).count()
    except Exception:
        followers_count = 0
        
    try:
        following_count = await Follow.find({"follower_id": current_user.anonymous_username}).count()
    except Exception:
        following_count = 0
        
    try:
        posts_count = await Post.find({"author": current_user.anonymous_username}).count()
    except Exception:
        posts_count = 0

    return UserProfileResponse(
        username=current_user.anonymous_username,
        avatar_url=current_user.avatar_url,
        bio=current_user.bio,
        age=current_user.age,
        country=current_user.country,
        gender=current_user.gender,
        personality_type=current_user.personality_type,
        interests=current_user.interests,
        followers_count=followers_count,
        following_count=following_count,
        posts_count=posts_count,
        trust_score=current_user.trust_score
    )

@router.get("/{username}", response_model=UserProfileResponse)
async def get_user_profile(username: str, current_user: User = Depends(get_current_user)):
    user = await User.find_one({"anonymous_username": username})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Calculate counts dynamically
    try:
        followers_count = await Follow.find({"following_id": username}).count()
    except Exception:
        followers_count = 0
        
    try:
        following_count = await Follow.find({"follower_id": username}).count()
    except Exception:
        following_count = 0
        
    try:
        posts_count = await Post.find({"author": username}).count()
    except Exception:
        posts_count = 0

    # Check if current user is following this user
    try:
        follow = await Follow.find_one({
            "follower_id": current_user.anonymous_username,
            "following_id": username
        })
        is_following = follow is not None
    except Exception:
        is_following = False

    return UserProfileResponse(
        username=user.anonymous_username,
        avatar_url=user.avatar_url,
        bio=user.bio,
        age=user.age,
        country=user.country,
        gender=user.gender,
        personality_type=user.personality_type,
        interests=user.interests,
        followers_count=followers_count,
        following_count=following_count,
        posts_count=posts_count,
        trust_score=user.trust_score,
        is_following=is_following
    )

@router.post("/upload-profile-photo")
async def upload_profile_photo(file: UploadFile = File(..., alias="file"), current_user: User = Depends(get_current_user)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid image format")
    
    content = await file.read()
    img = Image.open(io.BytesIO(content)).convert("RGB")
    img.thumbnail((512, 512))
    output = io.BytesIO()
    img.save(output, format="JPEG", quality=85)
    
    bucket = AsyncIOMotorGridFSBucket(database.db)
    file_id = await bucket.upload_from_stream(f"profile_{current_user.id}.jpg", output.getvalue())
    
    url = f"http://192.168.29.118:8000/media/profile/{file_id}"
    current_user.avatar_url = url
    await current_user.save()
    return {"url": current_user.avatar_url}
