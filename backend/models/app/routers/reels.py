from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form, Request
from ..models.reel import Reel
from ..models.user import User
from ..models.chat import Chat, Message
from ..models.notification import Notification
from ..core.security import get_current_user
from ..core.security import users_blocked
from ..core.rate_limiter import limiter
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

async def _ensure_reel_access(reel: Reel, current_user: User):
    author = await User.find_one({"anonymous_username": reel.author_id})
    if not author or users_blocked(current_user, author):
        raise HTTPException(status_code=404, detail="Reel not found")

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
    except Exception:
        logger.error("Reel upload failed.")
        raise HTTPException(status_code=400, detail="Failed to upload reel")

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
    await _ensure_reel_access(reel, current_user)

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
    await _ensure_reel_access(reel, current_user)

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
    await _ensure_reel_access(reel, current_user)

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
    await _ensure_reel_access(reel, current_user)

    sender = current_user.anonymous_username
    sent_count = 0

    for recipient in body.recipients:
        if recipient == sender:
            continue
        target = await User.find_one({"anonymous_username": recipient})
        if not target:
            raise HTTPException(status_code=404, detail="Recipient not found")
        if users_blocked(current_user, target):
            raise HTTPException(status_code=403, detail="Interaction blocked")
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
    if reel.video_url.startswith("/media/reels/"):
        file_id = reel.video_url.split("/")[-1]
        if not ObjectId.is_valid(file_id):
            raise HTTPException(status_code=500, detail="Reel media reference is invalid")
        try:
            await bucket.delete(ObjectId(file_id))
        except Exception:
            logger.error("Reel media deletion failed.")
            raise HTTPException(status_code=503, detail="Reel media could not be deleted")

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
        if not ObjectId.is_valid(rid):
            continue
        r = await Reel.get(ObjectId(rid))
        if r and not r.is_archived:
            reels.append(await _enrich_reel(r, current_user.anonymous_username))
    return reels

class EditReelRequest(BaseModel):
    caption: Optional[str] = None

class FeedbackRequest(BaseModel):
    feedback_type: str

class ReportReelRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500)
    details: Optional[str] = Field("", max_length=2000)

@router.patch("/{reel_id}")
async def edit_reel(reel_id: str, body: EditReelRequest, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel or reel.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Not authorized")
    if body.caption is not None:
        reel.caption = body.caption.strip()
    await reel.save()
    return {"success": True, "reel": await _enrich_reel(reel, current_user.anonymous_username)}

@router.post("/{reel_id}/pin")
async def toggle_pin_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel or reel.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Not authorized")
    reel.is_pinned = not reel.is_pinned
    await reel.save()
    return {"success": True, "is_pinned": reel.is_pinned}

@router.post("/{reel_id}/archive")
async def toggle_archive_reel(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel or reel.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Not authorized")
    reel.is_archived = not reel.is_archived
    await reel.save()
    return {"success": True, "is_archived": reel.is_archived}

@router.post("/{reel_id}/comments-toggle")
async def toggle_reel_comments(reel_id: str, current_user: User = Depends(get_current_user)):
    reel = await Reel.get(reel_id)
    if not reel or reel.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Not authorized")
    reel.comments_disabled = not reel.comments_disabled
    await reel.save()
    return {"success": True, "comments_disabled": reel.comments_disabled}

@router.post("/{reel_id}/feedback")
async def reel_feedback(reel_id: str, body: FeedbackRequest, current_user: User = Depends(get_current_user)):
    return {"success": True, "message": f"Recorded feedback: {body.feedback_type}"}

@router.post("/{reel_id}/report")
@limiter.limit("10/hour")
async def report_reel(
    request: Request,
    reel_id: str,
    body: ReportReelRequest,
    current_user: User = Depends(get_current_user),
):
    from ..models.report import Report
    reel = await Reel.get(reel_id)
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")
    if reel.author_id == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot report your own reel")
    duplicate = await Report.find_one({
        "reporter_id": current_user.anonymous_username,
        "reported_id": reel.author_id,
        "content_id": reel_id,
        "status": "pending",
    })
    if duplicate:
        return {"success": True, "message": "Reel reported successfully"}
    report = Report(
        reporter_id=current_user.anonymous_username,
        reported_id=reel.author_id,
        target_type="reel",
        target_id=reel_id,
        content_id=reel_id,
        reason=body.reason,
        details=body.details or "",
    )
    await report.insert()
    return {"success": True, "message": "Reel reported successfully"}
