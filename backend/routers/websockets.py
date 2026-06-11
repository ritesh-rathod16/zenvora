from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from services.websocket_manager import manager
from jose import jwt, JWTError
import os
from models.user import User

router = APIRouter()

SECRET_KEY = os.getenv("SECRET_KEY", "zenvora_secret_key_2026")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

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
            data = await websocket.receive_json()
            # Handle incoming messages if needed, 
            # though usually we use HTTP POST to send and WS to receive updates
            pass
    except WebSocketDisconnect:
        manager.disconnect(user.anonymous_username)
