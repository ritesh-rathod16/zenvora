from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..models.call import CallSession
from ..core.security import get_current_user
from typing import List
from datetime import datetime

router = APIRouter()

@router.post("/start/{chat_id}")
async def start_call(chat_id: str, call_type: str, current_user: User = Depends(get_current_user)):
    """
    Initializes a call session.
    Rule: Users must follow each other to call.
    """
    # Find the other participant in the chat (Simplified logic)
    from ..models.chat import Chat
    chat = await Chat.get(chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    
    partner_username = [p for p in chat.participants if p != current_user.anonymous_username][0]
    partner = await User.find_one({"anonymous_username": partner_username})
    
    # Mutual Follow Check
    if partner_username not in current_user.following or current_user.anonymous_username not in partner.following:
        raise HTTPException(
            status_code=403, 
            detail="Calls are only allowed between mutual followers."
        )

    call = CallSession(
        caller_id=current_user.anonymous_username,
        receiver_id=partner_username,
        chat_id=chat_id,
        call_type=call_type
    )
    await call.insert()
    return call

@router.post("/{call_id}/end")
async def end_call(call_id: str, current_user: User = Depends(get_current_user)):
    call = await CallSession.get(call_id)
    if call:
        call.status = "ended"
        await call.save()
    return {"message": "Call ended"}
