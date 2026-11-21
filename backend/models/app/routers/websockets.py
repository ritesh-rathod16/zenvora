from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from ..services.websocket_manager import manager
from jose import JWTError
from ..core.security import decode_access_token
from ..models.user import User
import json

router = APIRouter()

async def get_user_from_token(token: str):
    try:
        payload = decode_access_token(token)
        email: str = payload.get("sub")
        if email is None:
            return None
        user = await User.find_one({"email": email})
        if (
            not user
            or not user.is_active
            or user.is_banned
            or user.age is None
            or user.age < 13
            or payload.get("ver", 0) != getattr(user, "token_version", 0)
        ):
            return None
        return user
    except JWTError:
        return None

@router.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    await _handle_websocket(websocket, token)

@router.websocket("/ws")
async def websocket_query_endpoint(websocket: WebSocket):
    await _handle_websocket(websocket, websocket.query_params.get("token", ""))

async def _handle_websocket(websocket: WebSocket, token: str):
    user = await get_user_from_token(token) if token else None
    if not user:
        await websocket.close(code=1008)
        return

    await manager.connect(user.anonymous_username, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if len(data) > 16_384:
                await websocket.close(code=1009)
                return
            message_data = json.loads(data)
            recipient_id = message_data.get("recipient_id")
            if recipient_id:
                recipient = await User.find_one({"anonymous_username": recipient_id})
                if (
                    not recipient
                    or recipient_id in (user.blocked_users or [])
                    or user.anonymous_username in (recipient.blocked_users or [])
                ):
                    continue
                message_data["sender_id"] = user.anonymous_username
                await manager.send_personal_message(message_data, recipient_id)
    except WebSocketDisconnect:
        manager.disconnect(user.anonymous_username)
    except (ValueError, TypeError):
        await websocket.close(code=1003)
        manager.disconnect(user.anonymous_username)
    except Exception:
        manager.disconnect(user.anonymous_username)
