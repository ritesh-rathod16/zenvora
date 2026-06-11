from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..models.swipe import Swipe
from ..models.notification import Notification
from ..core.security import get_current_user
from ..websocket.signaling import sio
from pydantic import BaseModel
from datetime import datetime

router = APIRouter()

class SwipeRequest(BaseModel):
    target_user_id: str
    action: str # "like", "pass", "super_like"

@router.post("")
async def perform_swipe(data: SwipeRequest, current_user: User = Depends(get_current_user)):
    # 1. Prevent duplicate swipes
    existing_swipe = await Swipe.find_one({
        "user_id": current_user.anonymous_username,
        "target_user_id": data.target_user_id
    })
    if existing_swipe:
        return {"success": False, "message": "Already swiped on this user"}

    # 2. Store swipe
    new_swipe = Swipe(
        user_id=current_user.anonymous_username,
        target_user_id=data.target_user_id,
        action=data.action
    )
    await new_swipe.insert()

    # 3. Handle Notification & Real-time Emit
    if data.action in ["like", "super_like"]:
        priority = 10 if data.action == "super_like" else 5
        notification = Notification(
            user_id=data.target_user_id,
            type=data.action,
            actor_ids=[current_user.anonymous_username],
            message=f"{current_user.anonymous_username} liked your profile",
            priority_score=priority
        )
        await notification.insert()
        
        # Real-time WebSocket Emit
        await sio.emit("notification_received", {
            "type": data.action,
            "actor": current_user.anonymous_username,
            "message": notification.message
        }, room=data.target_user_id)

    # 4. Detect mutual likes
    if data.action in ["like", "super_like"]:
        mutual_swipe = await Swipe.find_one({
            "user_id": data.target_user_id,
            "target_user_id": current_user.anonymous_username,
            "action": {"$in": ["like", "super_like"]}
        })

        if mutual_swipe:
            # Create Match Notification for BOTH
            match_msg = f"You matched with {data.target_user_id}!"
            for uid in [current_user.anonymous_username, data.target_user_id]:
                partner = data.target_user_id if uid == current_user.anonymous_username else current_user.anonymous_username
                match_notif = Notification(
                    user_id=uid,
                    type="match",
                    actor_ids=[partner],
                    message=f"You matched with {partner}!",
                    priority_score=20
                )
                await match_notif.insert()
                await sio.emit("notification_received", {
                    "type": "match",
                    "actor": partner,
                    "message": match_notif.message
                }, room=uid)

            return {
                "success": True,
                "match": True,
                "matched_user": data.target_user_id
            }

    return {"success": True, "match": False}
