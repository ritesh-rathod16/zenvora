from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..models.call import CallSession
from ..core.security import get_current_user
from ..core.security import users_blocked
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
    if current_user.anonymous_username not in chat.participants:
        raise HTTPException(status_code=403, detail="Not authorized")
    partner_usernames = [p for p in chat.participants if p != current_user.anonymous_username]
    if len(partner_usernames) != 1:
        raise HTTPException(status_code=400, detail="Calls require a direct conversation")
    partner_username = partner_usernames[0]
    partner = await User.find_one({"anonymous_username": partner_username})
    if not partner:
        raise HTTPException(status_code=404, detail="User not found")
    if users_blocked(current_user, partner):
        raise HTTPException(status_code=403, detail="Interaction blocked")

    # Mutual Follow Check
    from ..models.social import Follow
    mutual_follow = await Follow.find_one({
        "follower_id": current_user.anonymous_username,
        "following_id": partner_username,
    })
    reverse_follow = await Follow.find_one({
        "follower_id": partner_username,
        "following_id": current_user.anonymous_username,
    })
    if not mutual_follow or not reverse_follow:
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
    if not call or current_user.anonymous_username not in [call.caller_id, call.receiver_id]:
        raise HTTPException(status_code=404, detail="Call not found")
    call.status = "ended"
    await call.save()
    return {"message": "Call ended"}
