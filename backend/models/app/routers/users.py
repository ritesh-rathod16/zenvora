from fastapi import APIRouter, HTTPException, Depends, status, UploadFile, File, Query
from ..models.user import User
from ..models.social import Follow
from ..models.post import Post
from ..core.security import get_current_user
from ..utils.auth import get_password_hash, verify_password
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import re
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import io
from PIL import Image
from datetime import datetime, date
import logging
from ..core.database import get_database

router = APIRouter()
logger = logging.getLogger(__name__)

class UserProfileResponse(BaseModel):
    username: str
    full_name: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    profile_photo_url: Optional[str] = None
    bio: Optional[str] = None
    website: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    interests: List[str] = []
    personality_type: Optional[str] = None
    is_private: bool = False
    visibility_settings: Dict[str, bool] = {}
    followers_count: int = 0
    following_count: int = 0
    posts_count: int = 0
    trust_score: int = 100
    is_following: bool = False
    is_pending: bool = False

class UserSearchResponse(BaseModel):
    username: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    trust_score: int

class EditProfileRequest(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None
    website: Optional[str] = None
    date_of_birth: Optional[str] = None # YYYY-MM-DD
    gender: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    interests: Optional[List[str]] = None
    visibility_settings: Optional[Dict[str, bool]] = None
    is_private: Optional[bool] = None

class UpdateSettingsRequest(BaseModel):
    is_private: Optional[bool] = None
    notifications_enabled: Optional[Dict[str, bool]] = None
    theme_preference: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6)

def normalize_username(raw: str) -> str:
    cleaned = raw.strip().lstrip('@').lower()
    return re.sub(r"[^\w]", "", cleaned)

def validate_username_format(username: str) -> bool:
    if not 3 <= len(username) <= 20:
        return False
    return bool(re.match(r"^\w+$", username))

def calculate_age(dob_str: Optional[str]) -> Optional[int]:
    if not dob_str:
        return None
    try:
        parts = dob_str.split('-')
        if len(parts) != 3:
            return None
        dob = date(int(parts[0]), int(parts[1]), int(parts[2]))
        today = date.today()
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    except Exception:
        return None

def _clean_photo(url: Optional[str]) -> Optional[str]:
    if not url or "dicebear.com" in url:
        return None
    return url

@router.get("/check-username/{username}")
async def check_username_availability(username: str):
    norm = normalize_username(username)
    if not validate_username_format(norm):
        return {"available": False, "reason": "Invalid format (3-20 alphanumeric/underscore characters)"}

    existing = await User.find_one({"normalized_username": norm})
    if existing:
        raise HTTPException(status_code=409, detail="Username is already taken")
    return {"available": True, "normalized_username": norm}

@router.get("/search", response_model=List[UserSearchResponse])
async def search_users(q: str = Query("", min_length=0)):
    query = {"role": {"$nin": ["admin", "super_admin"]}}
    if q and q.strip():
        q_clean = q.strip().lstrip('@')
        query["$or"] = [
            {"anonymous_username": {"$regex": q_clean, "$options": "i"}},
            {"full_name": {"$regex": q_clean, "$options": "i"}}
        ]

    users = await User.find(query).limit(25).to_list()
    return [
        UserSearchResponse(
            username=u.anonymous_username,
            full_name=u.full_name,
            avatar_url=_clean_photo(u.profile_photo_url or u.avatar_url),
            trust_score=u.trust_score
        ) for u in users
    ]

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    uname = current_user.anonymous_username
    followers_count = await Follow.find({"following_id": uname}).count()
    following_count = await Follow.find({"follower_id": uname}).count()
    posts_count = await Post.find({"author_id": uname}).count()

    photo = _clean_photo(current_user.profile_photo_url or current_user.avatar_url)

    return UserProfileResponse(
        username=uname,
        full_name=current_user.full_name,
        display_name=current_user.full_name or uname,
        avatar_url=photo,
        profile_photo_url=photo,
        bio=current_user.bio or "",
        website=current_user.website or "",
        age=current_user.age,
        gender=current_user.gender,
        country=current_user.country,
        city=current_user.city,
        interests=current_user.interests,
        personality_type=current_user.personality_type,
        is_private=current_user.is_private,
        visibility_settings=current_user.visibility_settings,
        followers_count=followers_count,
        following_count=following_count,
        posts_count=posts_count,
        trust_score=current_user.trust_score,
        is_following=False,
        is_pending=False
    )

@router.patch("/me/profile")
async def edit_profile(body: EditProfileRequest, current_user: User = Depends(get_current_user)):
    if body.full_name is not None:
        current_user.full_name = body.full_name.strip()
        current_user.display_name = body.full_name.strip()

    if body.username is not None:
        norm = normalize_username(body.username)
        if not validate_username_format(norm):
            raise HTTPException(status_code=400, detail="Invalid username format")
        if norm != current_user.normalized_username:
            conflict = await User.find_one({"normalized_username": norm})
            if conflict:
                raise HTTPException(status_code=409, detail="Username already taken")
            current_user.anonymous_username = body.username.strip().lstrip('@')
            current_user.normalized_username = norm

    if body.bio is not None:
        current_user.bio = body.bio.strip()
    if body.website is not None:
        current_user.website = body.website.strip()
    if body.date_of_birth is not None:
        current_user.date_of_birth = body.date_of_birth.strip()
        current_user.age = calculate_age(body.date_of_birth)
    if body.gender is not None:
        current_user.gender = body.gender.strip()
    if body.country is not None:
        current_user.country = body.country.strip()
    if body.city is not None:
        current_user.city = body.city.strip()
    if body.interests is not None:
        current_user.interests = body.interests
    if body.visibility_settings is not None:
        current_user.visibility_settings.update(body.visibility_settings)
    if body.is_private is not None:
        current_user.is_private = body.is_private

    await current_user.save()
    return {"message": "Profile updated successfully", "user": current_user.dict()}

@router.get("/{username}", response_model=UserProfileResponse)
async def get_user_profile(username: str, current_user: Optional[User] = Depends(get_current_user)):
    clean_un = username.lstrip('@').strip()
    user = await User.find_one({"$or": [{"anonymous_username": clean_un}, {"normalized_username": clean_un.lower()}]})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    uname = user.anonymous_username
    followers_count = await Follow.find({"following_id": uname}).count()
    following_count = await Follow.find({"follower_id": uname}).count()
    posts_count = await Post.find({"author_id": uname}).count()

    is_following = False
    is_pending = False
    if current_user and current_user.anonymous_username != uname:
        follow = await Follow.find_one({
            "follower_id": current_user.anonymous_username,
            "following_id": uname
        })
        is_following = follow is not None

        if not is_following and user.is_private:
            from ..models.social import FollowRequest
            freq = await FollowRequest.find_one({
                "from_user_id": current_user.anonymous_username,
                "to_user_id": uname,
                "status": "pending"
            })
            is_pending = freq is not None

    photo = _clean_photo(user.profile_photo_url or user.avatar_url)

    # Respect privacy visibility settings if viewing someone else's profile
    is_self = current_user and current_user.anonymous_username == user.anonymous_username
    vis = user.visibility_settings

    age_val = user.age if (is_self or vis.get("show_age", True)) else None
    country_val = user.country if (is_self or vis.get("show_country", True)) else None
    interests_val = user.interests if (is_self or vis.get("show_interests", True)) else []

    return UserProfileResponse(
        username=uname,
        full_name=user.full_name,
        display_name=user.full_name or uname,
        avatar_url=photo,
        profile_photo_url=photo,
        bio=user.bio or "",
        website=user.website or "",
        age=age_val,
        gender=user.gender if is_self else None,
        country=country_val,
        city=user.city if is_self else None,
        interests=interests_val,
        personality_type=user.personality_type,
        is_private=user.is_private,
        visibility_settings=vis,
        followers_count=followers_count,
        following_count=following_count,
        posts_count=posts_count,
        trust_score=user.trust_score,
        is_following=is_following,
        is_pending=is_pending
    )

@router.get("/{username}/followers")
async def get_user_followers(username: str, current_user: Optional[User] = Depends(get_current_user)):
    clean_un = username.lstrip('@').strip()
    follows = await Follow.find({"following_id": clean_un}).to_list()
    result = []
    for f in follows:
        u = await User.find_one({"anonymous_username": f.follower_id})
        if u:
            result.append({
                "username": u.anonymous_username,
                "full_name": u.full_name,
                "avatar_url": _clean_photo(u.profile_photo_url or u.avatar_url),
                "trust_score": u.trust_score
            })
    return result

@router.get("/{username}/following")
async def get_user_following(username: str, current_user: Optional[User] = Depends(get_current_user)):
    clean_un = username.lstrip('@').strip()
    follows = await Follow.find({"follower_id": clean_un}).to_list()
    result = []
    for f in follows:
        u = await User.find_one({"anonymous_username": f.following_id})
        if u:
            result.append({
                "username": u.anonymous_username,
                "full_name": u.full_name,
                "avatar_url": _clean_photo(u.profile_photo_url or u.avatar_url),
                "trust_score": u.trust_score
            })
    return result

@router.post("/upload-profile-photo")
async def upload_profile_photo(file: UploadFile = File(..., alias="file"), current_user: User = Depends(get_current_user)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid image format")

    content = await file.read()
    img = Image.open(io.BytesIO(content)).convert("RGB")
    img.thumbnail((512, 512))
    output = io.BytesIO()
    img.save(output, format="JPEG", quality=85)

    db = get_database()
    bucket = AsyncIOMotorGridFSBucket(db)
    file_id = await bucket.upload_from_stream(f"profile_{current_user.id}.jpg", output.getvalue())

    url = f"/media/profile/{file_id}"
    current_user.profile_photo_url = url
    current_user.avatar_url = url
    await current_user.save()
    return {"url": url, "profile_photo_url": url}

@router.get("/me/settings")
async def get_my_settings(current_user: User = Depends(get_current_user)):
    return {
        "is_private": current_user.is_private,
        "notifications_enabled": current_user.notifications_enabled,
        "chat_settings": getattr(current_user, "chat_settings", {}),
        "story_settings": getattr(current_user, "story_settings", {}),
        "visibility_settings": current_user.visibility_settings,
        "language": current_user.language,
        "theme_preference": getattr(current_user, "theme_preference", "dark")
    }

@router.patch("/me/settings")
async def update_my_settings(body: UpdateSettingsRequest, current_user: User = Depends(get_current_user)):
    if body.is_private is not None:
        current_user.is_private = body.is_private
    if body.notifications_enabled is not None:
        current_user.notifications_enabled = body.notifications_enabled
    if body.theme_preference is not None:
        current_user.theme_preference = body.theme_preference
    await current_user.save()
    return {"success": True, "message": "Settings updated"}
