from fastapi import APIRouter, HTTPException, Depends, status, WebSocket, WebSocketDisconnect, Query, BackgroundTasks
from typing import List, Dict, Any, Optional
from ..services.matchmaking import matchmaker
from ..services.livekit_service import livekit_service
from ..models.user import User
from ..models.post import Post
from ..models.report import Report
from ..models.chat import Chat, Message
from ..models.voice_room import VoiceRoom
from ..models.admin import AdminLog, PlatformSettings
from ..models.notification import Notification
from ..core.security import get_current_user
from ..utils.auth import get_password_hash, verify_password, create_access_token
from ..utils.email import SMTP_LOGIN, SMTP_PASSWORD, SMTP_SERVER, SMTP_PORT, EMAIL_FROM
from pydantic import BaseModel, EmailStr
from datetime import datetime, timedelta
import os
import json
import asyncio
from bson import ObjectId
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

router = APIRouter()

class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str

class BroadcastRequest(BaseModel):
    title: str
    message: str
    send_push: bool = True
    send_email: bool = False

class UserBanRequest(BaseModel):
    reason: str
    duration_hours: Optional[int] = None

class SettingsUpdate(BaseModel):
    registrations_enabled: Optional[bool] = None
    posting_enabled: Optional[bool] = None
    video_chat_enabled: Optional[bool] = None
    image_uploads_enabled: Optional[bool] = None
    maintenance_mode: Optional[bool] = None

# Helper to check if user is admin
async def require_admin(current_user: User = Depends(get_current_user)):
    if current_user.email != "zenvora@gmail.com":
        raise HTTPException(status_code=403, detail="Unauthorized access to admin terminal")
    if current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

async def send_broadcast_emails(title: str, message_text: str):
    """Background task to send emails to all verified users."""
    users = await User.find({"is_active": True}).to_list()
    if not all([SMTP_SERVER, SMTP_PORT, SMTP_LOGIN, SMTP_PASSWORD]):
        return

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_LOGIN, SMTP_PASSWORD)
            for user in users:
                msg = MIMEMultipart()
                msg['From'] = EMAIL_FROM
                msg['To'] = user.email
                msg['Subject'] = title
                msg.attach(MIMEText(message_text, 'plain'))
                server.send_message(msg)
    except Exception as e:
        print(f"Broadcast Email Error: {e}")

@router.post("/login")
async def admin_login(data: AdminLoginRequest):
    # Strictly enforce the master admin account
    admin_email = "zenvora@gmail.com"
    admin_password = "qwertyuiop"
    
    if data.email == admin_email and data.password == admin_password:
        # Check if user exists in DB, if not seed_admin should have created it
        user = await User.find_one({"email": admin_email})
        if not user:
            # Fallback to creating it if somehow missing
            user = User(
                real_name="Master Admin",
                email=admin_email,
                anonymous_username="ZenvoraMaster",
                password_hash=get_password_hash(admin_password),
                age=99,
                country="Global",
                role="super_admin",
                is_admin=True,
                is_active=True
            )
            await user.insert()

        access_token = create_access_token(data={"sub": admin_email, "role": "super_admin"})
        return {
            "access_token": access_token, 
            "token_type": "bearer", 
            "role": "super_admin",
            "user": {
                "email": user.email,
                "anonymous_username": user.anonymous_username,
                "is_admin": True,
                "role": "super_admin"
            }
        }

    # Deny all other accounts from using admin login
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, 
        detail="Access Denied: Only authorized Zenvora administrators can enter this terminal."
    )

@router.get("/stats")
async def get_dashboard_stats(admin: User = Depends(require_admin)):
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    total_users = await User.count()
    active_users = await User.find({"last_active": {"$gt": now - timedelta(minutes=15)}}).count()
    active_rooms = await VoiceRoom.find({"is_active": True}).count()
    posts_today = await Post.find({"created_at": {"$gt": today_start}}).count()
    pending_reports = await Report.find({"status": "pending"}).count()
    banned_users = await User.find({"is_banned": True}).count()
    
    growth = []
    for i in range(6, -1, -1):
        date = today_start - timedelta(days=i)
        count = await User.find({"created_at": {"$lt": date + timedelta(days=1)}}).count()
        growth.append({"date": date.strftime("%m-%d"), "users": count})

    return {
        "metrics": {
            "active_users": active_users,
            "active_rooms": active_rooms,
            "total_users": total_users,
            "posts_today": posts_today,
            "pending_reports": pending_reports,
            "banned_users": banned_users
        },
        "growth": growth
    }

@router.get("/users")
async def list_users(admin: User = Depends(require_admin), q: Optional[str] = None):
    query = {}
    if q:
        query["anonymous_username"] = {"$regex": q, "$options": "i"}
    return await User.find(query).limit(100).to_list()

@router.post("/users/{user_id}/ban")
async def ban_user(user_id: str, data: UserBanRequest, admin: User = Depends(require_admin)):
    user = await User.get(user_id)
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.is_banned = True
    user.ban_reason = data.reason
    await user.save()
    await AdminLog(admin_email=admin.email, action="ban_user", target=user.anonymous_username, details={"reason": data.reason}).insert()
    return {"message": "User banned"}

@router.post("/users/{user_id}/shadow-ban")
async def shadow_ban_user(user_id: str, admin: User = Depends(require_admin)):
    user = await User.get(user_id)
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.shadow_banned = True
    await user.save()
    await AdminLog(admin_email=admin.email, action="shadow_ban", target=user.anonymous_username).insert()
    return {"message": "User shadow banned"}

@router.post("/users/{user_id}/unban")
async def unban_user(user_id: str, admin: User = Depends(require_admin)):
    user = await User.get(user_id)
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.is_banned = False
    user.shadow_banned = False
    await user.save()
    return {"message": "User restrictions removed"}

@router.get("/rooms")
async def list_active_rooms(admin: User = Depends(require_admin)):
    return await VoiceRoom.find(VoiceRoom.is_active == True).to_list()

@router.post("/rooms/{room_id}/end")
async def end_room(room_id: str, admin: User = Depends(require_admin)):
    room = await VoiceRoom.get(room_id)
    if not room: raise HTTPException(status_code=404, detail="Room not found")
    room.is_active = False
    await room.save()
    
    # Optional: Force LiveKit room closure
    try:
        await livekit_service.end_room(room_id)
    except:
        pass
        
    return {"message": "Room terminated"}

@router.get("/posts")
async def list_posts(admin: User = Depends(require_admin)):
    return await Post.find_all().sort(-Post.created_at).limit(100).to_list()

@router.get("/chats")
async def list_reported_chats(admin: User = Depends(require_admin)):
    reports = await Report.find({"content_id": {"$exists": True}}).to_list()
    chat_ids = [r.content_id for r in reports if r.reason in ["Harassment", "Spam"]]
    return await Chat.find({"_id": {"$in": [ObjectId(cid) for cid in chat_ids if ObjectId.is_valid(cid)]}}).to_list()

@router.get("/settings")
async def get_settings(admin: User = Depends(require_admin)):
    settings = await PlatformSettings.find_one({})
    if not settings:
        settings = PlatformSettings()
        await settings.insert()
    return settings

@router.patch("/settings")
async def update_settings(data: SettingsUpdate, admin: User = Depends(require_admin)):
    settings = await PlatformSettings.find_one({})
    if not settings:
        settings = PlatformSettings()
        await settings.insert()
    
    for key, value in data.dict(exclude_unset=True).items():
        setattr(settings, key, value)
    
    settings.updated_at = datetime.utcnow()
    await settings.save()
    return settings

@router.get("/logs")
async def get_logs(admin: User = Depends(require_admin)):
    return await AdminLog.find_all().sort(-AdminLog.timestamp).limit(100).to_list()

@router.post("/broadcast")
async def broadcast(data: BroadcastRequest, background_tasks: BackgroundTasks, admin: User = Depends(require_admin)):
    # Create individual notifications for every user
    users = await User.find_all().to_list()
    
    for user in users:
        notification = Notification(
            user_id=user.anonymous_username,
            actor_id="system",
            type="announcement",
            title=data.title,
            message=data.message
        )
        await notification.insert()
    
    # Email Broadcast
    if data.send_email:
        background_tasks.add_task(send_broadcast_emails, data.title, data.message)
        
    return {"message": f"Broadcast sent to {len(users)} users successfully"}

@router.get("/analytics")
async def get_analytics(admin: User = Depends(require_admin)):
    # Simplified analytics
    active_countries = await User.aggregate([
        {"$group": {"_id": "$country", "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
        {"$limit": 5}
    ]).to_list()
    
    return {
        "countries": active_countries,
        "avg_session": "14m",
        "posts_per_user": 3.2
    }

@router.websocket("/ws/dashboard")
async def dashboard_ws(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            now = datetime.utcnow()
            active_now = await User.find({"last_active": {"$gt": now - timedelta(minutes=5)}}).count()
            total_users = await User.count()
            await websocket.send_json({"active_now": active_now, "total_users": total_users, "timestamp": now.isoformat()})
            await asyncio.sleep(5)
    except:
        pass
