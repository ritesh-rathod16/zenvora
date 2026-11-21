import logging
import os
import asyncio
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
from ..models.vibe import Vibe, UserVibe
from ..models.comment import Comment
from ..models.reel import Reel
from ..models.livestream import LiveStream
from ..models.note import UserNote
from ..models.highlight import StoryHighlight
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
    UserNote, StoryHighlight, InteractionEvent, UserInterestProfile, Vibe, UserVibe
]

async def init_db() -> AsyncIOMotorDatabase:
    """Initializes MongoDB Atlas connection with retry backoff, pooling, and Beanie ODM."""
    global client, db

    if client is not None and db is not None:
        try:
            await db.command('ping')
            return db
        except Exception:
            logger.warning("Existing MongoDB client ping failed. Re-initializing connection pool...")

    mongodb_uri = os.getenv("MONGODB_URL") or os.getenv("MONGODB_URI")
    if not mongodb_uri:
        raise ValueError("CRITICAL: MONGODB_URL or MONGODB_URI environment variable is not configured.")

    db_name = os.getenv("DATABASE_NAME", "zenvora")
    max_retries = 3
    retry_delay = 2.0

    for attempt in range(1, max_retries + 1):
        try:
            logger.info(f"Connecting to MongoDB Atlas (attempt {attempt}/{max_retries}, database: {db_name})...")
            client = AsyncIOMotorClient(
                mongodb_uri,
                minPoolSize=5,
                maxPoolSize=50,
                maxIdleTimeMS=45000,
                serverSelectionTimeoutMS=15000,
                connectTimeoutMS=20000,
                socketTimeoutMS=30000,
                retryWrites=True,
                retryReads=True
            )

            db = client[db_name]

            # Verify connection with ping
            await db.command('ping')
            logger.info(f"MongoDB Atlas connection to '{db_name}' successfully verified.")

            # Initialize Beanie ODM document models
            await init_beanie(
                database=db,
                document_models=DOCUMENT_MODELS,
                allow_index_dropping=True
            )
            logger.info(f"Beanie ODM initialized with {len(DOCUMENT_MODELS)} document models.")

            return db
        except Exception as e:
            logger.error(f"MongoDB connection attempt {attempt} failed.")
            if attempt == max_retries:
                raise
            await asyncio.sleep(retry_delay)
            retry_delay *= 2.0

    return db

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
    except Exception:
        return {"status": "unhealthy", "error": "Database unavailable"}

def get_database() -> Optional[AsyncIOMotorDatabase]:
    """Returns the current active database instance."""
    return db

def get_client() -> Optional[AsyncIOMotorClient]:
    """Returns the current active motor client instance."""
    return client
