import logging
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
import os
from ..models.user import User
from ..models.chat import Chat, Message
from ..models.post import Post
from ..models.voice_room import VoiceRoom
from ..models.report import Report
from ..models.admin import AdminLog, PlatformSettings
from ..models.notification import Notification
from ..models.social import Follow, FollowRequest
from ..models.story import Story
from ..models.call import CallSession
from ..models.ghost import GhostIdentity
from ..models.swipe import Swipe
from ..models.match import Match

db = None
logger = logging.getLogger(__name__)

async def init_db():
    global db
    client = AsyncIOMotorClient(os.getenv("MONGODB_URL"))
    db_name = os.getenv("DATABASE_NAME", "zenvora")
    db = client[db_name]
    
    # Registration of ALL platform models
    await init_beanie(
        database=db,
        document_models=[
            User, Chat, Message, Post, VoiceRoom, 
            Report, Notification, AdminLog, 
            PlatformSettings, Story, CallSession,
            GhostIdentity, Follow, FollowRequest,
            Swipe, Match
        ]
    )
    
    logger.info("MongoDB connected and all Beanie models initialized successfully.")
