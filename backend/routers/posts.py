from fastapi import APIRouter, HTTPException, Depends
from models.post import Post
from models.user import User
from routers.users import get_current_user
from datetime import datetime, timedelta
from typing import List

router = APIRouter()

@router.post("/create")
async def create_post(content: str, current_user: User = Depends(get_current_user)):
    new_post = Post(
        author_id=current_user.anonymous_username,
        content=content,
        expires_at=datetime.utcnow() + timedelta(hours=24)
    )
    await new_post.insert()
    return new_post

@router.get("/feed", response_model=List[Post])
async def get_feed():
    # Only return posts that haven't expired
    now = datetime.utcnow()
    return await Post.find(Post.expires_at > now).sort(-Post.created_at).to_list()

@router.post("/{post_id}/like")
async def like_post(post_id: str, current_user: User = Depends(get_current_user)):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    if current_user.anonymous_username in post.likes:
        post.likes.remove(current_user.anonymous_username)
    else:
        post.likes.append(current_user.anonymous_username)
    
    await post.save()
    return {"likes": len(post.likes)}
