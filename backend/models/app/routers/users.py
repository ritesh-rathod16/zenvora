from fastapi import APIRouter, HTTPException, Depends, status, UploadFile, File, Query
from ..models.user import User
from ..models.social import Follow, FollowRequest
from ..models.post import Post
from ..core.security import get_current_user, get_optional_current_user
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
from ..websocket.signaling import disconnect_user

router = APIRouter()
logger = logging.getLogger(__name__)

class UserProfileResponse(BaseModel):
    username: str
    full_name: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    profile_photo_url: Optional[str] = None
    voice_intro_url: Optional[str] = None
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

class OnboardingRequest(BaseModel):
    gender: str = Field(..., min_length=1, max_length=40)
    interested_in: str = Field(..., min_length=1, max_length=40)
    age_min: int = Field(..., ge=13, le=120)
    age_max: int = Field(..., ge=13, le=120)
    avatar_url: str = Field(..., min_length=1, max_length=2048)
    bio: str = Field("", max_length=500)
    personality_type: str = Field(..., min_length=1, max_length=80)
    interests: List[str] = Field(..., min_items=3, max_items=50)
    voice_intro_url: Optional[str] = Field(None, max_length=2048)

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
async def search_users(
    q: str = Query("", min_length=0),
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    query = {"role": {"$nin": ["admin", "super_admin"]}}
    if current_user:
        query["anonymous_username"] = {"$nin": [current_user.anonymous_username, *current_user.blocked_users]}
        query["blocked_users"] = {"$ne": current_user.anonymous_username}
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
        voice_intro_url=current_user.voice_intro_url,
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
    if body.date_of_birth and body.date_of_birth.strip():
        age = calculate_age(body.date_of_birth)
        if age is not None and 13 <= age <= 120:
            current_user.date_of_birth = body.date_of_birth.strip()
            current_user.age = age
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

@router.post("/onboarding")
async def save_onboarding(body: OnboardingRequest, current_user: User = Depends(get_current_user)):
    if body.age_min > body.age_max:
        raise HTTPException(status_code=400, detail="Minimum age cannot exceed maximum age")
    if not current_user.age or current_user.age < 13:
        raise HTTPException(status_code=403, detail="Account is not eligible for discovery")
    if not current_user.avatar_url or body.avatar_url != current_user.avatar_url:
        raise HTTPException(status_code=400, detail="Upload a profile photo before completing setup")

    interests = [interest.strip() for interest in body.interests if interest.strip()]
    if len(interests) < 3 or len(set(interests)) != len(interests):
        raise HTTPException(status_code=400, detail="Select at least three unique interests")

    current_user.gender = body.gender.strip()
    current_user.interested_in = body.interested_in.strip()
    current_user.age_min = body.age_min
    current_user.age_max = body.age_max
    current_user.bio = body.bio.strip()
    current_user.personality_type = body.personality_type.strip()
    current_user.interests = interests
    current_user.voice_intro_url = body.voice_intro_url
    await current_user.save()
    return {"message": "Onboarding saved successfully"}

@router.post("/block/{username}")
async def block_user(username: str, current_user: User = Depends(get_current_user)):
    target_username = username.strip().lstrip("@")
    if target_username == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot block yourself")
    target = await User.find_one({"anonymous_username": target_username})
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    if target_username not in current_user.blocked_users:
        current_user.blocked_users.append(target_username)
        await current_user.save()
    await disconnect_user(target_username)

    for follower_id, following_id in (
        (current_user.anonymous_username, target_username),
        (target_username, current_user.anonymous_username),
    ):
        follow = await Follow.find_one({"follower_id": follower_id, "following_id": following_id})
        if follow:
            await follow.delete()
            follower = current_user if follower_id == current_user.anonymous_username else target
            following = current_user if following_id == current_user.anonymous_username else target
            follower.following_count = max(0, follower.following_count - 1)
            following.followers_count = max(0, following.followers_count - 1)
            await follower.save()
            await following.save()

    await FollowRequest.find({
        "$or": [
            {"from_user_id": current_user.anonymous_username, "to_user_id": target_username},
            {"from_user_id": target_username, "to_user_id": current_user.anonymous_username},
        ]
    }).delete()
    return {"success": True, "message": "User blocked"}

@router.delete("/block/{username}")
async def unblock_user(username: str, current_user: User = Depends(get_current_user)):
    target_username = username.strip().lstrip("@")
    if target_username in current_user.blocked_users:
        current_user.blocked_users.remove(target_username)
        await current_user.save()
    return {"success": True, "message": "User unblocked"}

@router.get("/{username}", response_model=UserProfileResponse)
async def get_user_profile(username: str, current_user: Optional[User] = Depends(get_current_user)):
    clean_un = username.lstrip('@').strip()
    user = await User.find_one({"$or": [{"anonymous_username": clean_un}, {"normalized_username": clean_un.lower()}]})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if current_user and (
        clean_un in current_user.blocked_users
        or current_user.anonymous_username in user.blocked_users
    ):
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
        voice_intro_url=user.voice_intro_url,
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
    target = await User.find_one({"anonymous_username": clean_un})
    if current_user and target and (
        clean_un in current_user.blocked_users or current_user.anonymous_username in target.blocked_users
    ):
        raise HTTPException(status_code=404, detail="User not found")
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
    target = await User.find_one({"anonymous_username": clean_un})
    if current_user and target and (
        clean_un in current_user.blocked_users or current_user.anonymous_username in target.blocked_users
    ):
        raise HTTPException(status_code=404, detail="User not found")
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
@router.post("/avatar")
async def upload_profile_photo(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image file too large (max 10MB)")

    try:
        img = Image.open(io.BytesIO(content)).convert("RGB")
        img.thumbnail((512, 512))
        output = io.BytesIO()
        img.save(output, format="JPEG", quality=85)
        processed_bytes = output.getvalue()
    except Exception:
        logger.error("Failed to process uploaded image.")
        raise HTTPException(status_code=400, detail="Invalid image file or unsupported format")

    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    bucket = AsyncIOMotorGridFSBucket(db)
    file_id = await bucket.upload_from_stream(
        f"profile_{current_user.id}.jpg",
        processed_bytes,
        metadata={"contentType": "image/jpeg", "userId": str(current_user.id)}
    )

    url = f"/media/profile/{file_id}"
    current_user.profile_photo_url = url
    current_user.avatar_url = url
    await current_user.save()
    return {
        "url": url,
        "avatar_url": url,
        "profile_photo_url": url,
        "message": "Profile photo updated successfully",
    }

@router.post("/voice-intro")
async def upload_voice_intro(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    if not (file.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=400, detail="Invalid audio file")
    content = await file.read()
    if not content or len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio file must be between 1 byte and 10MB")

    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    bucket = AsyncIOMotorGridFSBucket(db)
    file_id = await bucket.upload_from_stream(
        f"voice_intro_{current_user.id}",
        content,
        metadata={"contentType": file.content_type, "userId": str(current_user.id)},
    )
    url = f"/media/voice-intro/{file_id}"
    current_user.voice_intro_url = url
    await current_user.save()
    return {"voice_intro_url": url}

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

@router.post("/me/change-password")
async def change_password(body: ChangePasswordRequest, current_user: User = Depends(get_current_user)):
    if not verify_password(body.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.password_hash = get_password_hash(body.new_password)
    current_user.token_version = getattr(current_user, "token_version", 0) + 1
    await current_user.save()
    return {"success": True, "message": "Password changed successfully. Please log in again with your new password."}
