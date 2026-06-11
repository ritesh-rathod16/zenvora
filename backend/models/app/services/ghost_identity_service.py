import random
from datetime import datetime, timedelta
from ..models.ghost import GhostIdentity
from ..models.user import User

class GhostIdentityService:
    PREFIXES = ["Silent", "Neon", "Shadow", "Lunar", "Nova", "Echo", "Mystic", "Swift", "Frost", "Neon"]
    SUFFIXES = ["Fox", "Drift", "Pixel", "Ghost", "Raven", "Owl", "Wolf", "Tiger", "Tiger", "Panda"]

    @classmethod
    def generate_alias(cls):
        return f"{random.choice(cls.PREFIXES)}{random.choice(cls.SUFFIXES)}{random.randint(100, 999)}"

    @classmethod
    def get_avatar_url(cls, alias: str):
        return f"https://api.dicebear.com/7.x/bottts/svg?seed={alias}"

    @classmethod
    async def get_or_regenerate_identity(cls, user_id: str, force: bool = False):
        now = datetime.utcnow()
        identity = await GhostIdentity.find_one({"user_id": user_id})

        if identity and not force and identity.expires_at > now:
            return identity

        new_alias = cls.generate_alias()
        new_avatar = cls.get_avatar_url(new_alias)
        expires_at = now + timedelta(minutes=30)

        if identity:
            identity.alias = new_alias
            identity.avatar_url = new_avatar
            identity.expires_at = expires_at
            await identity.save()
        else:
            identity = GhostIdentity(
                user_id=user_id,
                alias=new_alias,
                avatar_url=new_avatar,
                expires_at=expires_at
            )
            await identity.insert()
        
        return identity

    @classmethod
    async def cleanup_expired_identities(cls):
        now = datetime.utcnow()
        # In a real app, we might just let them stay and update on next request,
        # but for Omegle-style fresh starts, we can regenerate.
        expired = await GhostIdentity.find({"expires_at": {"$lt": now}}).to_list()
        for ident in expired:
            await cls.get_or_regenerate_identity(ident.user_id, force=True)

ghost_service = GhostIdentityService()
