from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form, Body
from ..models.chat import Chat, Message
from ..models.user import User
from ..models.notification import Notification
from ..core.security import get_current_user
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import io
from bson import ObjectId
import logging
from pydantic import BaseModel, Field

router = APIRouter()
logger = logging.getLogger(__name__)

class MessageCreate(BaseModel):
    content: str = ""
    message_type: str = "text" # text, voice, photo, video, gif, sticker, post_share, story_reply, story_reaction, system
    attachment_url: Optional[str] = None
    reply_to_message_id: Optional[str] = None

class AutoDeleteUpdate(BaseModel):
    auto_delete_mode: str = Field(..., description="immediately_delete, delete_24h, never_delete")

class ChatThemeUpdate(BaseModel):
    custom_theme: Optional[str] = None

class ReactionRequest(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=10)

class ChatSettingsRequest(BaseModel):
    allow_messages_from: Optional[str] = None
    allow_message_requests: Optional[bool] = None
    allow_group_adds: Optional[str] = None
    read_receipts_enabled: Optional[bool] = None
    typing_indicators_enabled: Optional[bool] = None
    online_status_enabled: Optional[bool] = None
    last_seen_enabled: Optional[bool] = None

def _clean_photo(url: Optional[str]) -> Optional[str]:
    if not url or "dicebear.com" in url:
        return None
    return url

async def _enrich_message(msg: Message, current_username: str) -> Dict[str, Any]:
    return {
        "id": str(msg.id),
        "_id": str(msg.id),
        "chat_id": msg.chat_id,
        "sender_id": msg.sender_id,
        "content": msg.content,
        "message_type": msg.message_type,
        "attachment_url": msg.attachment_url,
        "is_read": msg.is_read,
        "delivered_at": msg.delivered_at.isoformat() if msg.delivered_at else None,
        "viewed_at": msg.viewed_at.isoformat() if msg.viewed_at else None,
        "expires_at": msg.expires_at.isoformat() if msg.expires_at else None,
        "deletion_mode": msg.deletion_mode,
        "reactions": msg.reactions,
        "reply_to_message_id": msg.reply_to_message_id,
        "created_at": msg.created_at.isoformat(),
        "is_me": msg.sender_id == current_username
    }

@router.get("/settings")
async def get_chat_settings(current_user: User = Depends(get_current_user)):
    return {"chat_settings": current_user.chat_settings}

@router.put("/settings")
async def update_chat_settings(body: ChatSettingsRequest, current_user: User = Depends(get_current_user)):
    settings = current_user.chat_settings or {}
    for key, value in body.dict(exclude_unset=True).items():
        if value is not None:
            settings[key] = value

    current_user.chat_settings = settings
    await current_user.save()
    return {"message": "Chat settings updated successfully", "chat_settings": current_user.chat_settings}

@router.get("")
@router.get("/")
async def get_my_chats(current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    chats = await Chat.find({"participants": me}).sort(-Chat.updated_at).to_list()

    result = []
    for c in chats:
        other_usernames = [p for p in c.participants if p != me]
        other_user = other_usernames[0] if other_usernames else me

        u = await User.find_one({"anonymous_username": other_user})
        other_photo = _clean_photo(u.profile_photo_url or u.avatar_url) if u else None

        result.append({
            "id": str(c.id),
            "_id": str(c.id),
            "participants": c.participants,
            "other_user": other_user,
            "other_user_display_name": u.display_name if u else other_user,
            "other_user_photo": other_photo,
            "last_message": c.last_message,
            "auto_delete_mode": c.auto_delete_mode,
            "custom_theme": c.custom_theme,
            "is_muted": me in c.muted_by,
            "updated_at": c.updated_at.isoformat()
        })
    return result

@router.post("/start/{target_username}")
async def start_chat(target_username: str, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    if target_username == me:
        raise HTTPException(status_code=400, detail="Cannot chat with yourself")

    target_user = await User.find_one({"anonymous_username": target_username})
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    if target_username in current_user.blocked_users or me in target_user.blocked_users:
        raise HTTPException(status_code=403, detail="Cannot start chat with blocked user")

    existing_chat = await Chat.find_one({
        "participants": {"$all": [me, target_username], "$size": 2}
    })

    if existing_chat:
        return {
            "id": str(existing_chat.id),
            "_id": str(existing_chat.id),
            "participants": existing_chat.participants,
            "auto_delete_mode": existing_chat.auto_delete_mode
        }

    new_chat = Chat(
        participants=[me, target_username],
        auto_delete_mode="never_delete"
    )
    await new_chat.insert()

    return {
        "id": str(new_chat.id),
        "_id": str(new_chat.id),
        "participants": new_chat.participants,
        "auto_delete_mode": new_chat.auto_delete_mode
    }

@router.get("/{chat_id}/details")
async def get_chat_details(chat_id: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    me = current_user.anonymous_username
    other_usernames = [p for p in chat.participants if p != me]
    other_user = other_usernames[0] if other_usernames else me
    u = await User.find_one({"anonymous_username": other_user})

    return {
        "id": str(chat.id),
        "_id": str(chat.id),
        "participants": chat.participants,
        "other_user": other_user,
        "other_user_display_name": u.display_name if u else other_user,
        "other_user_photo": _clean_photo(u.profile_photo_url or u.avatar_url) if u else None,
        "auto_delete_mode": chat.auto_delete_mode,
        "custom_theme": chat.custom_theme,
        "is_muted": me in chat.muted_by
    }

@router.patch("/{chat_id}/auto-delete")
async def set_chat_auto_delete_mode(chat_id: str, body: AutoDeleteUpdate, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    valid_modes = ["immediately_delete", "delete_24h", "never_delete"]
    if body.auto_delete_mode not in valid_modes:
        raise HTTPException(status_code=400, detail=f"Invalid mode. Choose from {valid_modes}")

    chat.auto_delete_mode = body.auto_delete_mode
    chat.updated_at = datetime.utcnow()
    await chat.save()

    mode_label = {
        "immediately_delete": "Immediately Delete",
        "delete_24h": "Delete After 24 Hours",
        "never_delete": "Never Delete"
    }.get(body.auto_delete_mode, body.auto_delete_mode)

    # Insert system notification message into conversation
    sys_msg = Message(
        chat_id=chat_id,
        sender_id=current_user.anonymous_username,
        content=f"@{current_user.anonymous_username} changed disappearing messages to {mode_label}.",
        message_type="system",
        deletion_mode="never_delete"
    )
    await sys_msg.insert()

    chat.last_message = f"Disappearing messages set to {mode_label}"
    await chat.save()

    return {
        "id": str(chat.id),
        "auto_delete_mode": chat.auto_delete_mode,
        "message": f"Updated disappearing messages to {mode_label}"
    }

@router.patch("/{chat_id}/theme")
async def set_chat_theme(chat_id: str, body: ChatThemeUpdate, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    chat.custom_theme = body.custom_theme
    await chat.save()
    return {"custom_theme": chat.custom_theme}

@router.post("/{chat_id}/mute")
async def toggle_mute_chat(chat_id: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    me = current_user.anonymous_username
    if me in chat.muted_by:
        chat.muted_by.remove(me)
        is_muted = False
    else:
        chat.muted_by.append(me)
        is_muted = True

    await chat.save()
    return {"is_muted": is_muted}

@router.get("/{chat_id}/messages")
async def get_messages(chat_id: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    me = current_user.anonymous_username
    now = datetime.now(timezone.utc)

    # Exclude permanently deleted/expired messages
    messages = await Message.find({
        "chat_id": chat_id,
        "deleted_at": None,
        "$or": [
            {"expires_at": None},
            {"expires_at": {"$gt": now}}
        ]
    }).sort(Message.created_at).to_list()

    # Update delivery timestamps for unread messages sent by partner
    for msg in messages:
        if msg.sender_id != me and not msg.delivered_at:
            msg.delivered_at = now
            msg.is_read = True
            await msg.save()

    return [await _enrich_message(m, me) for m in messages]

@router.post("/{chat_id}/messages/{message_id}/view")
async def mark_message_viewed(chat_id: str, message_id: str, current_user: User = Depends(get_current_user)):
    msg = await Message.get(message_id)
    if not msg or msg.chat_id != chat_id:
        raise HTTPException(status_code=404, detail="Message not found")

    me = current_user.anonymous_username
    if msg.sender_id != me and not msg.viewed_at:
        now = datetime.now(timezone.utc)
        msg.viewed_at = now
        msg.is_read = True
        await msg.save()

    return {"success": True, "viewed_at": msg.viewed_at.isoformat() if msg.viewed_at else None}

@router.post("/{chat_id}/send")
async def send_message(chat_id: str, data: MessageCreate, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    me = current_user.anonymous_username
    now = datetime.now(timezone.utc)
    mode = chat.auto_delete_mode or "never_delete"

    expires_at = None
    if mode == "delete_24h":
        expires_at = now + timedelta(hours=24)

    msg = Message(
        chat_id=chat_id,
        sender_id=me,
        content=data.content,
        message_type=data.message_type or "text",
        attachment_url=data.attachment_url,
        deletion_mode=mode,
        expires_at=expires_at,
        reply_to_message_id=data.reply_to_message_id
    )
    await msg.insert()

    chat.last_message = data.content if data.content else f"[{data.message_type.capitalize()}]"
    chat.updated_at = now
    await chat.save()

    # Send notifications to other participants if not muted
    for p in chat.participants:
        if p != me and p not in chat.muted_by:
            notif = Notification(
                user_id=p,
                type="message",
                actor_ids=[me],
                message=f"@{me}: {data.content[:50]}",
                metadata={"chat_id": chat_id, "message_id": str(msg.id)}
            )
            await notif.insert()

    return await _enrich_message(msg, me)

@router.post("/{chat_id}/upload-media")
async def upload_chat_media(chat_id: str, file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    content = await file.read()
    from ..core.database import db
    bucket = AsyncIOMotorGridFSBucket(db)
    now = datetime.now(timezone.utc)

    file_id = await bucket.upload_from_stream(
        f"chat_{chat_id}_{now.timestamp()}_{file.filename}",
        content,
        metadata={"contentType": file.content_type}
    )

    url = f"/media/chat/{file_id}"
    msg_type = "photo" if file.content_type.startswith("image/") else "video" if file.content_type.startswith("video/") else "voice" if file.content_type.startswith("audio/") else "file"

    mode = chat.auto_delete_mode or "never_delete"
    expires_at = now + timedelta(hours=24) if mode == "delete_24h" else None

    msg = Message(
        chat_id=chat_id,
        sender_id=current_user.anonymous_username,
        content=f"Sent a {msg_type}",
        message_type=msg_type,
        attachment_url=url,
        deletion_mode=mode,
        expires_at=expires_at
    )
    await msg.insert()

    chat.last_message = f"Sent a {msg_type}"
    chat.updated_at = now
    await chat.save()

    return await _enrich_message(msg, current_user.anonymous_username)

@router.post("/{chat_id}/messages/{message_id}/react")
async def react_to_message(chat_id: str, message_id: str, body: ReactionRequest, current_user: User = Depends(get_current_user)):
    msg = await Message.get(message_id)
    if not msg or msg.chat_id != chat_id:
        raise HTTPException(status_code=404, detail="Message not found")

    me = current_user.anonymous_username
    # Toggle reaction
    existing = next((r for r in msg.reactions if r.get("username") == me), None)
    if existing:
        msg.reactions.remove(existing)
        if existing.get("emoji") != body.emoji:
            msg.reactions.append({"username": me, "emoji": body.emoji})
    else:
        msg.reactions.append({"username": me, "emoji": body.emoji})

    await msg.save()
    return await _enrich_message(msg, me)

@router.delete("/{chat_id}/messages/{message_id}")
async def delete_own_message(chat_id: str, message_id: str, current_user: User = Depends(get_current_user)):
    msg = await Message.get(message_id)
    if not msg or msg.chat_id != chat_id:
        raise HTTPException(status_code=404, detail="Message not found")

    if msg.sender_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Cannot delete other user's message")

    msg.deleted_at = datetime.now(timezone.utc)
    msg.content = "[Deleted by sender]"
    msg.attachment_url = None
    await msg.save()

    return {"message": "Message deleted"}

@router.delete("/{chat_id}")
async def delete_chat(chat_id: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")

    await Message.find(Message.chat_id == chat_id).delete()
    await chat.delete()
    return {"message": "Chat deleted"}
