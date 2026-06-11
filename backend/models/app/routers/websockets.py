from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from ..services.websocket_manager import manager
from jose import jwt, JWTError
from ..utils.auth import SECRET_KEY, ALGORITHM
from ..models.user import User
import json

router = APIRouter()

async def get_user_from_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            return None
        user = await User.find_one(User.email == email)
        return user
    except JWTError:
        return None

@router.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    user = await get_user_from_token(token)
    if not user:
        await websocket.close(code=1008)
        return

    await manager.connect(user.anonymous_username, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Message logic: forward to recipient
            recipient_id = message_data.get("recipient_id")
            if recipient_id:
                await manager.send_personal_message(message_data, recipient_id)
            
    except WebSocketDisconnect:
        manager.disconnect(user.anonymous_username)
    except Exception as e:
        print(f"WebSocket Error: {e}")
        manager.disconnect(user.anonymous_username)
