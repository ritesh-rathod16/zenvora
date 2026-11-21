import re
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.database import get_database
from ..core.security import get_current_admin, get_current_user
from ..models.user import User
from ..models.vibe import DEFAULT_VIBES, UserVibe, Vibe
from ..services.matchmaking import matchmaker

router = APIRouter()
VIBE_TTL = timedelta(hours=2)
VIBE_ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def _minimum_age(vibe: Vibe) -> int:
    return max(vibe.minimum_age, 18 if vibe.vibe_id == "flirting" else 13)


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _vibe_dict(vibe: Vibe) -> dict:
    return {
        "id": vibe.vibe_id,
        "label": vibe.label,
        "emoji": vibe.emoji,
        "description": vibe.description,
        "compatible_vibes": vibe.compatible_vibes,
        "allow_fallback": vibe.allow_fallback,
        "fallback_group": vibe.fallback_group,
        "minimum_age": vibe.minimum_age,
    }


async def seed_default_vibes() -> None:
    """Insert initial categories without overwriting backend-managed settings."""
    db = get_database()
    if db is None:
        return
    now = datetime.now(timezone.utc)
    collection = db.get_collection("vibes")
    for definition in DEFAULT_VIBES:
        await collection.update_one(
            {"vibe_id": definition["vibe_id"]},
            {"$setOnInsert": {**definition, "is_active": True, "created_at": now, "updated_at": now}},
            upsert=True,
        )


class SetActiveVibeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    vibe_id: Optional[str] = Field(default=None, min_length=2, max_length=48)
    preferred_vibes: List[str] = Field(default_factory=list, max_length=12)

    @field_validator("preferred_vibes")
    @classmethod
    def validate_preferred_vibes(cls, values: List[str]) -> List[str]:
        normalized = [value.strip().lower() for value in values]
        if any(not VIBE_ID_PATTERN.fullmatch(value) for value in normalized):
            raise ValueError("Vibe preferences must use valid vibe IDs")
        if len(set(normalized)) != len(normalized):
            raise ValueError("Vibe preferences cannot contain duplicates")
        return normalized


class CreateVibeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    vibe_id: str = Field(..., min_length=2, max_length=48, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    label: str = Field(..., min_length=2, max_length=48)
    emoji: str = Field(default="✨", max_length=8)
    description: str = Field(default="", max_length=160)
    compatible_vibes: List[str] = Field(default_factory=list, max_length=20)
    allow_fallback: bool = True
    fallback_group: Optional[str] = Field(default="social", max_length=32)
    minimum_age: int = Field(default=13, ge=13, le=120)
    display_order: int = Field(default=0, ge=0, le=10000)

    @field_validator("compatible_vibes")
    @classmethod
    def validate_compatible_vibes(cls, values: List[str]) -> List[str]:
        if any(not VIBE_ID_PATTERN.fullmatch(value) for value in values):
            raise ValueError("Compatibility values must be valid vibe IDs")
        if len(set(values)) != len(values):
            raise ValueError("Compatibility values cannot contain duplicates")
        return values


class UpdateVibeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: Optional[str] = Field(default=None, min_length=2, max_length=48)
    emoji: Optional[str] = Field(default=None, max_length=8)
    description: Optional[str] = Field(default=None, max_length=160)
    compatible_vibes: Optional[List[str]] = Field(default=None, max_length=20)
    allow_fallback: Optional[bool] = None
    fallback_group: Optional[str] = Field(default=None, max_length=32)
    minimum_age: Optional[int] = Field(default=None, ge=13, le=120)
    display_order: Optional[int] = Field(default=None, ge=0, le=10000)
    is_active: Optional[bool] = None

    @field_validator("compatible_vibes")
    @classmethod
    def validate_compatible_vibes(cls, values: Optional[List[str]]) -> Optional[List[str]]:
        if values is None:
            return values
        if any(not VIBE_ID_PATTERN.fullmatch(value) for value in values):
            raise ValueError("Compatibility values must be valid vibe IDs")
        if len(set(values)) != len(values):
            raise ValueError("Compatibility values cannot contain duplicates")
        return values


@router.get("")
async def get_vibes(current_user: User = Depends(get_current_user)):
    """Return available categories and only the caller's own active vibe."""
    now = datetime.now(timezone.utc)
    catalog = await Vibe.find({"is_active": True}).sort("display_order").to_list()
    age = current_user.age or 0
    catalog = [v for v in catalog if age >= _minimum_age(v)]
    active = await UserVibe.find_one({"user_id": current_user.anonymous_username})
    active_data = None
    if active and _utc(active.expires_at) > now:
        active_data = {
            "vibe_id": active.vibe_id,
            "preferred_vibes": active.preferred_vibes,
            "expires_at": _utc(active.expires_at).isoformat(),
        }
    return {"vibes": [_vibe_dict(v) for v in catalog], "active_vibe": active_data}


@router.put("/me")
async def set_active_vibe(
    body: SetActiveVibeRequest,
    current_user: User = Depends(get_current_user),
):
    """Set or clear a private vibe that expires after two hours."""
    if not current_user.is_active or current_user.is_banned or current_user.shadow_banned:
        raise HTTPException(status_code=403, detail="This account cannot use vibe matching")

    user_id = current_user.anonymous_username
    if body.vibe_id is None:
        await UserVibe.find({"user_id": user_id}).delete()
        await matchmaker.cancel_vibe_queue_for_owner(user_id)
        return {"active_vibe": None}

    vibe_id = body.vibe_id.strip().lower()
    if not VIBE_ID_PATTERN.fullmatch(vibe_id):
        raise HTTPException(status_code=422, detail="Invalid vibe ID")
    vibe = await Vibe.find_one({"vibe_id": vibe_id, "is_active": True})
    if not vibe:
        raise HTTPException(status_code=404, detail="Vibe is unavailable")
    if current_user.age is None or current_user.age < _minimum_age(vibe):
        raise HTTPException(status_code=403, detail="This vibe is not available for this account")

    if body.preferred_vibes:
        preferences = await Vibe.find({
            "vibe_id": {"$in": body.preferred_vibes},
            "is_active": True,
        }).to_list()
        if len(preferences) != len(body.preferred_vibes):
            raise HTTPException(status_code=422, detail="One or more preferred vibes are unavailable")
        if any(current_user.age < _minimum_age(item) for item in preferences):
            raise HTTPException(status_code=403, detail="A preferred vibe is not available for this account")

    db = get_database()
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")
    now = datetime.now(timezone.utc)
    expires_at = now + VIBE_TTL
    await db.get_collection("user_vibes").update_one(
        {"user_id": user_id},
        {"$set": {
            "user_id": user_id,
            "vibe_id": vibe_id,
            "preferred_vibes": body.preferred_vibes,
            "expires_at": expires_at,
            "updated_at": now,
        }},
        upsert=True,
    )
    await matchmaker.cancel_vibe_queue_for_owner(user_id)
    return {
        "active_vibe": {
            "vibe_id": vibe_id,
            "preferred_vibes": body.preferred_vibes,
            "expires_at": expires_at.isoformat(),
        }
    }


@router.post("/catalog", status_code=201)
async def create_vibe(
    body: CreateVibeRequest,
    _: User = Depends(get_current_admin),
):
    existing = await Vibe.find_one({"vibe_id": body.vibe_id})
    if existing:
        raise HTTPException(status_code=409, detail="Vibe ID already exists")
    known_ids = {v.vibe_id for v in await Vibe.find({"is_active": True}).to_list()}
    if any(item not in known_ids for item in body.compatible_vibes):
        raise HTTPException(status_code=422, detail="Compatibility references must exist in the catalog")
    now = datetime.now(timezone.utc)
    vibe = Vibe(**body.model_dump(), is_active=True, created_at=now, updated_at=now)
    await vibe.insert()
    return _vibe_dict(vibe)


@router.patch("/catalog/{vibe_id}")
async def update_vibe(
    vibe_id: str,
    body: UpdateVibeRequest,
    _: User = Depends(get_current_admin),
):
    vibe = await Vibe.find_one({"vibe_id": vibe_id})
    if not vibe:
        raise HTTPException(status_code=404, detail="Vibe not found")
    updates = {
        key: value
        for key, value in body.model_dump(exclude_unset=True).items()
        if value is not None
    }
    if "compatible_vibes" in updates:
        known_ids = {v.vibe_id for v in await Vibe.find({"is_active": True}).to_list()}
        if any(item not in known_ids for item in updates["compatible_vibes"]):
            raise HTTPException(status_code=422, detail="Compatibility references must exist in the catalog")
    for key, value in updates.items():
        setattr(vibe, key, value)
    vibe.updated_at = datetime.now(timezone.utc)
    await vibe.save()
    return _vibe_dict(vibe) | {"is_active": vibe.is_active}
