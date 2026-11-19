from fastapi import APIRouter, HTTPException, Response, Depends
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from bson import ObjectId
import os
import time
import uuid
import hmac
import hashlib
import logging
from typing import Dict, Any, Optional
from ..core.database import get_database

logger = logging.getLogger(__name__)
router = APIRouter()

IMAGEKIT_PUBLIC_KEY = os.getenv("IMAGEKIT_PUBLIC_KEY", "")
IMAGEKIT_PRIVATE_KEY = os.getenv("IMAGEKIT_PRIVATE_KEY", "")
IMAGEKIT_URL_ENDPOINT = os.getenv("IMAGEKIT_URL_ENDPOINT", "")

@router.get("/imagekit-auth")
async def get_imagekit_auth() -> Dict[str, Any]:
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
async def get_profile_photo(file_id: str):
    """Serve profile photos from MongoDB GridFS as fallback when CDN is not used."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg")
    except Exception:
        raise HTTPException(status_code=404, detail="Profile photo not found")

@router.get("/stories/{file_id}")
async def get_story_media(file_id: str):
    """Serve story media from MongoDB GridFS as fallback when CDN is not used."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg")
    except Exception:
        raise HTTPException(status_code=404, detail="Story media not found")

@router.get("/chat/{file_id}")
async def get_chat_media(file_id: str):
    """Serve chat attachments from MongoDB GridFS."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        media_type = grid_out.metadata.get("contentType", "image/jpeg") if grid_out.metadata else "image/jpeg"
        return Response(content=content, media_type=media_type)
    except Exception:
        raise HTTPException(status_code=404, detail="Chat media not found")

@router.get("/reels/{file_id}")
async def get_reel_media(file_id: str):
    """Serve reel video from MongoDB GridFS."""
    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        media_type = grid_out.metadata.get("contentType", "video/mp4") if grid_out.metadata else "video/mp4"
        return Response(content=content, media_type=media_type)
    except Exception:
        raise HTTPException(status_code=404, detail="Reel video not found")
