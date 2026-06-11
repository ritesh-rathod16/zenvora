from fastapi import APIRouter, HTTPException, Depends, status
from ..models.user import User
from ..models.social import Follow, FollowRequest
from ..models.notification import Notification
from ..models.swipe import Swipe
from ..core.security import get_current_user
from typing import List, Optional, Dict
from datetime import datetime, timedelta
from bson import ObjectId

router = APIRouter()

@router.get("/notifications")
async def get_notifications(current_user: User = Depends(get_current_user)):
    """
    Fetch ranked and aggregated notifications for the current user.
    Aggregates 'like' types from same window.
    """
    raw_notifications = await Notification.find({
        "user_id": current_user.anonymous_username
    }).sort("-priority_score", "-created_at").limit(100).to_list()
    
    if not raw_notifications:
        return []

    aggregated = []
    seen_groups = {} # type -> group_key

    for n in raw_notifications:
        # Only aggregate 'like' types for now
        if n.type == "like":
            group_key = f"{n.type}_{n.created_at.strftime('%Y-%m-%d_%H')}"
            if group_key in seen_groups:
                idx = seen_groups[group_key]
                if n.actor_ids[0] not in aggregated[idx]["actor_ids"]:
                    aggregated[idx]["actor_ids"].append(n.actor_ids[0])
                    count = len(aggregated[idx]["actor_ids"])
                    if count > 1:
                        first = aggregated[idx]["actor_ids"][0]
                        aggregated[idx]["message"] = f"{first} and {count-1} others liked your profile"
                continue
            else:
                seen_groups[group_key] = len(aggregated)
        
        aggregated.append({
            "id": str(n.id),
            "type": n.type,
            "actor_ids": n.actor_ids,
            "message": n.message,
            "priority_score": n.priority_score,
            "read": n.read,
            "created_at": n.created_at,
            "metadata": n.metadata
        })

    return aggregated[:50]

@router.get("/notifications/unread-count")
async def get_unread_count(current_user: User = Depends(get_current_user)):
    """Returns the unread count for the red badge."""
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

@router.get("/likes-received")
async def get_likes_received(current_user: User = Depends(get_current_user)):
    """Secret Admirer System: returns blurred profiles of people who liked the user."""
    swipes = await Swipe.find({
        "target_user_id": current_user.anonymous_username,
        "action": "like"
    }).to_list()
    
    # Exclude those already matched
    matches = await Follow.find({
        "follower_id": current_user.anonymous_username
    }).to_list()
    matched_ids = [m.following_id for m in matches]
    
    potential_admirers = [s.user_id for s in swipes if s.user_id not in matched_ids]
    users = await User.find({"anonymous_username": {"$in": potential_admirers}}).to_list()
    
    return [{
        "username": "Secret Admirer",
        "avatar_url": u.avatar_url,
        "trust_score": u.trust_score,
        "is_blurred": True
    } for u in users]
