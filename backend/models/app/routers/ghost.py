from fastapi import APIRouter, HTTPException, Depends
from ..models.user import User
from ..models.ghost import GhostIdentity
from ..core.security import get_current_user
from ..services.ghost_identity_service import ghost_service

router = APIRouter()

@router.get("/me")
async def get_my_ghost_identity(current_user: User = Depends(get_current_user)):
    """Returns the active ghost identity for the current user."""
    identity = await ghost_service.get_or_regenerate_identity(str(current_user.id))
    return {
        "alias": identity.alias,
        "avatar_url": identity.avatar_url,
        "expires_at": identity.expires_at,
        "level": current_user.ghost_mode_level
    }

@router.patch("/toggle")
async def update_ghost_mode(level: int, current_user: User = Depends(get_current_user)):
    """
    Updates the ghost mode level.
    0: Disabled, 1: Only in random chats, 2: Always On
    """
    if level not in [0, 1, 2]:
        raise HTTPException(status_code=400, detail="Invalid ghost mode level")
    
    current_user.ghost_mode_level = level
    await current_user.save()
    
    # Regenerate identity if moving from disabled to enabled
    if level > 0:
        await ghost_service.get_or_regenerate_identity(str(current_user.id), force=True)
        
    return {"message": "Ghost mode updated", "level": current_user.ghost_mode_level}
