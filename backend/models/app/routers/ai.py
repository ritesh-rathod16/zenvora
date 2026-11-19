from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..core.security import get_current_user
from pydantic import BaseModel
from typing import List

router = APIRouter()

class PromptRequest(BaseModel):
    prompt: str

@router.post("/generate-caption")
async def generate_caption(body: PromptRequest, current_user: User = Depends(get_current_user)):
    p = body.prompt.strip()
    return {"caption": f"✨ Exploring new horizons in {p or 'Zenvora'}. Thoughts? 🚀 #Zenvora #Vibes"}

@router.post("/hashtag-suggestions")
async def generate_hashtags(body: PromptRequest, current_user: User = Depends(get_current_user)):
    return {"hashtags": ["#Zenvora", "#Discover", "#Connection", "#Vibes", "#Trending"]}

@router.post("/generate-bio")
async def generate_bio(body: PromptRequest, current_user: User = Depends(get_current_user)):
    return {"bio": f"Living life on my own terms. Passionate about {body.prompt or 'creativity'} and genuine connections. ✨"}
