from fastapi import APIRouter, HTTPException, Depends, Request
from ..models.user import User
from ..models.swipe import Swipe
from ..models.social import Follow, FollowRequest
from ..models.notification import Notification
from ..core.security import get_current_user
from ..core.rate_limiter import limiter
from ..websocket.signaling import sio
from pydantic import BaseModel
from typing import Literal
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

class SwipeRequest(BaseModel):
    target_user_id: str # target username
    action: Literal["like", "pass", "super_like"]

@router.post("")
@limiter.limit("30/minute")
async def perform_swipe(request: Request, data: SwipeRequest, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    target_username = data.target_user_id.strip()

    if target_username == me:
        raise HTTPException(status_code=400, detail="Cannot swipe on yourself")

    target_user = await User.find_one({"anonymous_username": target_username})
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check blocks
    if target_username in (current_user.blocked_users or []) or me in (target_user.blocked_users or []):
        raise HTTPException(status_code=403, detail="Interaction blocked")

    # Store or update swipe record
    existing_swipe = await Swipe.find_one({
        "user_id": me,
        "target_user_id": target_username
    })
    if existing_swipe:
        existing_swipe.action = data.action
        existing_swipe.created_at = datetime.utcnow()
        await existing_swipe.save()
    else:
        new_swipe = Swipe(
            user_id=me,
            target_user_id=target_username,
            action=data.action
        )
        await new_swipe.insert()

    # --- SWIPE LEFT (PASS) ---
    if data.action == "pass":
        return {
            "success": True,
            "status": "skipped",
            "message": f"Skipped @{target_username}"
        }

    # --- SWIPE RIGHT (LIKE / SUPER_LIKE -> FOLLOW / FOLLOW REQUEST) ---
    if data.action in ["like", "super_like"]:
        # 1. PUBLIC ACCOUNT: Immediately create Follow
        if not target_user.is_private:
            existing_follow = await Follow.find_one({
                "follower_id": me,
                "following_id": target_username
            })
            if not existing_follow:
                follow = Follow(follower_id=me, following_id=target_username)
                await follow.insert()

                # Update counts
                current_user.following_count += 1
                await current_user.save()
                target_user.followers_count += 1
                await target_user.save()

                # Notify recipient
                notif = Notification(
                    user_id=target_username,
                    type="follow",
                    actor_ids=[me],
                    message=f"@{me} started following you",
                    metadata={"from_user": me}
                )
                await notif.insert()

                try:
                    await sio.emit("notification_received", {
                        "type": "follow",
                        "actor": me,
                        "message": notif.message
                    }, room=target_username)
                except Exception:
                    logger.warning("Follow notification delivery failed.")

            return {
                "success": True,
                "status": "following",
                "is_private": False,
                "target_username": target_username,
                "message": f"Following @{target_username}"
            }

        # 2. PRIVATE ACCOUNT: Create Follow Request with status 'pending'
        else:
            existing_request = await FollowRequest.find_one({
                "from_user_id": me,
                "to_user_id": target_username
            })

            if not existing_request:
                freq = FollowRequest(
                    from_user_id=me,
                    to_user_id=target_username,
                    status="pending"
                )
                await freq.insert()

                notif = Notification(
                    user_id=target_username,
                    type="follow_request",
                    actor_ids=[me],
                    message=f"@{me} sent you a follow request through Discover.",
                    metadata={"request_id": str(freq.id), "from_user": me}
                )
                await notif.insert()

                try:
                    await sio.emit("notification_received", {
                        "type": "follow_request",
                        "actor": me,
                        "message": notif.message
                    }, room=target_username)
                except Exception:
                    logger.warning("Follow request notification delivery failed.")

                return {
                    "success": True,
                    "status": "pending",
                    "is_private": True,
                    "target_username": target_username,
                    "message": "Follow Request Sent"
                }
            else:
                return {
                    "success": True,
                    "status": existing_request.status,
                    "is_private": True,
                    "target_username": target_username,
                    "message": "Follow Request Already Sent"
                }

    return {"success": True, "status": "processed"}

@router.post("/undo")
async def undo_last_swipe(current_user: User = Depends(get_current_user)):
    last_swipe = await Swipe.find({"user_id": current_user.anonymous_username}).sort("-created_at").first_or_none()
    if not last_swipe:
        raise HTTPException(status_code=404, detail="No previous swipe found")

    target_username = last_swipe.target_user_id

    # If it was a follow request or follow, clean it up
    await FollowRequest.find({"from_user_id": current_user.anonymous_username, "to_user_id": target_username, "status": "pending"}).delete()

    follow = await Follow.find_one({"follower_id": current_user.anonymous_username, "following_id": target_username})
    if follow:
        await follow.delete()
        current_user.following_count = max(0, current_user.following_count - 1)
        await current_user.save()

        target = await User.find_one({"anonymous_username": target_username})
        if target:
            target.followers_count = max(0, target.followers_count - 1)
            await target.save()

    await last_swipe.delete()
    return {"success": True, "message": f"Undid swipe on @{target_username}", "target_username": target_username}
