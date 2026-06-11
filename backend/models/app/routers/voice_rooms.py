from fastapi import APIRouter, HTTPException, Depends
from ..models.voice_room import VoiceRoom
from ..models.user import User
from ..core.security import get_current_user
from ..services.livekit_service import livekit_service
from ..services.ghost_identity_service import ghost_service
from typing import List
from pydantic import BaseModel

router = APIRouter()

class VoiceRoomCreate(BaseModel):
    title: str
    description: str
    category: str

@router.get("/", response_model=List[VoiceRoom])
async def get_active_rooms():
    return await VoiceRoom.find(VoiceRoom.is_active == True).to_list()

@router.post("/create")
async def create_room(data: VoiceRoomCreate, current_user: User = Depends(get_current_user)):
    room = VoiceRoom(
        title=data.title,
        description=data.description,
        category=data.category,
        creator_id=current_user.anonymous_username,
        participants=[current_user.anonymous_username]
    )
    await room.insert()
    return room

@router.get("/{room_id}/token")
async def get_room_token(room_id: str, current_user: User = Depends(get_current_user)):
    room = await VoiceRoom.get(room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # Use Ghost Identity for anonymity
    identity = await ghost_service.get_or_regenerate_identity(str(current_user.id))
    
    token = livekit_service.create_token(
        room_name=room_id,
        participant_identity=identity.alias,
        is_admin=(room.creator_id == current_user.anonymous_username)
    )
    
    return {
        "token": token,
        "url": livekit_service.url,
        "identity": identity.alias,
        "avatar": identity.avatar_url
    }

@router.post("/{room_id}/join")
async def join_room(room_id: str, current_user: User = Depends(get_current_user)):
    room = await VoiceRoom.get(room_id)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Room not found")
    
    if current_user.anonymous_username not in room.participants:
        room.participants.append(current_user.anonymous_username)
        await room.save()
    
    return room

@router.post("/{room_id}/leave")
async def leave_room(room_id: str, current_user: User = Depends(get_current_user)):
    room = await VoiceRoom.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    if current_user.anonymous_username in room.participants:
        room.participants.remove(current_user.anonymous_username)
        if not room.participants:
            room.is_active = False
        await room.save()
    
    return {"message": "Left room"}
