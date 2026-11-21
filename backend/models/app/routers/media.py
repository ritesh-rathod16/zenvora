from fastapi import APIRouter, HTTPException, Response, Depends, Request
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from bson import ObjectId
import os
import time
import uuid
import hmac
import hashlib
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timezone
from ..core.database import get_database
from ..core.security import get_current_user, get_optional_current_user, users_blocked
from ..models.user import User
from ..models.story import Story
from ..models.chat import Message, Chat
from ..models.reel import Reel
from ..core.rate_limiter import limiter

logger = logging.getLogger(__name__)
router = APIRouter()

IMAGEKIT_PUBLIC_KEY = os.getenv("IMAGEKIT_PUBLIC_KEY", "")
IMAGEKIT_PRIVATE_KEY = os.getenv("IMAGEKIT_PRIVATE_KEY", "")
IMAGEKIT_URL_ENDPOINT = os.getenv("IMAGEKIT_URL_ENDPOINT", "")

@router.get("/imagekit-auth")
@limiter.limit("10/minute")
async def get_imagekit_auth(
    request: Request,
    current_user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """
    Generates secure HMAC-SHA1 client authentication parameters for direct ImageKit uploads.
    Used by Flutter client to upload directly to ImageKit CDN.
    """
    if not IMAGEKIT_PRIVATE_KEY or not IMAGEKIT_PUBLIC_KEY or not IMAGEKIT_URL_ENDPOINT:
        return {
            "enabled": False,
            "message": "ImageKit is not fully configured in environment. Fallback to server GridFS is active."
        }

    token = str(uuid.uuid4())
    expire = int(time.time()) + 1800 # 30 minutes validity

    signature = hmac.new(
        IMAGEKIT_PRIVATE_KEY.encode('utf-8'),
        f"{token}{expire}".encode('utf-8'),
        hashlib.sha1
    ).hexdigest()

    return {
        "enabled": True,
        "token": token,
        "expire": expire,
        "signature": signature,
        "publicKey": IMAGEKIT_PUBLIC_KEY,
        "urlEndpoint": IMAGEKIT_URL_ENDPOINT
    }

@router.get("/profile/{file_id}")
async def get_profile_photo(
    file_id: str,
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """Serve profile photos from MongoDB GridFS as fallback when CDN is not used."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        owner_id = (grid_out.metadata or {}).get("userId")
        owner = await User.get(owner_id) if owner_id else None
        if not owner or f"/media/profile/{file_id}" not in {
            owner.profile_photo_url,
            owner.avatar_url,
        }:
            raise HTTPException(status_code=404, detail="Profile photo not found")
        if current_user and owner and users_blocked(current_user, owner):
            raise HTTPException(status_code=404, detail="Profile photo not found")
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg", headers={"X-Content-Type-Options": "nosniff"})
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Profile photo not found")

@router.get("/voice-intro/{file_id}")
async def get_voice_intro(
    file_id: str,
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        owner_id = (grid_out.metadata or {}).get("userId")
        owner = await User.get(owner_id) if owner_id else None
        if not owner or owner.voice_intro_url != f"/media/voice-intro/{file_id}":
            raise HTTPException(status_code=404, detail="Voice introduction not found")
        if current_user and owner and users_blocked(current_user, owner):
            raise HTTPException(status_code=404, detail="Voice introduction not found")
        content = await grid_out.read()
        media_type = grid_out.metadata.get("contentType", "audio/mp4") if grid_out.metadata else "audio/mp4"
        if not media_type.startswith("audio/"):
            raise HTTPException(status_code=404, detail="Voice introduction not found")
        return Response(content=content, media_type=media_type, headers={"X-Content-Type-Options": "nosniff"})
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Voice introduction not found")

@router.get("/stories/{file_id}")
async def get_story_media(
    file_id: str,
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """Serve story media from MongoDB GridFS as fallback when CDN is not used."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        story = await Story.find_one({"media_url": f"/media/stories/{file_id}"})
        if not story:
            raise HTTPException(status_code=404, detail="Story media not found")
        author = await User.find_one({"anonymous_username": story.author_id})
        if not author:
            raise HTTPException(status_code=404, detail="Story media not found")

        viewer_name = current_user.anonymous_username if current_user else None
        is_owner = viewer_name == author.anonymous_username
        expires_at = story.expires_at
        if expires_at and expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if not is_owner and expires_at and expires_at <= datetime.now(timezone.utc):
            raise HTTPException(status_code=404, detail="Story media not found")
        if not is_owner:
            if not viewer_name and story.is_close_friends_only:
                raise HTTPException(status_code=404, detail="Story media not found")
            if current_user and (
                users_blocked(current_user, author)
                or viewer_name in (author.hide_story_from or [])
                or story.is_close_friends_only and viewer_name not in (author.close_friends or [])
            ):
                raise HTTPException(status_code=404, detail="Story media not found")

        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Story media not found")

@router.get("/chat/{file_id}")
async def get_chat_media(file_id: str, current_user: User = Depends(get_current_user)):
    """Serve chat attachments only to participants in the owning conversation."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        message = await Message.find_one({"attachment_url": f"/media/chat/{file_id}"})
        if not message:
            raise HTTPException(status_code=404, detail="Chat media not found")
        expires_at = message.expires_at
        if expires_at and expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if message.deleted_at or (expires_at and expires_at <= datetime.now(timezone.utc)):
            raise HTTPException(status_code=404, detail="Chat media not found")
        chat = await Chat.get(message.chat_id)
        if not chat or current_user.anonymous_username not in chat.participants:
            raise HTTPException(status_code=404, detail="Chat media not found")
        participants = await User.find({
            "anonymous_username": {"$in": chat.participants}
        }).to_list()
        if chat.is_group:
            for index, first in enumerate(participants):
                if any(users_blocked(first, second) for second in participants[index + 1:]):
                    raise HTTPException(status_code=404, detail="Chat media not found")
        else:
            other = next(
                (user for user in participants if user.anonymous_username != current_user.anonymous_username),
                None,
            )
            if other and users_blocked(current_user, other):
                raise HTTPException(status_code=404, detail="Chat media not found")

        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        media_type = grid_out.metadata.get("contentType", "image/jpeg") if grid_out.metadata else "image/jpeg"
        if media_type not in {
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "video/mp4", "video/webm",
            "audio/mpeg", "audio/mp4", "audio/wav", "audio/ogg", "audio/webm",
        }:
            media_type = "application/octet-stream"
        return Response(content=content, media_type=media_type, headers={"X-Content-Type-Options": "nosniff"})
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Chat media not found")

@router.get("/reels/{file_id}")
async def get_reel_media(
    file_id: str,
    current_user: Optional[User] = Depends(get_optional_current_user),
):
    """Serve reel video from MongoDB GridFS."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        reel = await Reel.find_one({"video_url": f"/media/reels/{file_id}"})
        if not reel or reel.is_archived:
            raise HTTPException(status_code=404, detail="Reel video not found")
        author = await User.find_one({"anonymous_username": reel.author_id})
        if not author or current_user and users_blocked(current_user, author):
            raise HTTPException(status_code=404, detail="Reel video not found")

        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        media_type = grid_out.metadata.get("contentType", "video/mp4") if grid_out.metadata else "video/mp4"
        if media_type not in {"video/mp4", "video/webm"}:
            media_type = "application/octet-stream"
        return Response(content=content, media_type=media_type, headers={"X-Content-Type-Options": "nosniff"})
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="Reel video not found")
