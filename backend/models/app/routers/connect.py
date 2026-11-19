from fastapi import APIRouter, Depends
from ..models.user import User
from ..models.social import Follow
from ..core.security import get_current_user
from typing import List, Optional
from pydantic import BaseModel

router = APIRouter()

class ConnectUserResponse(BaseModel):
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    latitude: float
    longitude: float
    country: str
    is_online: bool = True
    mutual_count: int = 0

@router.get("/map-users", response_model=List[ConnectUserResponse])
async def get_connect_map_users(current_user: User = Depends(get_current_user)):
    """Returns active users for the ZENVORA Connect interactive social discovery map."""
    me = current_user.anonymous_username
    users = await User.find({
        "anonymous_username": {"$ne": me},
        "is_banned": False,
        "role": {"$nin": ["admin", "super_admin"]}
    }).limit(50).to_list()

    my_following = {f.following_id for f in await Follow.find({"follower_id": me}).to_list()}

    result = []
    for u in users:
        u_following = {f.following_id for f in await Follow.find({"follower_id": u.anonymous_username}).to_list()}
        mutuals = len(my_following & u_following)

        # Mock coordinates around global hubs if 0
        lat = u.latitude if u.latitude != 0.0 else 35.6762 + (hash(u.anonymous_username) % 10) * 0.5
        lng = u.longitude if u.longitude != 0.0 else 139.6503 + (hash(u.anonymous_username) % 10) * 0.5

        result.append(ConnectUserResponse(
            username=u.anonymous_username,
            display_name=u.display_name or u.anonymous_username,
            avatar_url=u.profile_photo_url or u.avatar_url,
            latitude=lat,
            longitude=lng,
            country=u.country or "Global",
            is_online=True,
            mutual_count=mutuals
        ))

    return result
