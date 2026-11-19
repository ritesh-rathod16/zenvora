from fastapi import APIRouter, HTTPException, Depends, status
from ..models.user import User
from ..models.social import Follow, FollowRequest
from ..models.notification import Notification
from ..models.swipe import Swipe
from ..core.security import get_current_user
from typing import List, Optional, Dict
from datetime import datetime
from bson import ObjectId

router = APIRouter()

def _clean_photo(url: Optional[str]) -> Optional[str]:
    if not url or "dicebear.com" in url:
        return None
    return url

@router.get("/requests/pending")
async def get_pending_follow_requests(current_user: User = Depends(get_current_user)):
    """Fetch pending follow requests received by the current user."""
    reqs = await FollowRequest.find({
        "to_user_id": current_user.anonymous_username,
        "status": "pending"
    }).sort("-created_at").to_list()

    result = []
    for r in reqs:
        sender = await User.find_one({"anonymous_username": r.from_user_id})
        photo = _clean_photo(sender.profile_photo_url or sender.avatar_url) if sender else None
        result.append({
            "request_id": str(r.id),
            "from_user": r.from_user_id,
            "display_name": sender.display_name if sender else r.from_user_id,
            "sender_photo": photo,
            "created_at": r.created_at.isoformat()
        })
    return result

@router.post("/requests/{request_id}/accept")
async def accept_follow_request(request_id: str, current_user: User = Depends(get_current_user)):
    freq = await FollowRequest.get(request_id)
    if not freq or freq.to_user_id != current_user.anonymous_username:
        raise HTTPException(status_code=404, detail="Follow request not found")

    freq.status = "accepted"
    freq.updated_at = datetime.utcnow()
    await freq.save()

    # Create Follow relationship
    existing_follow = await Follow.find_one({
        "follower_id": freq.from_user_id,
        "following_id": current_user.anonymous_username
    })
    if not existing_follow:
        follow = Follow(follower_id=freq.from_user_id, following_id=current_user.anonymous_username)
        await follow.insert()

        # Update follower / following counts
        current_user.followers_count += 1
        await current_user.save()

        requester = await User.find_one({"anonymous_username": freq.from_user_id})
        if requester:
            requester.following_count += 1
            await requester.save()

        # Notify requester that request was accepted
        notif = Notification(
            user_id=freq.from_user_id,
            type="follow_accept",
            actor_ids=[current_user.anonymous_username],
            message=f"@{current_user.anonymous_username} accepted your follow request",
            metadata={"from_user": current_user.anonymous_username}
        )
        await notif.insert()

    return {"success": True, "message": f"Accepted follow request from @{freq.from_user_id}"}

@router.post("/requests/{request_id}/reject")
async def reject_follow_request(request_id: str, current_user: User = Depends(get_current_user)):
    freq = await FollowRequest.get(request_id)
    if not freq or freq.to_user_id != current_user.anonymous_username:
        raise HTTPException(status_code=404, detail="Follow request not found")

    freq.status = "declined"
    freq.updated_at = datetime.utcnow()
    await freq.save()

    return {"success": True, "message": "Follow request declined"}

@router.post("/follow/{username}")
async def follow_user(username: str, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    if username == me:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    target = await User.find_one({"anonymous_username": username})
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    # If target is private, create request
    if target.is_private:
        existing_req = await FollowRequest.find_one({"from_user_id": me, "to_user_id": username})
        if not existing_req:
            freq = FollowRequest(from_user_id=me, to_user_id=username, status="pending")
            await freq.insert()

            notif = Notification(
                user_id=username,
                type="follow_request",
                actor_ids=[me],
                message=f"@{me} requested to follow you",
                metadata={"request_id": str(freq.id), "from_user": me}
            )
            await notif.insert()

        return {"status": "pending", "message": "Follow request sent"}

    # Public user: direct follow
    existing = await Follow.find_one({"follower_id": me, "following_id": username})
    if not existing:
        follow = Follow(follower_id=me, following_id=username)
        await follow.insert()

        current_user.following_count += 1
        await current_user.save()
        target.followers_count += 1
        await target.save()

        notif = Notification(
            user_id=username,
            type="follow",
            actor_ids=[me],
            message=f"@{me} started following you",
            metadata={"from_user": me}
        )
        await notif.insert()

    return {"status": "following", "message": f"Following @{username}"}

@router.post("/unfollow/{username}")
async def unfollow_user(username: str, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    follow = await Follow.find_one({"follower_id": me, "following_id": username})
    if follow:
        await follow.delete()
        current_user.following_count = max(0, current_user.following_count - 1)
        await current_user.save()

        target = await User.find_one({"anonymous_username": username})
        if target:
            target.followers_count = max(0, target.followers_count - 1)
            await target.save()

    await FollowRequest.find({"from_user_id": me, "to_user_id": username}).delete()

    return {"status": "unfollowed", "message": f"Unfollowed @{username}"}

@router.get("/notifications")
async def get_notifications(current_user: User = Depends(get_current_user)):
    """Fetch ranked notifications for current user with actor profile photos."""
    raw_notifications = await Notification.find({
        "user_id": current_user.anonymous_username
    }).sort("-created_at").limit(100).to_list()

    if not raw_notifications:
        return []

    result = []
    for n in raw_notifications:
        actor_username = n.actor_ids[0] if n.actor_ids else n.metadata.get("from_user", "")
        sender_photo = None
        if actor_username:
            u = await User.find_one({"anonymous_username": actor_username})
            if u:
                sender_photo = _clean_photo(u.profile_photo_url or u.avatar_url)

        result.append({
            "id": str(n.id),
            "type": n.type,
            "from_user": actor_username,
            "sender_photo": sender_photo,
            "message": n.message,
            "read": n.read,
            "created_at": n.created_at.isoformat(),
            "metadata": n.metadata
        })

    return result

@router.get("/notifications/unread-count")
async def get_unread_count(current_user: User = Depends(get_current_user)):
    count = await Notification.find({
        "user_id": current_user.anonymous_username,
        "read": False
    }).count()
    return {"count": count}

@router.post("/notifications/mark-read")
async def mark_notifications_read(current_user: User = Depends(get_current_user)):
    await Notification.find({
        "user_id": current_user.anonymous_username,
        "read": False
    }).update({"$set": {"read": True}})
    return {"success": True}
