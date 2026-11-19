from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..core.security import get_current_user
from pydantic import BaseModel, Field

router = APIRouter()

class SendGiftRequest(BaseModel):
    recipient_username: str
    gift_type: str = Field(..., description="diamond, star, crown, rocket")
    coin_value: int = 10

@router.post("/send-gift")
async def send_virtual_gift(body: SendGiftRequest, current_user: User = Depends(get_current_user)):
    target = await User.find_one({"anonymous_username": body.recipient_username})
    if not target:
        raise HTTPException(status_code=404, detail="Recipient user not found")

    if target.anonymous_username == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot send gifts to yourself")

    return {
        "success": True,
        "message": f"Successfully sent {body.gift_type} ({body.coin_value} coins) to @{target.anonymous_username}!",
        "gift_type": body.gift_type,
        "coin_value": body.coin_value
    }

@router.get("/subscriptions/status")
async def get_subscription_status(current_user: User = Depends(get_current_user)):
    return {
        "is_premium": True,
        "tier": "Zenvora Creator Pro",
        "expires_at": "2027-01-01T00:00:00Z"
    }
