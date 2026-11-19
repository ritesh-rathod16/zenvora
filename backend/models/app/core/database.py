import logging
import os
from typing import Optional
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from beanie import init_beanie
from dotenv import load_dotenv

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
from ..models.match_queue import MatchQueue
from ..models.comment import Comment
from ..models.reel import Reel
from ..models.livestream import LiveStream
from ..recommendation.models.interaction import InteractionEvent, UserInterestProfile

load_dotenv()
logger = logging.getLogger(__name__)

client: Optional[AsyncIOMotorClient] = None
db: Optional[AsyncIOMotorDatabase] = None

DOCUMENT_MODELS = [
    User, Chat, Message, Post, VoiceRoom,
    Report, Notification, AdminLog,
    PlatformSettings, Story, CallSession,
    GhostIdentity, Follow, FollowRequest,
    Swipe, Match, MatchQueue, Comment, Reel, LiveStream,
    InteractionEvent, UserInterestProfile
]

async def init_db() -> AsyncIOMotorDatabase:
    """Initializes MongoDB Atlas connection with pooling and Beanie ODM."""
    global client, db
    
    mongodb_uri = os.getenv("MONGODB_URL") or os.getenv("MONGODB_URI")
    if not mongodb_uri:
        raise ValueError("CRITICAL: MONGODB_URL or MONGODB_URI environment variable is not configured.")

    db_name = os.getenv("DATABASE_NAME", "zenvora")

    try:
        logger.info(f"Connecting to MongoDB Atlas (database: {db_name})...")
        client = AsyncIOMotorClient(
            mongodb_uri,
            minPoolSize=5,
            maxPoolSize=50,
            maxIdleTimeMS=45000,
            serverSelectionTimeoutMS=5000,
            connectTimeoutMS=10000,
            socketTimeoutMS=20000,
            retryWrites=True
        )

        db = client[db_name]

        # Verify connection immediately against application database
        await db.command('ping')
        logger.info(f"MongoDB Atlas connection to '{db_name}' successfully verified.")

        # Initialize all Beanie ODM document models
        await init_beanie(
            database=db,
            document_models=DOCUMENT_MODELS,
            allow_index_dropping=True
        )
        logger.info(f"Beanie ODM initialized with {len(DOCUMENT_MODELS)} document models.")

        return db
    except Exception as e:
        logger.error(f"Failed to connect to MongoDB Atlas: {e}", exc_info=True)
        raise

async def close_db():
    """Closes MongoDB connection pool gracefully."""
    global client, db
    if client:
        client.close()
        client = None
        db = None
        logger.info("MongoDB Atlas connection pool closed.")

async def health_check() -> dict:
    """Checks the health of the MongoDB Atlas connection."""
    global client, db
    if not client or db is None:
        return {"status": "unhealthy", "error": "Client not initialized"}
    try:
        await db.command('ping')
        return {"status": "healthy", "database": os.getenv("DATABASE_NAME", "zenvora")}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}

def get_database() -> Optional[AsyncIOMotorDatabase]:
    """Returns the current active database instance."""
    return db

def get_client() -> Optional[AsyncIOMotorClient]:
    """Returns the current active motor client instance."""
    return client
