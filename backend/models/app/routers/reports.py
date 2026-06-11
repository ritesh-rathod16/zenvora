from fastapi import APIRouter, HTTPException, Depends
from ..models.report import Report
from ..models.user import User
from ..core.security import get_current_user
from typing import List

router = APIRouter()

@router.post("/")
async def create_report(reported_id: str, reason: str, content_id: str = None, current_user: User = Depends(get_current_user)):
    target_user = await User.find_one({"anonymous_username": reported_id})
    if not target_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    report = Report(
        reporter_id=current_user.anonymous_username,
        reported_id=reported_id,
        reason=reason,
        content_id=content_id
    )
    await report.insert()
    
    # Simple trust score impact
    target_user.trust_score -= 5
    if target_user.trust_score < 0:
        target_user.trust_score = 0
    await target_user.save()
    
    return {"message": "Report submitted successfully"}

@router.get("/admin/all", response_model=List[Report])
async def get_all_reports(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin only")
    return await Report.find_all().to_list()
