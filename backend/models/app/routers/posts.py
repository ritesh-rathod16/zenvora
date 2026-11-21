from fastapi import APIRouter, HTTPException, Depends, Request, Query
from ..models.post import Post
from ..models.comment import Comment
from ..models.user import User
from ..models.chat import Chat, Message
from ..models.notification import Notification
from ..core.security import get_current_user
from ..core.security import users_blocked
from ..core.rate_limiter import limiter
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel, Field

router = APIRouter()

class CreatePostRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)
    media_url: Optional[str] = None

class CreateCommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)
    parent_comment_id: Optional[str] = None

class SharePostRequest(BaseModel):
    recipients: List[str] = Field(..., min_items=1)

async def _ensure_post_access(post: Post, current_user: User):
    author = await User.find_one({"anonymous_username": post.author_id})
    if not author or users_blocked(current_user, author):
        raise HTTPException(status_code=404, detail="Post not found")

async def _enrich_post(post: Post, current_username: Optional[str] = None) -> Dict[str, Any]:
    author = await User.find_one({"anonymous_username": post.author_id})
    author_photo = None
    if author:
        author_photo = author.profile_photo_url or author.avatar_url
        if author_photo and "dicebear.com" in author_photo:
            author_photo = None

    is_liked = current_username in post.likes if current_username else False
    is_reposted = current_username in post.reposts if current_username else False

    data = post.dict()
    data["id"] = str(post.id)
    data["_id"] = str(post.id)
    data["author_photo"] = author_photo
    data["author_name"] = author.anonymous_username if author else post.author_id
    data["likes_count"] = len(post.likes)
    data["is_liked"] = is_liked
    data["is_reposted"] = is_reposted
    data["reposts_count"] = len(post.reposts)
    data["comments_count"] = post.replies_count
    return data

@router.post("/create")
@limiter.limit("10/minute")
async def create_post(request: Request, body: CreatePostRequest, current_user: User = Depends(get_current_user)):
    content = body.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Post content cannot be empty")

    now = datetime.now(timezone.utc)
    new_post = Post(
        author_id=current_user.anonymous_username,
        content=content,
        media_url=body.media_url,
        expires_at=now + timedelta(days=365) # Persist active posts
    )
    await new_post.insert()
    return await _enrich_post(new_post, current_user.anonymous_username)

@router.get("/feed")
async def get_feed(current_user: Optional[User] = Depends(get_current_user)):
    now = datetime.now(timezone.utc)
    posts = await Post.find({"expires_at": {"$gt": now}}).sort(-Post.created_at).limit(50).to_list()
    username = current_user.anonymous_username if current_user else None
    return [await _enrich_post(p, username) for p in posts]

@router.get("/user/{username}")
async def get_user_posts(username: str, current_user: Optional[User] = Depends(get_current_user)):
    posts = await Post.find({"author_id": username, "is_repost": False}).sort(-Post.created_at).to_list()
    current_un = current_user.anonymous_username if current_user else None
    return [await _enrich_post(p, current_un) for p in posts]

@router.get("/user/{username}/reposts")
async def get_user_reposts(username: str, current_user: Optional[User] = Depends(get_current_user)):
    posts = await Post.find({"author_id": username, "is_repost": True}).sort(-Post.created_at).to_list()
    current_un = current_user.anonymous_username if current_user else None
    return [await _enrich_post(p, current_un) for p in posts]

@router.post("/{post_id}/like")
@limiter.limit("60/minute")
async def like_post(request: Request, post_id: str, current_user: User = Depends(get_current_user)):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    await _ensure_post_access(post, current_user)
    
    uname = current_user.anonymous_username
    liked = False
    if uname in post.likes:
        post.likes.remove(uname)
        liked = False
    else:
        post.likes.append(uname)
        liked = True

        # Send notification to post author (if not self)
        if post.author_id != uname:
            notif = Notification(
                user_id=post.author_id,
                type="like",
                actor_ids=[uname],
                message=f"@{uname} liked your post",
                metadata={"post_id": str(post.id)}
            )
            await notif.insert()

    await post.save()
    return {
        "liked": liked,
        "likes_count": len(post.likes),
        "likes": post.likes
    }

@router.get("/{post_id}/likers")
async def get_post_likers(post_id: str):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    likers = []
    for uname in post.likes:
        u = await User.find_one({"anonymous_username": uname})
        photo = None
        if u:
            photo = u.profile_photo_url or u.avatar_url
            if photo and "dicebear.com" in photo:
                photo = None
        likers.append({
            "username": uname,
            "profile_photo_url": photo,
            "trust_score": u.trust_score if u else 100
        })
    return likers

@router.get("/{post_id}/comments")
async def get_comments(post_id: str):
    comments = await Comment.find({"post_id": post_id}).sort(Comment.created_at).to_list()
    result = []
    for c in comments:
        author = await User.find_one({"anonymous_username": c.author_id})
        photo = None
        if author:
            photo = author.profile_photo_url or author.avatar_url
            if photo and "dicebear.com" in photo:
                photo = None
        result.append({
            "id": str(c.id),
            "_id": str(c.id),
            "post_id": c.post_id,
            "author_id": c.author_id,
            "author_photo": photo,
            "content": c.content,
            "parent_comment_id": c.parent_comment_id,
            "likes_count": len(c.likes),
            "created_at": c.created_at.isoformat()
        })
    return result

@router.post("/{post_id}/comments")
async def add_comment(post_id: str, body: CreateCommentRequest, current_user: User = Depends(get_current_user)):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    await _ensure_post_access(post, current_user)

    content = body.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Comment cannot be empty")

    comment = Comment(
        post_id=post_id,
        author_id=current_user.anonymous_username,
        content=content,
        parent_comment_id=body.parent_comment_id
    )
    await comment.insert()

    # Increment reply count
    post.replies_count += 1
    await post.save()

    # Notify post author if not self
    if post.author_id != current_user.anonymous_username:
        notif = Notification(
            user_id=post.author_id,
            type="comment",
            actor_ids=[current_user.anonymous_username],
            message=f"@{current_user.anonymous_username} commented: {content[:50]}",
            metadata={"post_id": post_id, "comment_id": str(comment.id)}
        )
        await notif.insert()

    author_photo = current_user.profile_photo_url or current_user.avatar_url
    if author_photo and "dicebear.com" in author_photo:
        author_photo = None

    return {
        "id": str(comment.id),
        "_id": str(comment.id),
        "post_id": post_id,
        "author_id": comment.author_id,
        "author_photo": author_photo,
        "content": comment.content,
        "parent_comment_id": comment.parent_comment_id,
        "likes_count": 0,
        "created_at": comment.created_at.isoformat()
    }

@router.delete("/comments/{comment_id}")
async def delete_comment(comment_id: str, current_user: User = Depends(get_current_user)):
    comment = await Comment.get(comment_id)
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    
    if comment.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    post = await Post.get(comment.post_id)
    if post and post.replies_count > 0:
        post.replies_count = max(0, post.replies_count - 1)
        await post.save()

    await comment.delete()
    return {"message": "Comment deleted successfully"}

@router.post("/{post_id}/repost")
async def toggle_repost(post_id: str, current_user: User = Depends(get_current_user)):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    await _ensure_post_access(post, current_user)

    uname = current_user.anonymous_username
    reposted = False

    if uname in post.reposts:
        # Undo repost
        post.reposts.remove(uname)
        reposted = False
        # Remove cloned repost post
        await Post.find({"author_id": uname, "original_post_id": post_id, "is_repost": True}).delete()
    else:
        # Create repost
        post.reposts.append(uname)
        reposted = True

        now = datetime.now(timezone.utc)
        repost_doc = Post(
            author_id=uname,
            content=post.content,
            media_url=post.media_url,
            is_repost=True,
            original_author_id=post.author_id,
            original_post_id=str(post.id),
            expires_at=now + timedelta(days=365)
        )
        await repost_doc.insert()

        # Send notification to original author
        if post.author_id != uname:
            notif = Notification(
                user_id=post.author_id,
                type="repost",
                actor_ids=[uname],
                message=f"@{uname} reposted your post",
                metadata={"post_id": str(post.id)}
            )
            await notif.insert()

    await post.save()
    return {
        "reposted": reposted,
        "reposts_count": len(post.reposts)
    }

@router.post("/{post_id}/share")
async def share_post(post_id: str, body: SharePostRequest, current_user: User = Depends(get_current_user)):
    post = await Post.get(post_id)
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    await _ensure_post_access(post, current_user)

    sender = current_user.anonymous_username
    sent_count = 0

    for recipient in body.recipients:
        if recipient == sender:
            continue
        target = await User.find_one({"anonymous_username": recipient})
        if not target:
            raise HTTPException(status_code=404, detail="Recipient not found")
        if users_blocked(current_user, target):
            raise HTTPException(status_code=403, detail="Interaction blocked")

        # Find or create 1-on-1 Chat
        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=f"Shared post by @{post.author_id}")
            await chat.insert()

        # Create DM message of type 'post_share'
        share_msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Shared a post by @{post.author_id}: {post.content[:80]}",
            message_type="post_share"
        )
        await share_msg.insert()

        chat.last_message = f"Shared post by @{post.author_id}"
        chat.updated_at = datetime.utcnow()
        await chat.save()

        # Notify recipient
        notif = Notification(
            user_id=recipient,
            type="message",
            actor_ids=[sender],
            message=f"@{sender} shared a post with you",
            metadata={"post_id": str(post.id), "chat_id": str(chat.id)}
        )
        await notif.insert()
        sent_count += 1

    post.shares_count += sent_count
    await post.save()

    return {
        "success": True,
        "shares_count": post.shares_count,
        "delivered_to": sent_count
    }

@router.get("/trending")
async def get_trending_posts(current_user: Optional[User] = Depends(get_current_user)):
    """Fetch trending posts sorted by likes and recency."""
    now = datetime.now(timezone.utc)
    posts = await Post.find({"expires_at": {"$gt": now}}).sort(-Post.created_at).limit(20).to_list()
    # Sort in memory by likes count
    posts.sort(key=lambda p: len(p.likes), reverse=True)
    username = current_user.anonymous_username if current_user else None
    return [await _enrich_post(p, username) for p in posts]
