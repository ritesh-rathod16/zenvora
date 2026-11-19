from fastapi import APIRouter, Depends
from ..models.user import User
from ..models.post import Post
from ..models.reel import Reel
from ..core.security import get_current_user

router = APIRouter()

@router.get("/dashboard")
async def get_creator_dashboard(current_user: User = Depends(get_current_user)):
    uname = current_user.anonymous_username
    posts = await Post.find({"author_id": uname}).to_list()
    reels = await Reel.find({"author_id": uname}).to_list()

    total_likes = sum(len(p.likes) for p in posts) + sum(len(r.likes) for r in reels)
    total_reposts = sum(len(p.reposts) for p in posts) + sum(len(r.reposts) for r in reels)

    return {
        "username": uname,
        "is_verified": current_user.is_verified,
        "verification_badge_type": current_user.verification_badge_type,
        "followers_count": current_user.followers_count,
        "following_count": current_user.following_count,
        "posts_count": len(posts),
        "reels_count": len(reels),
        "total_engagement_likes": total_likes,
        "total_reposts": total_reposts,
        "daily_streak": current_user.daily_streak,
        "estimated_earnings": 142.50 # Virtual gifts & subscriber rewards placeholder
    }
