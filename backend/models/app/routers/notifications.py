from fastapi import APIRouter, HTTPException, Depends, Query
from ..models.notification import Notification
from ..models.user import User
from ..core.security import get_current_user
from typing import List, Optional, Dict, Any
from pydantic import BaseModel

router = APIRouter()

class NotificationSettingsUpdate(BaseModel):
    likes: Optional[str] = "everyone" # everyone, following, off
    comments: Optional[str] = "everyone"
    follows: Optional[str] = "everyone"
    messages: Optional[str] = "everyone"
    stories: Optional[str] = "everyone"
    system_alerts: Optional[bool] = True

@router.get("/")
async def get_notifications(
    category: Optional[str] = Query(None), # social, mentions, system
    current_user: User = Depends(get_current_user)
):
    query = {"recipient_id": current_user.anonymous_username}
    if category and category in ["social", "mentions", "system"]:
        query["category"] = category

    notifs = await Notification.find(query).sort(-Notification.created_at).limit(50).to_list()

    result = []
    for n in notifs:
        actor = await User.find_one({"anonymous_username": n.actor_id}) if n.actor_id else None
        actor_usernames = set(n.actor_ids or [])
        if n.actor_id:
            actor_usernames.add(n.actor_id)
        if actor_usernames.intersection(current_user.blocked_users or []):
            continue
        blocked_actor = False
        for actor_username in actor_usernames:
            actor_user = actor if actor and actor.anonymous_username == actor_username else await User.find_one(
                {"anonymous_username": actor_username}
            )
            if actor_user and current_user.anonymous_username in (actor_user.blocked_users or []):
                blocked_actor = True
                break
        if blocked_actor:
            continue
        sender_photo = actor.profile_photo_url or actor.avatar_url if actor else None
        if sender_photo and "dicebear.com" in sender_photo:
            sender_photo = None

        d = n.dict()
        d["id"] = str(n.id)
        d["_id"] = str(n.id)
        d["from_user"] = n.actor_id
        d["sender_photo"] = sender_photo
        d["created_at"] = n.created_at.isoformat()
        result.append(d)

    return result

@router.get("/unread-count")
async def get_unread_count(current_user: User = Depends(get_current_user)):
    count = await Notification.find({"recipient_id": current_user.anonymous_username, "read": False}).count()
    return {"unread_count": count}

@router.post("/{notification_id}/read")
async def mark_notification_read(notification_id: str, current_user: User = Depends(get_current_user)):
    n = await Notification.get(notification_id)
    if not n or n.recipient_id != current_user.anonymous_username:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.read = True
    await n.save()
    return {"success": True}

@router.post("/read-all")
async def mark_all_notifications_read(current_user: User = Depends(get_current_user)):
    await Notification.find({"recipient_id": current_user.anonymous_username, "read": False}).update({"$set": {"read": True}})
    return {"success": True}

@router.delete("/{notification_id}")
async def delete_notification(notification_id: str, current_user: User = Depends(get_current_user)):
    n = await Notification.get(notification_id)
    if not n or n.recipient_id != current_user.anonymous_username:
        raise HTTPException(status_code=404, detail="Notification not found")
    await n.delete()
    return {"success": True}

@router.get("/settings")
async def get_notification_settings(current_user: User = Depends(get_current_user)):
    return {"notification_settings": getattr(current_user, "notification_settings", {})}

@router.put("/settings")
async def update_notification_settings(body: NotificationSettingsUpdate, current_user: User = Depends(get_current_user)):
    current_user.notification_settings = body.dict()
    await current_user.save()
    return {"success": True, "notification_settings": current_user.notification_settings}
