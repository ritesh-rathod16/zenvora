from fastapi import APIRouter, HTTPException, Response
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from bson import ObjectId
from ..core.database import db

router = APIRouter()

@router.get("/profile/{file_id}")
async def get_profile_photo(file_id: str):
    """Serve profile photos from GridFS."""
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg")
    except Exception:
        raise HTTPException(status_code=404, detail="Profile photo not found")

@router.get("/stories/{file_id}")
async def get_story_media(file_id: str):
    """Serve story media from GridFS."""
    try:
        bucket = AsyncIOMotorGridFSBucket(db)
        grid_out = await bucket.open_download_stream(ObjectId(file_id))
        content = await grid_out.read()
        return Response(content=content, media_type="image/jpeg")
    except Exception:
        raise HTTPException(status_code=404, detail="Story media not found")
