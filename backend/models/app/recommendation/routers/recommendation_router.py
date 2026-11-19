from fastapi import APIRouter, HTTPException, Depends, Query
from ...models.user import User
from ...core.security import get_current_user
from ..services.interest_service import InterestService
from ..services.candidate_generator import CandidateGenerator
from ..services.ranking import RankingEngine
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

router = APIRouter()

class EventIngestionRequest(BaseModel):
    content_id: str
    content_type: str = Field(..., description="post, reel, story, room, user, query")
    event_type: str = Field(..., description="impression, view, like, comment, save, share, watch_start, watch_complete, skip, hide, not_interested")
    watch_duration: float = 0.0
    content_duration: float = 0.0
    category: Optional[str] = None
    author_id: Optional[str] = None
    recommendation_source: Optional[str] = "feed"

@router.get("/feed")
async def get_recommended_feed(
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user)
):
    profile = await InterestService.get_or_create_profile(current_user)
    candidates = await CandidateGenerator.get_feed_candidates(current_user, limit=limit * 2)
    ranked = RankingEngine.rank_posts(candidates, current_user, profile)

    result = []
    for p in ranked[:limit]:
        result.append({
            "id": str(p.id),
            "author_id": p.author_id,
            "content": p.content,
            "media_url": p.media_url,
            "likes_count": len(p.likes),
            "replies_count": p.replies_count,
            "created_at": p.created_at.isoformat(),
            "recommendation_source": "ai_hybrid_feed"
        })
    return result

@router.get("/reels")
async def get_recommended_reels(
    limit: int = Query(20, ge=1, le=50),
    current_user: User = Depends(get_current_user)
):
    profile = await InterestService.get_or_create_profile(current_user)
    candidates = await CandidateGenerator.get_reels_candidates(current_user, limit=limit * 2)
    ranked = RankingEngine.rank_reels(candidates, current_user, profile)

    result = []
    for r in ranked[:limit]:
        result.append({
            "id": str(r.id),
            "author_id": r.author_id,
            "video_url": r.video_url,
            "caption": r.caption,
            "likes_count": len(r.likes),
            "reposts_count": len(r.reposts),
            "recommendation_source": "ai_reels_engine"
        })
    return result

@router.get("/people")
async def get_suggested_people(
    limit: int = Query(10, ge=1, le=30),
    current_user: User = Depends(get_current_user)
):
    candidates = await CandidateGenerator.get_people_candidates(current_user, limit=limit)
    result = []
    for u in candidates:
        photo = u.profile_photo_url or u.avatar_url
        if photo and "dicebear.com" in photo:
            photo = None
        result.append({
            "username": u.anonymous_username,
            "full_name": u.full_name,
            "avatar_url": photo,
            "trust_score": u.trust_score,
            "country": u.country or "Global",
            "recommendation_source": "social_graph_ai"
        })
    return result

@router.post("/events")
async def ingest_event(body: EventIngestionRequest, current_user: User = Depends(get_current_user)):
    event = await InterestService.record_interaction(
        user=current_user,
        content_id=body.content_id,
        content_type=body.content_type,
        event_type=body.event_type,
        watch_duration=body.watch_duration,
        content_duration=body.content_duration,
        category=body.category,
        author_id=body.author_id,
        recommendation_source=body.recommendation_source
    )
    return {"success": True, "event_id": str(event.id)}

@router.post("/reset")
async def reset_recommendations(current_user: User = Depends(get_current_user)):
    profile = await InterestService.reset_user_interests(current_user)
    return {"success": True, "message": "ZENVORA AI Personalization reset successfully!", "profile": profile.dict()}

@router.get("/health")
async def recommendation_health():
    return {
        "status": "healthy",
        "engine": "ZENVORA AI Hybrid Recommendation Pipeline",
        "version": "v1.2-production",
        "features": ["collaborative_filtering", "content_similarity", "diversity_reranking", "event_ingestion"]
    }
