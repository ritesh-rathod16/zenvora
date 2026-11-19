from fastapi import APIRouter, HTTPException, Depends
from ..models.note import UserNote
from ..models.user import User
from ..models.social import Follow
from ..core.security import get_current_user
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timezone, timedelta

router = APIRouter()

class CreateNoteRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=60)
    visibility: str = "followers" # followers or close_friends

@router.post("/create")
async def create_note(body: CreateNoteRequest, current_user: User = Depends(get_current_user)):
    uname = current_user.anonymous_username
    now = datetime.now(timezone.utc)

    # Remove existing active notes by this user
    await UserNote.find({"user_id": uname}).delete()

    note = UserNote(
        user_id=uname,
        content=body.content.strip(),
        visibility=body.visibility,
        created_at=now,
        expires_at=now + timedelta(hours=24)
    )
    await note.insert()
    return {"success": True, "note": note.dict()}

@router.get("/feed")
async def get_notes_feed(current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    now = datetime.now(timezone.utc)

    # Get followed users
    following = {f.following_id for f in await Follow.find({"follower_id": me}).to_list()}
    following.add(me)

    notes = await UserNote.find({
        "user_id": {"$in": list(following)},
        "expires_at": {"$gt": now}
    }).sort(-UserNote.created_at).to_list()

    result = []
    for n in notes:
        u = await User.find_one({"anonymous_username": n.user_id})
        photo = u.profile_photo_url or u.avatar_url if u else None
        if photo and "dicebear.com" in photo:
            photo = None

        result.append({
            "id": str(n.id),
            "user_id": n.user_id,
            "content": n.content,
            "author_photo": photo,
            "is_me": n.user_id == me,
            "created_at": n.created_at.isoformat()
        })
    return result

@router.delete("/delete")
async def delete_note(current_user: User = Depends(get_current_user)):
    await UserNote.find({"user_id": current_user.anonymous_username}).delete()
    return {"success": True, "message": "Note deleted"}
