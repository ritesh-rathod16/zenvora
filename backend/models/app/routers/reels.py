from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form, Request
from ..models.reel import Reel
from ..models.user import User
from ..models.chat import Chat, Message
from ..models.notification import Notification
from ..core.security import get_current_user
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import io
from bson import ObjectId
import logging
from pydantic import BaseModel, Field

router = APIRouter()
logger = logging.getLogger(__name__)

class CommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)

class ShareReelRequest(BaseModel):
    recipients: List[str] = Field(..., min_items=1)

def _clean_photo(url: Optional[str]) -> Optional[str]:
    if not url or "dicebear.com" in url:
        return None
    return url

async def _enrich_reel(reel: Reel, current_username: Optional[str] = None) -> Dict[str, Any]:
    author = await User.find_one({"anonymous_username": reel.author_id})
    author_photo = _clean_photo(author.profile_photo_url or author.avatar_url) if author else None

    is_liked = current_username in reel.likes if current_username else False
    is_reposted = current_username in reel.reposts if current_username else False

    data = reel.dict()
    data["id"] = str(reel.id)
    data["_id"] = str(reel.id)
    data["author_name"] = author.display_name if author else reel.author_id
    data["author_photo"] = author_photo
    data["likes_count"] = len(reel.likes)
    data["reposts_count"] = len(reel.reposts)
    data["is_liked"] = is_liked
    data["is_reposted"] = is_reposted
    data["created_at"] = reel.created_at.isoformat()
    return data

@router.post("/upload")
async def upload_reel(
    file: UploadFile = File(...),
    caption: Optional[str] = Form(""),
    current_user: User = Depends(get_current_user)
):
    if not file.content_type or not file.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Invalid video format")

    try:
        content = await file.read()
        from ..core.database import db
        bucket = AsyncIOMotorGridFSBucket(db)
        now = datetime.now(timezone.utc)

        file_id = await bucket.upload_from_stream(
            f"reel_{current_user.id}_{now.timestamp()}.mp4",
            content,
            metadata={"contentType": file.content_type, "userId": str(current_user.id)}
        )

        video_url = f"/media/reels/{file_id}"

        new_reel = Reel(
            author_id=current_user.anonymous_username,
            video_url=video_url,
            caption=caption or ""
        )
        await new_reel.insert()
        return await _enrich_reel(new_reel, current_user.anonymous_username)
    except Exception as e:
        logger.error(f"Reel upload error: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to upload reel: {e}")

@router.get("/feed")
async def get_reels_feed(current_user: Optional[User] = Depends(get_current_user)):
    reels = await Reel.find().sort(-Reel.created_at).limit(30).to_list()
    uname = current_user.anonymous_username if current_user else None
    return [await _enrich_reel(r, uname) for r in reels]

@router.post("/{reel_id}/like")
async def toggle_like_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")

    uname = current_user.anonymous_username
    liked = False
    if uname in reel.likes:
        reel.likes.remove(uname)
        liked = False
    else:
        reel.likes.append(uname)
        liked = True

        if reel.author_id != uname:
            notif = Notification(
                user_id=reel.author_id,
                type="like",
                actor_ids=[uname],
                message=f"@{uname} liked your reel",
                metadata={"reel_id": reel_id}
            )
            await notif.insert()

    await reel.save()
    return {"liked": liked, "likes_count": len(reel.likes)}

@router.post("/{reel_id}/comment")
async def add_reel_comment(reel_id: str, body: CommentRequest, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")

    uname = current_user.anonymous_username
    comment_entry = {
        "id": str(ObjectId()),
        "author_id": uname,
        "content": body.content.strip(),
        "created_at": datetime.utcnow().isoformat()
    }
    reel.comments.append(comment_entry)
    await reel.save()

    if reel.author_id != uname:
        notif = Notification(
            user_id=reel.author_id,
            type="comment",
            actor_ids=[uname],
            message=f"@{uname} commented on your reel",
            metadata={"reel_id": reel_id}
        )
        await notif.insert()

    return {"success": True, "comment": comment_entry, "comments_count": len(reel.comments)}

@router.post("/{reel_id}/repost")
async def toggle_repost_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")

    uname = current_user.anonymous_username
    reposted = False
    if uname in reel.reposts:
        reel.reposts.remove(uname)
        reposted = False
    else:
        reel.reposts.append(uname)
        reposted = True

        if reel.author_id != uname:
            notif = Notification(
                user_id=reel.author_id,
                type="repost",
                actor_ids=[uname],
                message=f"@{uname} reposted your reel",
                metadata={"reel_id": reel_id}
            )
            await notif.insert()

    await reel.save()
    return {"reposted": reposted, "reposts_count": len(reel.reposts)}

@router.post("/{reel_id}/share")
async def share_reel(reel_id: str, body: ShareReelRequest, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")

    sender = current_user.anonymous_username
    sent_count = 0

    for recipient in body.recipients:
        if recipient == sender:
            continue
        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=f"Shared a reel by @{reel.author_id}")
            await chat.insert()

        msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Shared a reel by @{reel.author_id}: {reel.caption[:40]}",
            message_type="post_share",
            attachment_url=reel.video_url
        )
        await msg.insert()
        chat.last_message = f"Shared reel by @{reel.author_id}"
        chat.updated_at = datetime.utcnow()
        await chat.save()
        sent_count += 1

    reel.shares_count += sent_count
    await reel.save()
    return {"success": True, "sent_to": sent_count}

@router.delete("/{reel_id}")
async def delete_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")
    if reel.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    from ..core.database import db
    bucket = AsyncIOMotorGridFSBucket(db)
    try:
        file_id = reel.video_url.split("/")[-1]
        await bucket.delete(ObjectId(file_id))
    except Exception:
        pass

    await reel.delete()
    return {"success": True, "message": "Reel deleted"}

@router.post("/{reel_id}/save")
async def save_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")
    r_id = str(reel.id)
    if r_id not in current_user.saved_reels:
        current_user.saved_reels.append(r_id)
        await current_user.save()
    return {"success": True, "saved": True}

@router.delete("/{reel_id}/save")
async def unsave_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    r_id = reel_id
    if r_id in current_user.saved_reels:
        current_user.saved_reels.remove(r_id)
        await current_user.save()
    return {"success": True, "saved": False}

@router.get("/saved")
async def get_saved_reels(current_user: User = Depends(get_current_user)):
    saved_ids = current_user.saved_reels
    reels = []
    for rid in saved_ids:
        try:
            r = await Reel.get(ObjectId(rid))
            if r:
                reels.append(await _enrich_reel(r, current_user.anonymous_username))
        except Exception:
            pass
    return reels
