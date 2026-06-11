from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from ..models.story import Story
from ..models.user import User
from ..core.security import get_current_user
from typing import List
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import io
from PIL import Image
from bson import ObjectId
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/upload")
async def create_story(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    """Uploads a story image to GridFS and creates a record."""
    logger.info(f"Received story upload request from {current_user.anonymous_username}. Content type: {file.content_type}")
    
    # Be more lenient with content type checks
    if not file.content_type or not (file.content_type.startswith("image/") or file.content_type == "application/octet-stream"):
        logger.error(f"Invalid content type: {file.content_type}")
        raise HTTPException(status_code=400, detail=f"Invalid image format: {file.content_type}")
    
    try:
        content = await file.read()
        
        # Process image
        img = Image.open(io.BytesIO(content))
        img = img.convert("RGB")
        # Stories are usually vertical
        img.thumbnail((1080, 1920))
        
        output = io.BytesIO()
        img.save(output, format="JPEG", quality=80)
        processed_content = output.getvalue()

        from ..core.database import db
        if db is None:
            logger.error("Database connection not initialized")
            raise HTTPException(status_code=500, detail="Database connection not initialized")
            
        bucket = AsyncIOMotorGridFSBucket(db)
        
        file_id = await bucket.upload_from_stream(
            f"story_{current_user.id}_{datetime.utcnow().timestamp()}.jpg",
            processed_content,
            metadata={"contentType": "image/jpeg", "userId": str(current_user.id)}
        )
        
        media_url = f"/media/stories/{file_id}"
        
        new_story = Story(
            author_id=current_user.anonymous_username,
            media_url=media_url,
            expires_at=datetime.utcnow() + timedelta(hours=24)
        )
        await new_story.insert()
        logger.info(f"Story created successfully: {media_url}")
        return new_story
    except Exception as e:
        logger.error(f"Story upload error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to process image: {str(e)}")

@router.get("/feed", response_model=List[Story])
async def get_stories_feed(current_user: User = Depends(get_current_user)):
    """Fetch all active stories from users (excluding expired ones)."""
    now = datetime.utcnow()
    stories = await Story.find({"expires_at": {"$gt": now}}).sort(-Story.created_at).to_list()
    return stories

@router.delete("/{story_id}")
async def delete_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if story.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    from ..core.database import db
    bucket = AsyncIOMotorGridFSBucket(db)
    try:
        file_id = story.media_url.split("/")[-1]
        await bucket.delete(ObjectId(file_id))
    except:
        pass

    await story.delete()
    return {"message": "Story deleted"}

@router.post("/{story_id}/view")
async def view_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if story and current_user.anonymous_username not in story.views:
        story.views.append(current_user.anonymous_username)
        await story.save()
    return {"message": "Viewed"}
