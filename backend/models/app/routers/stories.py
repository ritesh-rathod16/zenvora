from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form, Body
from ..models.story import Story
from ..models.user import User
from ..models.chat import Chat, Message
from ..models.notification import Notification
from ..models.social import Follow
from ..core.security import get_current_user, get_optional_current_user, users_blocked
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta, timezone
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
import os
import io
import json
import httpx
from PIL import Image
from bson import ObjectId
import logging
from pydantic import BaseModel, Field

router = APIRouter()
logger = logging.getLogger(__name__)

class StoryReactionRequest(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=10)

class StoryReplyRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=1000)

class PollVoteRequest(BaseModel):
    option_index: int

class QuestionResponseRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)

class QuizVoteRequest(BaseModel):
    option_index: int

class StorySettingsUpdateRequest(BaseModel):
    allow_story_replies: Optional[str] = None # everyone, following, nobody
    allow_story_reactions: Optional[bool] = None
    allow_story_likes: Optional[bool] = None
    allow_story_sharing: Optional[bool] = None
    allow_story_mentions: Optional[str] = None # everyone, following, nobody
    save_to_archive: Optional[bool] = None
    save_original: Optional[bool] = None

class StoryShareRequest(BaseModel):
    recipients: List[str] = Field(..., min_items=1)

async def _ensure_story_access(story: Story, current_user: User) -> Optional[User]:
    author = await User.find_one({"anonymous_username": story.author_id})
    if not author or users_blocked(current_user, author):
        raise HTTPException(status_code=404, detail="Story not found")
    is_owner = current_user.anonymous_username == author.anonymous_username
    expires_at = story.expires_at
    if expires_at and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if not is_owner and expires_at and expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=404, detail="Story not found")
    if not is_owner and (
        current_user.anonymous_username in (author.hide_story_from or [])
        or story.is_close_friends_only
        and current_user.anonymous_username not in (author.close_friends or [])
    ):
        raise HTTPException(status_code=404, detail="Story not found")
    return author

def format_time_ago(dt: datetime) -> str:
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    diff = max(0, int((now - dt).total_seconds()))
    if diff < 60:
        return "Just now"
    mins = diff // 60
    if mins < 60:
        return f"{mins}m ago"
    hours = mins // 60
    if hours < 24:
        return f"{hours}h ago"
    days = hours // 24
    return f"{days}d ago"

async def _enrich_story(story: Story, current_username: Optional[str] = None) -> Dict[str, Any]:
    author = await User.find_one({"anonymous_username": story.author_id})
    author_photo = None
    if author:
        author_photo = author.profile_photo_url or author.avatar_url
        if author_photo and "dicebear.com" in author_photo:
            author_photo = None

    is_liked = current_username in story.likes if current_username else False

    quiz_data = None
    if story.quiz:
        q = dict(story.quiz)
        has_voted = current_username in q.get("votes", {})
        if current_username != story.author_id and not has_voted:
            q.pop("correct_option_index", None)
        quiz_data = q

    data = story.dict()
    data["id"] = str(story.id)
    data["_id"] = str(story.id)
    data["author_photo"] = author_photo
    data["likes_count"] = len(story.likes)
    data["views_count"] = len(story.views)
    data["is_liked"] = is_liked
    data["quiz"] = quiz_data
    data["created_at"] = story.created_at.isoformat()
    data["expires_at"] = story.expires_at.isoformat()
    data["time_ago"] = format_time_ago(story.created_at)
    data["is_close_friends_only"] = story.is_close_friends_only
    return data

@router.get("/settings")
async def get_story_settings(current_user: User = Depends(get_current_user)):
    return {
        "story_settings": current_user.story_settings,
        "close_friends": current_user.close_friends,
        "hide_story_from": current_user.hide_story_from
    }

@router.put("/settings")
async def update_story_settings(body: StorySettingsUpdateRequest, current_user: User = Depends(get_current_user)):
    settings = current_user.story_settings or {}
    if body.allow_story_replies is not None:
        settings["allow_story_replies"] = body.allow_story_replies
    if body.allow_story_reactions is not None:
        settings["allow_story_reactions"] = body.allow_story_reactions
    if body.allow_story_likes is not None:
        settings["allow_story_likes"] = body.allow_story_likes
    if body.allow_story_sharing is not None:
        settings["allow_story_sharing"] = body.allow_story_sharing
    if body.allow_story_mentions is not None:
        settings["allow_story_mentions"] = body.allow_story_mentions
    if body.save_to_archive is not None:
        settings["save_to_archive"] = body.save_to_archive
    if body.save_original is not None:
        settings["save_original"] = body.save_original

    current_user.story_settings = settings
    await current_user.save()
    return {"message": "Story settings updated", "story_settings": current_user.story_settings}

@router.get("/close-friends")
async def get_close_friends(current_user: User = Depends(get_current_user)):
    users = await User.find({"anonymous_username": {"$in": current_user.close_friends}}).to_list()
    return [{
        "username": u.anonymous_username,
        "display_name": u.display_name or u.anonymous_username,
        "profile_photo_url": u.profile_photo_url or u.avatar_url
    } for u in users]

@router.post("/close-friends/{username}")
async def add_close_friend(username: str, current_user: User = Depends(get_current_user)):
    if username == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot add yourself to close friends")
    if username not in current_user.close_friends:
        current_user.close_friends.append(username)
        await current_user.save()
    return {"message": f"Added @{username} to Close Friends"}

@router.post("/{story_id}/poll-vote")
async def vote_on_story_poll(story_id: str, body: PollVoteRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story or not story.poll:
        raise HTTPException(status_code=404, detail="Poll not found on this story")
    await _ensure_story_access(story, current_user)

    uname = current_user.anonymous_username
    poll = story.poll
    votes = poll.get("votes", {})
    votes[uname] = body.option_index
    poll["votes"] = votes
    story.poll = poll
    await story.save()
    return {"success": True, "poll": story.poll}

@router.post("/{story_id}/question-response")
async def respond_to_question(story_id: str, body: QuestionResponseRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story or not story.question_box:
        raise HTTPException(status_code=404, detail="Question box not found on this story")
    await _ensure_story_access(story, current_user)

    sender = current_user.anonymous_username
    recipient = story.author_id

    qbox = story.question_box
    responses = qbox.get("responses", [])
    responses.append({
        "username": sender,
        "text": body.text,
        "created_at": datetime.utcnow().isoformat()
    })
    qbox["responses"] = responses
    story.question_box = qbox
    await story.save()

    if sender != recipient:
        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=f"Answered your question: {body.text}")
            await chat.insert()

        msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Answered your question: {body.text}",
            message_type="story_reply",
            attachment_url=story.media_url
        )
        await msg.insert()

        chat.last_message = f"Answered your question: {body.text[:40]}"
        chat.updated_at = datetime.utcnow()
        await chat.save()

        notif = Notification(
            user_id=recipient,
            type="story_question_response",
            actor_ids=[sender],
            message=f"@{sender} answered your question: {body.text[:50]}",
            metadata={"story_id": story_id, "chat_id": str(chat.id)}
        )
        await notif.insert()

    return {"success": True, "message": "Response delivered to story owner"}

@router.get("/{story_id}/question-responses")
async def get_question_responses(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    await _ensure_story_access(story, current_user)

    if story.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Only story owner can view question responses")

    return {
        "question_box": story.question_box,
        "responses": story.question_box.get("responses", []) if story.question_box else []
    }

@router.post("/{story_id}/quiz-vote")
async def vote_on_story_quiz(story_id: str, body: QuizVoteRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story or not story.quiz:
        raise HTTPException(status_code=404, detail="Quiz not found on this story")
    await _ensure_story_access(story, current_user)

    uname = current_user.anonymous_username
    quiz = story.quiz
    options = quiz.get("options", [])
    if not (0 <= body.option_index < len(options)):
        raise HTTPException(status_code=400, detail="Invalid option index")

    votes = quiz.get("votes", {})
    votes[uname] = body.option_index
    quiz["votes"] = votes
    story.quiz = quiz
    await story.save()

    correct_index = quiz.get("correct_option_index", 0)
    is_correct = (body.option_index == correct_index)

    return {
        "success": True,
        "is_correct": is_correct,
        "correct_option_index": correct_index,
        "quiz": story.quiz
    }

@router.get("/{story_id}/quiz-stats")
async def get_quiz_stats(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story or not story.quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    await _ensure_story_access(story, current_user)

    if story.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Only story owner can access quiz analytics")

    votes = story.quiz.get("votes", {})
    correct_index = story.quiz.get("correct_option_index", 0)
    total_votes = len(votes)
    correct_count = sum(1 for idx in votes.values() if idx == correct_index)
    percentage = (correct_count / total_votes * 100) if total_votes > 0 else 0.0

    return {
        "total_votes": total_votes,
        "correct_count": correct_count,
        "incorrect_count": total_votes - correct_count,
        "correct_percentage": round(percentage, 1),
        "votes": votes,
        "quiz": story.quiz
    }

@router.get("/hide-from")
async def get_hide_story_users(current_user: User = Depends(get_current_user)):
    users = await User.find({"anonymous_username": {"$in": current_user.hide_story_from}}).to_list()
    return [{
        "username": u.anonymous_username,
        "display_name": u.display_name or u.anonymous_username,
        "profile_photo_url": u.profile_photo_url or u.avatar_url
    } for u in users]

@router.post("/hide-from/{username}")
async def hide_story_from_user(username: str, current_user: User = Depends(get_current_user)):
    if username == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot hide stories from yourself")
    if username not in current_user.hide_story_from:
        current_user.hide_story_from.append(username)
        await current_user.save()
    return {"message": f"Hiding stories from @{username}"}

@router.delete("/hide-from/{username}")
async def unhide_story_from_user(username: str, current_user: User = Depends(get_current_user)):
    if username in current_user.hide_story_from:
        current_user.hide_story_from.remove(username)
        await current_user.save()
    return {"message": f"Unhid stories from @{username}"}

GIPHY_API_KEY = os.getenv("GIPHY_API_KEY", "dc6zaTOxFJmzC")

@router.get("/gifs/trending")
async def get_trending_gifs(current_user: User = Depends(get_current_user)):
    try:
        async with httpx.AsyncClient() as client:
            res = await client.get(f"https://api.giphy.com/v1/gifs/trending?api_key={GIPHY_API_KEY}&limit=20")
            if res.status_code == 200:
                return res.json().get("data", [])
        return []
    except Exception:
        return []

@router.get("/gifs/search")
async def search_gifs(q: str, current_user: User = Depends(get_current_user)):
    try:
        async with httpx.AsyncClient() as client:
            res = await client.get(f"https://api.giphy.com/v1/gifs/search?api_key={GIPHY_API_KEY}&q={q}&limit=20")
            if res.status_code == 200:
                return res.json().get("data", [])
        return []
    except Exception:
        return []

@router.post("/create")
@router.post("/upload")
async def create_story(
    file: UploadFile = File(...),
    is_close_friends_only: bool = Form(False),
    caption: Optional[str] = Form(None),
    layers: Optional[str] = Form(None),
    poll: Optional[str] = Form(None),
    question_box: Optional[str] = Form(None),
    quiz: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user)
):
    """Uploads a story image to GridFS and creates a record."""
    if not file.content_type or not (file.content_type.startswith("image/") or file.content_type == "application/octet-stream"):
        raise HTTPException(status_code=400, detail=f"Invalid image format: {file.content_type}")

    try:
        content = await file.read()
        img = Image.open(io.BytesIO(content)).convert("RGB")
        img.thumbnail((1080, 1920))

        output = io.BytesIO()
        img.save(output, format="JPEG", quality=80)
        processed = output.getvalue()

        from ..core.database import db
        bucket = AsyncIOMotorGridFSBucket(db)
        now = datetime.utcnow()

        file_id = await bucket.upload_from_stream(
            f"story_{current_user.id}_{now.timestamp()}.jpg",
            processed,
            metadata={"contentType": "image/jpeg", "userId": str(current_user.id)}
        )

        media_url = f"/media/stories/{file_id}"

        parsed_layers = []
        if layers:
            try:
                parsed_layers = json.loads(layers)
            except Exception:
                pass

        parsed_poll = None
        if poll:
            try:
                parsed_poll = json.loads(poll)
            except Exception:
                pass

        parsed_qbox = None
        if question_box:
            try:
                parsed_qbox = json.loads(question_box)
            except Exception:
                pass

        parsed_quiz = None
        if quiz:
            try:
                parsed_quiz = json.loads(quiz)
            except Exception:
                pass

        new_story = Story(
            author_id=current_user.anonymous_username,
            media_url=media_url,
            caption=caption,
            layers=parsed_layers,
            poll=parsed_poll,
            question_box=parsed_qbox,
            quiz=parsed_quiz,
            is_close_friends_only=is_close_friends_only,
            expires_at=now + timedelta(hours=24)
        )
        await new_story.insert()
        return await _enrich_story(new_story, current_user.anonymous_username)
    except Exception:
        logger.error("Story upload failed.")
        raise HTTPException(status_code=400, detail="Failed to process story")

@router.get("/feed")
async def get_stories_feed(current_user: Optional[User] = Depends(get_optional_current_user)):
    """Fetch all active stories respecting privacy settings, blocks, and close friends lists."""
    now = datetime.utcnow()
    all_stories = await Story.find({"$or": [{"expires_at": {"$gt": now}}, {"expires_at": None}]}).sort(-Story.created_at).to_list()

    viewer_name = current_user.anonymous_username if current_user else None
    filtered_stories = []

    for story in all_stories:
        author = await User.find_one({"anonymous_username": story.author_id})
        if not author:
            continue

        if (
            story.is_close_friends_only
            and (
                not viewer_name
                or viewer_name != author.anonymous_username
                and viewer_name not in (author.close_friends or [])
            )
        ):
            continue

        if viewer_name:
            # Check blocks
            if viewer_name in author.blocked_users or author.anonymous_username in current_user.blocked_users:
                continue

            # Check hide_story_from
            if viewer_name in author.hide_story_from:
                continue

            # Check Close Friends privacy
            if story.is_close_friends_only and viewer_name != author.anonymous_username:
                if viewer_name not in author.close_friends:
                    continue

        filtered_stories.append(await _enrich_story(story, viewer_name))

    return filtered_stories

@router.post("/{story_id}/view")
async def view_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    await _ensure_story_access(story, current_user)

    uname = current_user.anonymous_username
    already_viewed = any(v.get("username") == uname for v in story.views)
    if not already_viewed:
        story.views.append({
            "user_id": str(current_user.id),
            "username": uname,
            "full_name": current_user.full_name,
            "avatar_url": current_user.profile_photo_url or current_user.avatar_url,
            "viewed_at": datetime.now(timezone.utc).isoformat()
        })
        await story.save()

    return {"success": True, "views_count": len(story.views)}

@router.get("/archive")
async def get_story_archive(current_user: User = Depends(get_current_user)):
    uname = current_user.anonymous_username
    stories = await Story.find({"author_id": uname, "save_to_archive": True}).sort(-Story.created_at).to_list()
    return [await _enrich_story(s, uname) for s in stories]

@router.get("/{story_id}/viewers")
async def get_story_viewers(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    await _ensure_story_access(story, current_user)

    if story.author_id != current_user.anonymous_username:
        raise HTTPException(status_code=403, detail="Only story owner can access full viewer list")

    return {
        "views_count": len(story.views),
        "viewers": story.views
    }

@router.post("/{story_id}/like")
async def like_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    await _ensure_story_access(story, current_user)

    author = await User.find_one({"anonymous_username": story.author_id})
    if author and author.story_settings.get("allow_story_likes") is False:
        raise HTTPException(status_code=403, detail="Story owner has disabled story likes")

    uname = current_user.anonymous_username
    liked = False
    if uname in story.likes:
        story.likes.remove(uname)
        liked = False
    else:
        story.likes.append(uname)
        liked = True

        if story.author_id != uname:
            notif = Notification(
                user_id=story.author_id,
                type="story_like",
                actor_ids=[uname],
                message=f"@{uname} liked your story",
                metadata={"story_id": story_id}
            )
            await notif.insert()

    await story.save()
    return {"liked": liked, "likes_count": len(story.likes)}

@router.post("/{story_id}/react")
async def react_to_story(story_id: str, body: StoryReactionRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    author = await _ensure_story_access(story, current_user)
    if author and author.story_settings.get("allow_story_reactions") is False:
        raise HTTPException(status_code=403, detail="Story owner has disabled story reactions")

    sender = current_user.anonymous_username
    recipient = story.author_id

    if story.reactions is None:
        story.reactions = []

    existing = next((r for r in story.reactions if r.get("username") == sender), None)
    removed = False
    if existing:
        story.reactions.remove(existing)
        if existing.get("emoji") != body.emoji:
            story.reactions.append({
                "username": sender,
                "emoji": body.emoji,
                "created_at": datetime.utcnow().isoformat()
            })
        else:
            removed = True
    else:
        story.reactions.append({
            "username": sender,
            "emoji": body.emoji,
            "created_at": datetime.utcnow().isoformat()
        })

    await story.save()

    if not removed and sender != recipient:
        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=f"Reacted {body.emoji} to your story")
            await chat.insert()

        msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Reacted {body.emoji} to your story",
            message_type="story_reaction",
            attachment_url=story.media_url
        )
        await msg.insert()

        chat.last_message = f"Reacted {body.emoji} to your story"
        chat.updated_at = datetime.utcnow()
        await chat.save()

        notif = Notification(
            user_id=recipient,
            type="story_reaction",
            actor_ids=[sender],
            message=f"@{sender} reacted {body.emoji} to your story",
            metadata={"story_id": story_id, "chat_id": str(chat.id)}
        )
        await notif.insert()

    return {"success": True, "removed": removed, "emoji": body.emoji, "reactions_count": len(story.reactions)}

@router.post("/{story_id}/reply")
async def reply_to_story(story_id: str, body: StoryReplyRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    author = await _ensure_story_access(story, current_user)
    if author:
        allow_replies = author.story_settings.get("allow_story_replies", "everyone")
        if allow_replies == "nobody":
            raise HTTPException(status_code=403, detail="Story owner has disabled story replies")
        elif allow_replies == "following":
            is_follower = await Follow.find_one({"follower_id": current_user.anonymous_username, "following_id": author.anonymous_username})
            if not is_follower and current_user.anonymous_username != author.anonymous_username:
                raise HTTPException(status_code=403, detail="Only people followed by the author can reply")

    sender = current_user.anonymous_username
    recipient = story.author_id

    if sender != recipient:
        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=body.text)
            await chat.insert()

        msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Replied to story: {body.text}",
            message_type="story_reply",
            attachment_url=story.media_url
        )
        await msg.insert()

        chat.last_message = f"Replied to story: {body.text[:40]}"
        chat.updated_at = datetime.utcnow()
        await chat.save()

        notif = Notification(
            user_id=recipient,
            type="story_reply",
            actor_ids=[sender],
            message=f"@{sender} replied to your story: {body.text[:50]}",
            metadata={"story_id": story_id, "chat_id": str(chat.id)}
        )
        await notif.insert()

    return {"success": True, "message": "Reply delivered to story owner's DM"}

@router.post("/{story_id}/share")
async def share_story(story_id: str, body: StoryShareRequest, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    author = await _ensure_story_access(story, current_user)
    if author and author.story_settings.get("allow_story_sharing") is False:
        raise HTTPException(status_code=403, detail="Story owner has disabled story sharing")

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

        chat = await Chat.find_one({"participants": {"$all": [sender, recipient], "$size": 2}})
        if not chat:
            chat = Chat(participants=[sender, recipient], last_message=f"Shared story by @{story.author_id}")
            await chat.insert()

        msg = Message(
            chat_id=str(chat.id),
            sender_id=sender,
            content=f"Shared a story by @{story.author_id}",
            message_type="story_reply",
            attachment_url=story.media_url
        )
        await msg.insert()

        chat.last_message = f"Shared story by @{story.author_id}"
        chat.updated_at = datetime.utcnow()
        await chat.save()
        sent_count += 1

    return {"success": True, "sent_to": sent_count}

@router.post("/{story_id}/view")
async def view_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if story and current_user.anonymous_username not in story.views:
        story.views.append(current_user.anonymous_username)
        await story.save()
    return {"message": "Viewed"}

@router.get("/{story_id}/viewers")
async def get_story_viewers(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")

    if story.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Only story owner can view viewers list")

    viewers = []
    for uname in story.views:
        u = await User.find_one({"anonymous_username": uname})
        photo = None
        if u:
            photo = u.profile_photo_url or u.avatar_url
            if photo and "dicebear.com" in photo:
                photo = None
        viewers.append({
            "username": uname,
            "display_name": u.display_name if u else uname,
            "profile_photo_url": photo,
            "has_liked": uname in story.likes
        })
    return viewers

@router.delete("/{story_id}")
async def delete_story(story_id: str, current_user: User = Depends(get_current_user)):
    story = await Story.get(story_id)
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if story.author_id != current_user.anonymous_username and not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Not authorized")

    from ..core.database import db
    bucket = AsyncIOMotorGridFSBucket(db)
    if story.media_url.startswith("/media/stories/"):
        file_id = story.media_url.split("/")[-1]
        if not ObjectId.is_valid(file_id):
            raise HTTPException(status_code=500, detail="Story media reference is invalid")
        try:
            await bucket.delete(ObjectId(file_id))
        except Exception:
            logger.error("Story media deletion failed.")
            raise HTTPException(status_code=503, detail="Story media could not be deleted")

    await story.delete()
    return {"message": "Story deleted"}
