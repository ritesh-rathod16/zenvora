"""
Database Seeding Script for Zenvora on MongoDB Atlas.
Creates:
- Platform Settings (features enabled)
- Diverse active community profiles (10+ users)
- Ephemeral community text & image posts with likes
- Live Voice Rooms
- Community Stories with high-res photos
"""
import os
import sys
import asyncio
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("seed_data")

from models.app.core.database import init_db, close_db
from models.app.models.user import User
from models.app.models.post import Post
from models.app.models.voice_room import VoiceRoom
from models.app.models.story import Story
from models.app.models.reel import Reel
from models.app.models.admin import PlatformSettings
from models.app.utils.auth import get_password_hash

SEED_PASSWORD = "Password123!"
DEFAULT_HASH = get_password_hash(SEED_PASSWORD)

USERS_DATA = [
    {
        "real_name": "Master Admin",
        "email": "zenvora@gmail.com",
        "anonymous_username": "ZenvoraMaster",
        "password_hash": get_password_hash("qwertyuiop"),
        "age": 99,
        "country": "Global",
        "gender": "male",
        "interests": ["Moderation", "Security", "Community"],
        "bio": "Official Guardian of Zenvora. Ensuring safe, anonymous digital connections.",
        "avatar_url": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=500&q=80",
        "current_mood": "neutral",
        "trust_score": 100,
        "role": "super_admin",
        "is_admin": True,
        "is_active": True,
        "personality_type": "The Architect"
    },
    {
        "real_name": "Elena Rostova",
        "email": "luna@zenvora.com",
        "anonymous_username": "LunaEcho",
        "password_hash": DEFAULT_HASH,
        "age": 22,
        "country": "Japan",
        "gender": "female",
        "interests": ["Art", "Music", "Cyberpunk", "Anime", "Lo-Fi"],
        "bio": "Late night coder & ambient sound designer. Staring into the neon glow. 🌙",
        "avatar_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=500&q=80",
        "current_mood": "chaotic",
        "voice_aura": "Cyber Purple",
        "social_battery": 85,
        "trust_score": 98,
        "role": "user",
        "is_active": True,
        "personality_type": "The Dreamer"
    },
    {
        "real_name": "Kai Chen",
        "email": "cipher@zenvora.com",
        "anonymous_username": "CyberShadow",
        "password_hash": DEFAULT_HASH,
        "age": 26,
        "country": "Germany",
        "gender": "male",
        "interests": ["Coding", "AI", "Gaming", "Philosophy", "Tech"],
        "bio": "Building zero-knowledge dreams in an over-connected world. ⚡",
        "avatar_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=500&q=80",
        "current_mood": "neutral",
        "voice_aura": "Ghost Blue",
        "social_battery": 90,
        "trust_score": 96,
        "role": "user",
        "is_active": True,
        "personality_type": "The Mastermind"
    },
    {
        "real_name": "Astrid Lindgren",
        "email": "aurora@zenvora.com",
        "anonymous_username": "AuroraBorealis",
        "password_hash": DEFAULT_HASH,
        "age": 23,
        "country": "Norway",
        "gender": "female",
        "interests": ["Astronomy", "Music", "Travel", "Photography", "Deep Talks"],
        "bio": "Stargazer and night owl. Tell me what keeps you awake at night. ✨",
        "avatar_url": "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=500&q=80",
        "current_mood": "sleepy",
        "voice_aura": "Dreamcore",
        "social_battery": 95,
        "trust_score": 99,
        "role": "user",
        "is_active": True,
        "personality_type": "The Mystic"
    },
    {
        "real_name": "Marcus Vance",
        "email": "pixel@zenvora.com",
        "anonymous_username": "PixelKnight",
        "password_hash": DEFAULT_HASH,
        "age": 25,
        "country": "Canada",
        "gender": "male",
        "interests": ["Retro Games", "Design", "Anime", "Coffee", "Pixel Art"],
        "bio": "16-bit heart living in a 4K world. Always down for late night gaming trivia. 🎮",
        "avatar_url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=500&q=80",
        "current_mood": "anxious",
        "voice_aura": "Neon Lime",
        "social_battery": 80,
        "trust_score": 93,
        "role": "user",
        "is_active": True,
        "personality_type": "The Adventurer"
    },
    {
        "real_name": "Maya Lin",
        "email": "velvet@zenvora.com",
        "anonymous_username": "VelvetVibe",
        "password_hash": DEFAULT_HASH,
        "age": 21,
        "country": "US",
        "gender": "female",
        "interests": ["Music", "Vinyl", "Fashion", "Art", "Coffee"],
        "bio": "Creative director & vinyl collector 🎧 Analog warmth in digital space.",
        "avatar_url": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=500&q=80",
        "current_mood": "peaceful",
        "voice_aura": "Warm Amber",
        "social_battery": 88,
        "trust_score": 97,
        "role": "user",
        "is_active": True,
        "personality_type": "The Creator"
    },
    {
        "real_name": "Kenji Sato",
        "email": "samurai@zenvora.com",
        "anonymous_username": "CyberSamurai",
        "password_hash": DEFAULT_HASH,
        "age": 24,
        "country": "Japan",
        "gender": "male",
        "interests": ["Unreal Engine", "Photography", "Cyberpunk", "Tokyo", "Gaming"],
        "bio": "Unreal Engine dev & Tokyo night photography 🗼 Rain on asphalt vibes.",
        "avatar_url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=500&q=80",
        "current_mood": "energetic",
        "voice_aura": "Electric Indigo",
        "social_battery": 91,
        "trust_score": 95,
        "role": "user",
        "is_active": True,
        "personality_type": "The Pioneer"
    },
    {
        "real_name": "Zane Miller",
        "email": "astro@zenvora.com",
        "anonymous_username": "AstroNaut",
        "password_hash": DEFAULT_HASH,
        "age": 22,
        "country": "UK",
        "gender": "male",
        "interests": ["Synthesizer", "Lo-Fi", "Game Dev", "Sci-Fi", "Music"],
        "bio": "Synthesizer jams & indie game composer 🎹 Turning feelings into frequencies.",
        "avatar_url": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=500&q=80",
        "current_mood": "neutral",
        "voice_aura": "Cosmic Violet",
        "social_battery": 82,
        "trust_score": 94,
        "role": "user",
        "is_active": True,
        "personality_type": "The Artist"
    },
    {
        "real_name": "Chloe Dubois",
        "email": "zenith@zenvora.com",
        "anonymous_username": "ZenithGlow",
        "password_hash": DEFAULT_HASH,
        "age": 23,
        "country": "France",
        "gender": "female",
        "interests": ["Architecture", "Coffee", "Books", "Minimalism", "Travel"],
        "bio": "Minimalist interior architecture & coffee enthusiast ☕ Paris after midnight.",
        "avatar_url": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=500&q=80",
        "profile_photo_url": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=500&q=80",
        "current_mood": "peaceful",
        "voice_aura": "Golden Glow",
        "social_battery": 94,
        "trust_score": 98,
        "role": "user",
        "is_active": True,
        "personality_type": "The Visionary"
    }
]

POSTS_DATA = [
    {
        "author_id": "CyberSamurai",
        "content": "Tokyo rainfall at 2 AM hit different tonight. Neon reflection off the asphalt looks straight out of a cyber film. 🌧️✨",
        "media_url": "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=800&q=80",
        "likes": ["LunaEcho", "VelvetVibe", "AstroNaut", "ZenithGlow"],
        "replies_count": 8
    },
    {
        "author_id": "VelvetVibe",
        "content": "Late night record spinning session. Nothing beats analog warmth when you're deep working on new design concepts. 🎧🎶",
        "media_url": "https://images.unsplash.com/photo-1539185441755-769473a23570?auto=format&fit=crop&w=800&q=80",
        "likes": ["CyberSamurai", "ZenithGlow", "AstroNaut"],
        "replies_count": 6
    },
    {
        "author_id": "AstroNaut",
        "content": "Synthesizer setup finally complete! Modular synthesis is a total rabbit hole for free time and I love every second of it. 🎹🎛️",
        "media_url": "https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=800&q=80",
        "likes": ["LunaEcho", "CyberShadow", "PixelKnight"],
        "replies_count": 11
    },
    {
        "author_id": "ZenithGlow",
        "content": "A quiet corner in Paris after midnight. Fresh coffee, soft rain, and endless stream of consciousness thoughts. ☕💭",
        "media_url": "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=800&q=80",
        "likes": ["VelvetVibe", "AuroraBorealis", "SolarNomad"],
        "replies_count": 5
    },
    {
        "author_id": "LunaEcho",
        "content": "Working on a new ambient lo-fi track. Here is the workstation view tonight. Stay creative, wanderers! 🌙💻",
        "media_url": "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=800&q=80",
        "likes": ["CyberSamurai", "VelvetVibe", "AstroNaut"],
        "replies_count": 9
    },
    {
        "author_id": "PixelKnight",
        "content": "Arcade cabinet restoration project is 90% complete! CRT scanlines are unbeatable for retro nostalgia. 🕹️🔥",
        "media_url": "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=800&q=80",
        "likes": ["CyberShadow", "AstroNaut", "CyberSamurai"],
        "replies_count": 14
    },
    {
        "author_id": "AuroraBorealis",
        "content": "Looked up at the night sky today. We're all just tiny specks looking for authentic connection in an endless universe. What is keeping you awake tonight? ✨",
        "media_url": None,
        "likes": ["SolarNomad", "LunaEcho", "PixelKnight", "CyberShadow"],
        "replies_count": 12
    }
]

VOICE_ROOMS_DATA = [
    {
        "title": "🌙 Late Night Lo-Fi & Deep Talks",
        "description": "Chill beats, open mics, and casual 3 AM conversations. No judgment, just vibes.",
        "category": "Music",
        "creator_id": "LunaEcho",
        "listener_count": 18,
        "peak_listeners": 35,
        "recording_enabled": False,
        "is_private": False,
        "is_featured": True,
        "tags": ["lofi", "chill", "deep-talks", "night"],
        "energy_score": 92.5,
        "is_active": True
    },
    {
        "title": "⚡ Cyberpunk & Game Dev Lounge",
        "description": "Unreal Engine, 3D art, shaders, and synthwave music breakdown.",
        "category": "Gaming",
        "creator_id": "CyberSamurai",
        "listener_count": 12,
        "peak_listeners": 24,
        "recording_enabled": False,
        "is_private": False,
        "is_featured": True,
        "tags": ["gamedev", "cyberpunk", "unreal", "design"],
        "energy_score": 95.0,
        "is_active": True
    },
    {
        "title": "🌌 Stargazing & Existential Philosophy",
        "description": "Discuss the cosmos, consciousness, and the mysteries of existence.",
        "category": "Philosophy",
        "creator_id": "AuroraBorealis",
        "listener_count": 14,
        "peak_listeners": 29,
        "recording_enabled": False,
        "is_private": False,
        "is_featured": False,
        "tags": ["space", "philosophy", "cosmos"],
        "energy_score": 84.0,
        "is_active": True
    }
]

STORIES_DATA = [
    {
        "author_id": "CyberSamurai",
        "media_url": "https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&w=600&q=80"
    },
    {
        "author_id": "LunaEcho",
        "media_url": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80"
    },
    {
        "author_id": "VelvetVibe",
        "media_url": "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=600&q=80"
    },
    {
        "author_id": "AstroNaut",
        "media_url": "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=600&q=80"
    },
    {
        "author_id": "ZenithGlow",
        "media_url": "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=600&q=80"
    }
]

REELS_DATA = [
    {
        "author_id": "CyberSamurai",
        "video_url": "https://www.w3schools.com/html/mov_bbb.mp4",
        "caption": "Tokyo neon nights and cyber aesthetic vibes. 🗼✨ #Tokyo #Cyberpunk",
        "likes": ["LunaEcho", "VelvetVibe", "AstroNaut"]
    },
    {
        "author_id": "LunaEcho",
        "video_url": "https://www.w3schools.com/html/movie.mp4",
        "caption": "Late night lo-fi sound design session in progress. 🎧🌙 #LoFi #Music",
        "likes": ["CyberSamurai", "ZenithGlow"]
    },
    {
        "author_id": "PixelKnight",
        "video_url": "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
        "caption": "Retro arcade gaming marathon! 16-bit nostalgia hits hard. 🎮🔥 #Retro #Gaming",
        "likes": ["CyberShadow", "AstroNaut", "VelvetVibe"]
    }
]

async def seed():
    logger.info("Connecting to MongoDB Atlas to seed data...")
    await init_db()

    # 1. Platform Settings
    settings = await PlatformSettings.find_one()
    if not settings:
        settings = PlatformSettings(
            registrations_enabled=True,
            posting_enabled=True,
            video_chat_enabled=True,
            image_uploads_enabled=True,
            maintenance_mode=False
        )
        await settings.insert()
        logger.info("PlatformSettings initialized.")
    else:
        settings.registrations_enabled = True
        settings.posting_enabled = True
        settings.video_chat_enabled = True
        settings.image_uploads_enabled = True
        settings.maintenance_mode = False
        await settings.save()

    # 2. Seed Users
    logger.info(f"Seeding {len(USERS_DATA)} community users...")
    for u_data in USERS_DATA:
        if "full_name" not in u_data:
            u_data["full_name"] = u_data.get("real_name", "Zenvora User")
        if "normalized_username" not in u_data:
            u_data["normalized_username"] = u_data["anonymous_username"].lower()

        existing = await User.find_one({"email": u_data["email"]})
        if not existing:
            user = User(**u_data)
            await user.insert()
            logger.info(f"  + User created: {user.anonymous_username} ({user.email})")
        else:
            for key, val in u_data.items():
                setattr(existing, key, val)
            if not existing.full_name:
                existing.full_name = u_data["full_name"]
            if not existing.normalized_username:
                existing.normalized_username = u_data["normalized_username"]
            await existing.save()
            logger.info(f"  ~ User updated: {existing.anonymous_username} ({existing.email})")

    # 3. Seed Posts
    logger.info(f"Seeding {len(POSTS_DATA)} community posts...")
    await Post.find({"author_id": {"$in": [u["anonymous_username"] for u in USERS_DATA]}}).delete()

    now = datetime.utcnow()
    for p_data in POSTS_DATA:
        post = Post(
            author_id=p_data["author_id"],
            content=p_data["content"],
            media_url=p_data.get("media_url"),
            likes=p_data["likes"],
            replies_count=p_data["replies_count"],
            expires_at=now + timedelta(days=365),
            created_at=now - timedelta(minutes=30)
        )
        await post.insert()
        logger.info(f"  + Post created by {post.author_id} (media={bool(post.media_url)})")

    # 4. Seed Voice Rooms
    logger.info(f"Seeding {len(VOICE_ROOMS_DATA)} live voice rooms...")
    await VoiceRoom.find({"creator_id": {"$in": [u["anonymous_username"] for u in USERS_DATA]}}).delete()

    for r_data in VOICE_ROOMS_DATA:
        room = VoiceRoom(**r_data)
        await room.insert()
        logger.info(f"  + Voice Room created: '{room.title}' in [{room.category}]")

    # 5. Seed Stories
    logger.info("Seeding community stories...")
    await Story.find({"author_id": {"$in": [u["anonymous_username"] for u in USERS_DATA]}}).delete()

    for s in STORIES_DATA:
        story = Story(
            author_id=s["author_id"],
            media_url=s["media_url"],
            views=[{"username": "CyberShadow"}, {"username": "SolarNomad"}, {"username": "PixelKnight"}],
            created_at=now,
            expires_at=now + timedelta(days=365)
        )
        await story.insert()
        logger.info(f"  + Story created by {story.author_id}")

    # 6. Seed Reels
    logger.info("Seeding community reels...")
    await Reel.find({"author_id": {"$in": [u["anonymous_username"] for u in USERS_DATA]}}).delete()

    for r in REELS_DATA:
        reel = Reel(
            author_id=r["author_id"],
            video_url=r["video_url"],
            caption=r["caption"],
            likes=r["likes"],
            created_at=now
        )
        await reel.insert()
        logger.info(f"  + Reel created by {reel.author_id}")

    # 7. Seed Notifications
    logger.info("Seeding historical notifications for all users...")
    from models.app.models.notification import Notification
    await Notification.find().delete()

    usernames = [u["anonymous_username"] for u in USERS_DATA]
    for uname in usernames:
        notifs_to_seed = [
            Notification(
                recipient_id=uname,
                actor_id="CyberSamurai",
                type="follow",
                category="social",
                title="New Follower",
                message="@CyberSamurai started following you.",
                read=False,
                created_at=now - timedelta(hours=2)
            ),
            Notification(
                recipient_id=uname,
                actor_id="LunaEcho",
                type="like",
                category="social",
                title="Post Like",
                message="@LunaEcho liked your post.",
                read=True,
                created_at=now - timedelta(hours=5)
            ),
            Notification(
                recipient_id=uname,
                actor_id="PixelKnight",
                type="story_reply",
                category="mentions",
                title="Story Reply",
                message="@PixelKnight replied to your story: 'Awesome vibes!'",
                read=False,
                created_at=now - timedelta(minutes=45)
            ),
            Notification(
                recipient_id=uname,
                actor_id="ZenithGlow",
                type="follow_request",
                category="social",
                title="Follow Request",
                message="@ZenithGlow requested to follow you.",
                read=False,
                created_at=now - timedelta(minutes=10)
            )
        ]
        for n in notifs_to_seed:
            await n.insert()
    logger.info("  + Seeded historical notifications for all users.")

    logger.info("ALL SEED DATA SUCCESSFULLY INSERTED AND VERIFIED!")
    await close_db()

if __name__ == "__main__":
    asyncio.run(seed())
