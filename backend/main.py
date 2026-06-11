from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
import os
from dotenv import load_dotenv

from models.user import User
from models.chat import Chat, Message
from models.post import Post
from models.voice_room import VoiceRoom
from models.report import Report
from routers import auth, users, chats, posts, voice_rooms, discovery, reports, websockets
from utils.auth import get_password_hash

load_dotenv()

app = FastAPI(title="Zenvora API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def seed_admin():
    admin_email = os.getenv("ADMIN_EMAIL")
    admin_password = os.getenv("ADMIN_PASSWORD")
    if admin_email and admin_password:
        admin = await User.find_one(User.email == admin_email)
        if not admin:
            new_admin = User(
                real_name="Admin",
                email=admin_email,
                password_hash=get_password_hash(admin_password),
                age=99,
                country="Global",
                interests=["Moderation"],
                anonymous_username="Admin",
                is_active=True,
                is_admin=True,
                avatar_url="https://api.dicebear.com/7.x/bottts/svg?seed=Admin"
            )
            await new_admin.insert()
            print("Admin user seeded.")

@app.on_event("startup")
async def startup_db_client():
    client = AsyncIOMotorClient(os.getenv("MONGODB_URL"))
    await init_beanie(
        database=client[os.getenv("DATABASE_NAME")], 
        document_models=[User, Chat, Message, Post, VoiceRoom, Report]
    )
    await seed_admin()

@app.get("/")
async def root():
    return {"message": "Welcome to Zenvora API"}

app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/users", tags=["Users"])
app.include_router(chats.router, prefix="/chats", tags=["Chats"])
app.include_router(posts.router, prefix="/posts", tags=["Posts"])
app.include_router(voice_rooms.router, prefix="/rooms", tags=["Voice Rooms"])
app.include_router(discovery.router, prefix="/discovery", tags=["Discovery"])
app.include_router(reports.router, prefix="/reports", tags=["Reports"])
app.add_api_websocket_route("/ws/{token}", websockets.websocket_endpoint)
