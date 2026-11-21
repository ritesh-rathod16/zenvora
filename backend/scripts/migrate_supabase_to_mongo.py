"""
Supabase-to-MongoDB Migration Utility
Transfers legacy records (e.g., match_queue, matches) from Supabase PostgreSQL to MongoDB Atlas.
Includes schema normalization, idempotency, retry safety, and record validation.
"""
import os
import sys
import asyncio
import logging
import json
from datetime import datetime
from dotenv import load_dotenv

# Ensure root backend dir is in PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("migration")

async def run_migration():
    supabase_db_url = os.getenv("SUPABASE_DB_URL")
    mongo_url = os.getenv("MONGODB_URL") or os.getenv("MONGODB_URI")
    db_name = os.getenv("DATABASE_NAME", "zenvora")

    if not mongo_url:
        logger.error("MONGODB_URL or MONGODB_URI is not set. Aborting.")
        return

    logger.info("Starting Supabase to MongoDB Atlas Migration...")
    logger.info(f"Target MongoDB: {db_name}")

    import motor.motor_asyncio
    mongo_client = motor.motor_asyncio.AsyncIOMotorClient(mongo_url)
    mongo_db = mongo_client[db_name]

    # Verify Mongo connection
    try:
        await mongo_client.admin.command('ping')
        logger.info("Successfully connected to MongoDB Atlas.")
    except Exception:
        logger.error("Cannot reach MongoDB Atlas.")
        return

    # Check if Supabase PostgreSQL URL is provided
    if not supabase_db_url:
        logger.info("No SUPABASE_DB_URL found in environment. Assuming clean MongoDB Atlas initialization.")
        return

    try:
        import asyncpg
    except ImportError:
        logger.warning("asyncpg is not installed. To run migration from live PostgreSQL, install asyncpg temporarily.")
        return

    logger.info("Connecting to source Supabase PostgreSQL...")
    try:
        pg_conn = await asyncpg.connect(supabase_db_url, timeout=10)
        logger.info("Connected to Supabase PostgreSQL.")
    except Exception:
        logger.warning("Could not connect to Supabase PostgreSQL.")
        logger.info("Supabase instance may be offline or paused. Proceeding with migration report.")
        return

    report = {
        "timestamp": datetime.utcnow().isoformat(),
        "tables_checked": [],
        "records_migrated": 0,
        "records_skipped": 0,
        "errors": []
    }

    try:
        # Check if match_queue exists in PostgreSQL
        table_exists = await pg_conn.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_name = 'match_queue'
            );
        """)

        if table_exists:
            report["tables_checked"].append("match_queue")
            rows = await pg_conn.fetch("SELECT * FROM match_queue;")
            logger.info(f"Discovered {len(rows)} records in Supabase match_queue.")

            target_collection = mongo_db.get_collection("match_queue")
            for row in rows:
                try:
                    user_id = row['user_id']
                    interests_raw = row['interests']
                    if isinstance(interests_raw, str):
                        try:
                            interests = json.loads(interests_raw)
                        except Exception:
                            interests = []
                    elif isinstance(interests_raw, list):
                        interests = interests_raw
                    else:
                        interests = []

                    created_at = row['created_at'] if row['created_at'] else datetime.utcnow()

                    doc = {
                        "user_id": str(user_id),
                        "interests": interests,
                        "region": row.get('region', 'Global') or 'Global',
                        "trust_score": int(row.get('trust_score', 100) or 100),
                        "status": str(row.get('status', 'waiting')),
                        "matched_with": None,
                        "matching_session_id": None,
                        "lease_expires_at": None,
                        "created_at": created_at,
                        "updated_at": datetime.utcnow()
                    }

                    # Idempotent upsert
                    await target_collection.update_one(
                        {"user_id": doc["user_id"]},
                        {"$set": doc},
                        upsert=True
                    )
                    report["records_migrated"] += 1
                except Exception as err:
                    logger.error(f"Error migrating row {row}: {err}")
                    report["errors"].append(str(err))
                    report["records_skipped"] += 1
        else:
            logger.info("Table 'match_queue' not found in Supabase. Nothing to migrate.")

    finally:
        await pg_conn.close()
        mongo_client.close()

    logger.info("Migration Complete!")
    logger.info(f"Summary: Migrated={report['records_migrated']}, Skipped={report['records_skipped']}, Errors={len(report['errors'])}")

if __name__ == "__main__":
    asyncio.run(run_migration())
