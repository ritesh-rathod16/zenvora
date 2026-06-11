from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import logging
import asyncio
from dotenv import load_dotenv

from .core.database import init_db
from .core.supabase import init_supabase_db, close_db_pool
from .routers import (
    auth, users, chats, posts, discovery, 
    voice_rooms, reports, media, admin, 
    icebreakers, social, stories, calls, ghost, swipe
)
from .websocket.signaling import sio_app, sio
from .services.matchmaking import matchmaker
from .services.ghost_identity_service import ghost_service
from .models.user import User
from .core.security import get_password_hash

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Zenvora API", version="1.6.1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def seed_admin():
    """Ensure master admin exists with correct role."""
    admin_email = "zenvora@gmail.com"
    admin_pass = "qwertyuiop"
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

@app.on_event("startup")
async def startup_event():
    logger.info("Zenvora API: Initializing...")
    try:
        await init_db() # MongoDB
        await seed_admin()
        
        # Initialize Supabase but don't let it crash the server if internet is bad
        try:
            await init_supabase_db()
            asyncio.create_task(matchmaker.run_adaptive_worker(sio))
        except Exception as se:
            logger.warning(f"Matchmaking initialized with limited connectivity: {se}")
            
        logger.info("Zenvora API: Ready.")
    except Exception as e:
        logger.error(f"Critical Startup Failure: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Zenvora API: Cleaning up...")
    matchmaker.stop()
    await close_db_pool()

@app.get("/")
async def root():
    return {"status": "online", "version": "1.6.1"}

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

app.mount("/socket.io", sio_app)
