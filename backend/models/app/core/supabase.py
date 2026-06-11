import os
import asyncpg
import logging
import asyncio
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

# Core Environment Variables
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
SUPABASE_DB_URL = os.getenv("SUPABASE_DB_URL")

# Supabase Client for general operations
supabase: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)

# Global connection pool
_db_pool = None

async def get_db_pool():
    global _db_pool
    if _db_pool is None:
        try:
            # Added timeout and validation to prevent getaddrinfo hangs
            _db_pool = await asyncpg.create_pool(
                dsn=SUPABASE_DB_URL,
                min_size=1,
                max_size=10,
                command_timeout=30,
                timeout=10
            )
            logger.info("Supabase: Connection established via IPv4/DNS.")
        except Exception as e:
            logger.error(f"Supabase Connection Error: {e}")
            return None
    return _db_pool

async def init_supabase_db():
    """Initializes the database only if connection is available."""
    pool = await get_db_pool()
    if pool is None:
        logger.warning("Supabase: Infrastructure offline. Matchmaking disabled.")
        return

    async with pool.acquire() as conn:
        try:
            await conn.execute('''
                CREATE TABLE IF NOT EXISTS match_queue (
                    user_id TEXT PRIMARY KEY,
                    interests JSONB DEFAULT '[]'::jsonb,
                    region TEXT DEFAULT 'Global',
                    trust_score INT DEFAULT 100,
                    status TEXT DEFAULT 'waiting',
                    created_at TIMESTAMP DEFAULT now()
                );
            ''')
            await conn.execute('CREATE INDEX IF NOT EXISTS idx_match_queue_status ON match_queue(status);')
            logger.info("Supabase: Matchmaking schema ready.")
        except Exception as e:
            logger.error(f"Supabase Schema Error: {e}")

async def close_db_pool():
    global _db_pool
    if _db_pool:
        await _db_pool.close()
        logger.info("Supabase: Pool closed.")
