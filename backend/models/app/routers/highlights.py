from fastapi import APIRouter, HTTPException, Depends
from ..models.highlight import StoryHighlight
from ..models.user import User
from ..core.security import get_current_user, get_optional_current_user
from pydantic import BaseModel, Field
from typing import List, Optional

router = APIRouter()

class CreateHighlightRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=30)
    cover_url: Optional[str] = None
    story_ids: List[str] = Field(..., min_items=1)

@router.get("/{username}")
async def get_user_highlights(username: str, current_user: Optional[User] = Depends(get_optional_current_user)):
    clean_un = username.lstrip('@').strip()
    highlights = await StoryHighlight.find({"user_id": clean_un}).sort(-StoryHighlight.created_at).to_list()
    result = []
    for h in highlights:
        d = h.dict()
        d["id"] = str(h.id)
        d["_id"] = str(h.id)
        result.append(d)
    return result

@router.post("")
@router.post("/")
async def create_highlight(body: CreateHighlightRequest, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    highlight = StoryHighlight(
        user_id=me,
        title=body.title.strip(),
        cover_url=body.cover_url,
        story_ids=body.story_ids
    )
    await highlight.insert()
    return {"success": True, "highlight": highlight.dict()}

@router.delete("/{highlight_id}")
async def delete_highlight(highlight_id: str, current_user: User = Depends(get_current_user)):
    me = current_user.anonymous_username
    h = await StoryHighlight.get(highlight_id)
    if not h or h.user_id != me:
        raise HTTPException(status_code=403, detail="Not authorized")
    await h.delete()
    return {"success": True, "message": "Highlight deleted"}
