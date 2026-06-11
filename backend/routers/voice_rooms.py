from fastapi import APIRouter, HTTPException, Depends
from models.voice_room import VoiceRoom
from models.user import User
from routers.users import get_current_user
from typing import List

router = APIRouter()

@router.get("/", response_model=List[VoiceRoom])
async def get_rooms():
    return await VoiceRoom.find(VoiceRoom.is_active == True).to_list()

@router.post("/create")
async def create_room(title: str, description: str, category: str, current_user: User = Depends(get_current_user)):
    room = VoiceRoom(
        title=title,
        description=description,
        category=category,
        creator_id=current_user.anonymous_username,
        participants=[current_user.anonymous_username]
    )
    await room.insert()
    return room

@router.post("/{room_id}/join")
async def join_room(room_id: str, current_user: User = Depends(get_current_user)):
    room = await VoiceRoom.get(room_id)
    if not room:
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
        await room.save()
    
    return {"message": "Left room"}
