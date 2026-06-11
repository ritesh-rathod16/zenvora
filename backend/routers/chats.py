from fastapi import APIRouter, HTTPException, Depends
from models.chat import Chat, Message
from models.user import User
from routers.users import get_current_user
from typing import List
from datetime import datetime

router = APIRouter()

@router.get("/", response_model=List[Chat])
async def get_my_chats(current_user: User = Depends(get_current_user)):
    return await Chat.find(Chat.participants == current_user.anonymous_username).sort(-Chat.updated_at).to_list()

@router.post("/start/{target_username}")
async def start_chat(target_username: str, current_user: User = Depends(get_current_user)):
    if target_username == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot chat with yourself")
    
    target_user = await User.find_one(User.anonymous_username == target_username)
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    existing_chat = await Chat.find_one({
        "participants": {"$all": [current_user.anonymous_username, target_username]}
    })
    
    if existing_chat:
        return existing_chat
    
    new_chat = Chat(participants=[current_user.anonymous_username, target_username])
    await new_chat.insert()
    return new_chat

@router.get("/{chat_id}/messages", response_model=List[Message])
async def get_messages(chat_id: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized to view these messages")
        
    return await Message.find(Message.chat_id == chat_id).sort(Message.created_at).to_list()

@router.post("/{chat_id}/send")
async def send_message(chat_id: str, content: str, current_user: User = Depends(get_current_user)):
    chat = await Chat.get(chat_id)
    if not chat or current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    message = Message(
        chat_id=chat_id,
        sender_id=current_user.anonymous_username,
        content=content
    )
    await message.insert()
    
    chat.last_message = content
    chat.updated_at = datetime.utcnow()
    await chat.save()
    
    return message
