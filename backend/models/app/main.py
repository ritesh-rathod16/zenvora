from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import logging
import asyncio
from dotenv import load_dotenv

from .core.database import init_db, close_db, health_check
from .routers import (
    auth, users, chats, posts, discovery, 
    voice_rooms, reports, media, admin, 
    icebreakers, social, stories, calls, ghost, swipe, reels,
    communities, ai, creator, livestream, monetization, connect, notifications, recommendation, notes
)
from .websocket.signaling import sio_app, sio, set_pairing
from .services.matchmaking import matchmaker
from .services.ghost_identity_service import ghost_service
from .services.disappearing_messages_worker import disappearing_worker
from .models.user import User
from .core.security import get_password_hash

load_dotenv()

from contextlib import asynccontextmanager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

from .core.config import validate_production_config

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Zenvora API: Initializing...")
    validate_production_config()
    try:
        await init_db() # MongoDB Atlas with Beanie ODM
        await seed_admin()

        # Start High-Concurrency Matchmaking Worker
        try:
            asyncio.create_task(matchmaker.run_adaptive_worker(sio, set_pairing))
            logger.info("Matchmaker worker initialized.")
        except Exception as me:
            logger.warning(f"Matchmaker worker startup issue: {me}")

        # Start Disappearing Messages Cleanup Worker
        try:
            disappearing_worker.start()
            logger.info("Disappearing messages worker initialized.")
        except Exception as de:
            logger.warning(f"Disappearing messages worker startup issue: {de}")

        logger.info("Zenvora API: Ready on MongoDB Atlas.")
    except Exception as e:
        logger.error(f"Critical Startup Failure: {e}", exc_info=True)

    yield

    logger.info("Zenvora API: Cleaning up...")
    disappearing_worker.stop()
    matchmaker.stop()
    await close_db()

from slowapi.errors import RateLimitExceeded
from .core.rate_limiter import limiter, rate_limit_exceeded_handler

app = FastAPI(title="Zenvora API", version="1.6.1", lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)

cors_origins_raw = os.getenv("CORS_ORIGINS", "*")
cors_origins = [o.strip() for o in cors_origins_raw.split(",")] if cors_origins_raw != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def seed_admin():
    """Ensure master admin exists with correct role."""
    admin_email = os.getenv("ADMIN_EMAIL", "zenvora@gmail.com")
    admin_pass = os.getenv("ADMIN_PASSWORD", "qwertyuiop")
    admin = await User.find_one({"email": admin_email})
    if not admin:
        new_admin = User(
            real_name="Master Admin",
            email=admin_email,
            anonymous_username="ZenvoraMaster",
            password_hash=get_password_hash(admin_pass),
            age=99,
            country="Global",
            role="super_admin",
            is_admin=True,
            is_active=True
        )
        await new_admin.insert()
        logger.info("Master admin user created.")
    else:
        # Sync password and role to match requirements exactly
        admin.password_hash = get_password_hash(admin_pass)
        admin.role = "super_admin"
        admin.is_admin = True
        await admin.save()
        logger.info("Admin role and password synchronized.")

@app.get("/")
async def root():
    return {"status": "online", "version": "1.6.1", "database": "MongoDB Atlas"}

@app.get("/health")
async def health():
    db_health = await health_check()
    return {
        "status": "healthy" if db_health.get("status") == "healthy" else "degraded",
        "database": db_health
    }

@app.get("/health/ready")
async def health_ready():
    db_health = await health_check()
    if db_health.get("status") == "healthy":
        return {"status": "ready", "database": "connected"}
    raise HTTPException(status_code=503, detail="Database connection degraded")

# Register Routers directly
app.include_router(auth, prefix="/auth", tags=["Auth"])
app.include_router(users, prefix="/users", tags=["Users"])
app.include_router(chats, prefix="/chats", tags=["Chats"])
app.include_router(posts, prefix="/posts", tags=["Posts"])
app.include_router(discovery, prefix="/discovery", tags=["Discovery"])
app.include_router(voice_rooms, prefix="/rooms", tags=["Rooms"])
app.include_router(reports, prefix="/reports", tags=["Reports"])
app.include_router(media, prefix="/media", tags=["Media"])
app.include_router(admin, prefix="/admin", tags=["Admin"])
app.include_router(social, prefix="/social", tags=["Social"])
app.include_router(stories, prefix="/stories", tags=["Stories"])
app.include_router(calls, prefix="/calls", tags=["Calls"])
app.include_router(swipe, prefix="/swipe", tags=["Swipe"])
app.include_router(reels, prefix="/reels", tags=["Reels"])
app.include_router(communities, prefix="/communities", tags=["Communities"])
app.include_router(ai, prefix="/ai", tags=["Zenvora AI"])
app.include_router(creator, prefix="/creator", tags=["Creator Dashboard"])
app.include_router(livestream, prefix="/livestream", tags=["Live Streaming"])
app.include_router(monetization, prefix="/monetization", tags=["Monetization & Gifts"])
app.include_router(connect, prefix="/connect", tags=["Zenvora Connect"])
app.include_router(notifications, prefix="/notifications", tags=["Notifications & Activity"])
app.include_router(recommendation, prefix="/recommendations", tags=["ZENVORA AI Recommendations"])
app.include_router(notes, prefix="/notes", tags=["Instagram Notes"])

app.mount("/socket.io", sio_app)
