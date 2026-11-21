from fastapi import APIRouter, HTTPException, Depends, Query, Request
from ..models.report import Report
from ..models.user import User
from ..core.security import get_current_user, get_current_admin
from ..core.rate_limiter import limiter
from typing import List, Optional

router = APIRouter()

@router.post("/")
@limiter.limit("10/hour")
async def create_report(
    request: Request,
    reported_id: str = Query(..., min_length=3, max_length=20),
    reason: str = Query(..., min_length=3, max_length=500),
    content_id: Optional[str] = Query(None, max_length=100),
    current_user: User = Depends(get_current_user),
):
    reported_id = reported_id.strip().lstrip("@")
    reason = reason.strip()
    if reported_id == current_user.anonymous_username:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    target_user = await User.find_one({"anonymous_username": reported_id})
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")

    duplicate = await Report.find_one({
        "reporter_id": current_user.anonymous_username,
        "reported_id": reported_id,
        "content_id": content_id,
        "status": "pending",
    })
    if duplicate:
        return {"message": "Report submitted successfully"}

    report = Report(
        reporter_id=current_user.anonymous_username,
        reported_id=reported_id,
        reason=reason,
        content_id=content_id
    )
    await report.insert()

    return {"message": "Report submitted successfully"}

@router.get("/admin/all", response_model=List[Report])
async def get_all_reports(current_user: User = Depends(get_current_admin)):
    return await Report.find_all().to_list()
