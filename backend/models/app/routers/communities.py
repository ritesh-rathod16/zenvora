from fastapi import APIRouter, HTTPException, Depends
from ..models.community import Community
from ..models.user import User
from ..core.security import get_current_user
from typing import List, Optional
from pydantic import BaseModel, Field

router = APIRouter()

class CreateCommunityRequest(BaseModel):
    name: str = Field(..., min_length=3, max_length=50)
    description: str = Field(..., max_length=500)
    category: str = "General"
    is_private: bool = False
    cover_url: Optional[str] = None

@router.get("/")
async def get_communities(current_user: User = Depends(get_current_user)):
    return await Community.find().to_list()

@router.post("/create")
async def create_community(body: CreateCommunityRequest, current_user: User = Depends(get_current_user)):
    existing = await Community.find_one({"name": body.name})
    if existing:
        raise HTTPException(status_code=400, detail="Community name already taken")

    comm = Community(
        name=body.name.strip(),
        description=body.description.strip(),
        category=body.category,
        is_private=body.is_private,
        admin_ids=[current_user.anonymous_username],
        members=[current_user.anonymous_username],
        cover_url=body.cover_url
    )
    await comm.insert()
    return comm

@router.post("/{community_id}/join")
async def join_community(community_id: str, current_user: User = Depends(get_current_user)):
    comm = await Community.get(community_id)
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found")
    uname = current_user.anonymous_username
    if uname not in comm.members:
        comm.members.append(uname)
        await comm.save()
    return {"success": True, "members_count": len(comm.members)}
