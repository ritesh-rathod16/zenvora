from fastapi import APIRouter, HTTPException, Depends
from ..models.livestream import LiveStream
from ..models.user import User
from ..core.security import get_current_user
from pydantic import BaseModel, Field

router = APIRouter()

class StartStreamRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)

@router.post("/start")
async def start_livestream(body: StartStreamRequest, current_user: User = Depends(get_current_user)):
    uname = current_user.anonymous_username
    # End any existing active stream by this host
    await LiveStream.find({"host_id": uname, "is_live": True}).update({"$set": {"is_live": False}})

    stream = LiveStream(
        host_id=uname,
        title=body.title.strip(),
        is_live=True,
        viewers_count=1
    )
    await stream.insert()
    return stream

@router.get("/active")
async def get_active_livestreams(current_user: User = Depends(get_current_user)):
    streams = await LiveStream.find({"is_live": True}).sort(-LiveStream.created_at).to_list()
    result = []
    for s in streams:
        host = await User.find_one({"anonymous_username": s.host_id})
        photo = host.profile_photo_url or host.avatar_url if host else None
        result.append({
            "id": str(s.id),
            "_id": str(s.id),
            "host_id": s.host_id,
            "host_photo": photo,
            "title": s.title,
            "viewers_count": s.viewers_count,
            "created_at": s.created_at.isoformat()
        })
    return result

@router.post("/{stream_id}/end")
async def end_livestream(stream_id: str, current_user: User = Depends(get_current_user)):
    stream = await LiveStream.get(stream_id)
    if not stream or (stream.host_id != current_user.anonymous_username and not current_user.is_admin):
        raise HTTPException(status_code=403, detail="Not authorized")
    stream.is_live = False
    await stream.save()
    return {"success": True, "message": "Livestream ended"}
