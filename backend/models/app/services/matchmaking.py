import json
import logging
import asyncio
import asyncpg
from ..core.supabase import get_db_pool

logger = logging.getLogger(__name__)

class MatchmakingService:
    def __init__(self):
        self._stop_worker = False

    def stop(self):
        self._stop_worker = True
        logger.info("Matchmaking: Worker stop signal received.")

    async def add_to_queue(self, user_id: str, interests: list = None, region: str = "Global", trust_score: int = 100):
        """Adds a user to the match_queue using UPSERT."""
        pool = await get_db_pool()
        if not pool: return
        async with pool.acquire() as conn:
            try:
                await conn.execute('''
                    INSERT INTO match_queue (user_id, interests, region, trust_score, status, created_at)
                    VALUES ($1, $2, $3, $4, 'waiting', now())
                    ON CONFLICT (user_id) DO UPDATE 
                    SET interests = EXCLUDED.interests,
                        region = EXCLUDED.region,
                        trust_score = EXCLUDED.trust_score,
                        status = 'waiting',
                        created_at = now();
                ''', user_id, json.dumps(interests or []), region, trust_score)
            except Exception as e:
                logger.error(f"Matchmaking add error: {e}")

    async def remove_from_queue(self, user_id: str):
        """Removes a user from the queue."""
        pool = await get_db_pool()
        if not pool: return
        async with pool.acquire() as conn:
            try:
                await conn.execute('DELETE FROM match_queue WHERE user_id = $1', user_id)
            except Exception as e:
                logger.error(f"Matchmaking remove error: {e}")

    async def find_match(self, current_user_id: str):
        """Transactional matching logic."""
        pool = await get_db_pool()
        if not pool: return None
        async with pool.acquire() as conn:
            try:
                async with conn.transaction():
                    partner_id = await conn.fetchval('''
                        WITH candidate AS (
                            SELECT user_id FROM match_queue
                            WHERE status = 'waiting' AND user_id != $1
                            ORDER BY trust_score DESC, created_at ASC LIMIT 1
                            FOR UPDATE SKIP LOCKED
                        )
                        UPDATE match_queue SET status = 'matched'
                        WHERE user_id IN ($1, (SELECT user_id FROM candidate))
                        RETURNING user_id;
                    ''', current_user_id)

                    if partner_id:
                        res = await conn.fetchval("SELECT user_id FROM match_queue WHERE status = 'matched' AND user_id != $1 LIMIT 1", current_user_id)
                        return res
                return None
            except Exception as e:
                logger.error(f"Matchmaking search error: {e}")
                return None

    async def run_adaptive_worker(self, sio):
        """Resilient background worker with error recovery."""
        logger.info("Matchmaking adaptive worker started")
        while not self._stop_worker:
            try:
                pool = await get_db_pool()
                if pool is None:
                    # Wait longer if DB is unreachable
                    await asyncio.sleep(5)
                    continue

                async with pool.acquire() as conn:
                    q_size = await conn.fetchval("SELECT count(*) FROM match_queue WHERE status = 'waiting'")
                    
                    if q_size and q_size > 1:
                        waiting_users = await conn.fetch("SELECT user_id FROM match_queue WHERE status = 'waiting' LIMIT 10")
                        for user in waiting_users:
                            uid = user['user_id']
                            partner = await self.find_match(uid)
                            if partner:
                                await sio.emit('match_found', {'partner_id': partner, 'role': 'caller'}, room=uid)
                                await sio.emit('match_found', {'partner_id': uid, 'role': 'receiver'}, room=partner)

                    # Adaptive sleep logic
                    sleep_time = 2.0 if not q_size or q_size < 10 else 0.5
                    await asyncio.sleep(sleep_time)

            except (asyncpg.PostgresError, OSError) as e:
                logger.warning(f"Matchmaking Connection Issue: {e}. Retrying in 5s...")
                await asyncio.sleep(5)
            except Exception as e:
                logger.error(f"Matchmaking unexpected error: {e}")
                await asyncio.sleep(2)

matchmaker = MatchmakingService()
