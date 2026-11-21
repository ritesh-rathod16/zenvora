import os
import logging
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

load_dotenv()

ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()
MONGODB_URL = os.getenv("MONGODB_URL")
DATABASE_NAME = os.getenv("DATABASE_NAME", "zenvora")
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL")
ADMIN_EMAIL = ADMIN_EMAIL.strip().lower() if ADMIN_EMAIL else None
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

REDIS_URL = os.getenv("REDIS_URL")

INSECURE_SECRETS = {
    "your_super_secret_jwt_key_here",
    "change_this_master_admin_password_in_production",
    "qwertyuiop",
    "zenvora_secure_random_production_secret_key_2026_x9_enterprise_safe!",
    "zenvora_super_secret_key_2026_production",
    "secret",
    "password",
}

def validate_production_config():
    """Fail closed when required authentication secrets are absent or unsafe."""
    if not SECRET_KEY or SECRET_KEY in INSECURE_SECRETS or len(SECRET_KEY.encode("utf-8")) < 32:
        raise RuntimeError("SECRET_KEY must be configured with at least 32 bytes of random data.")

    if ENVIRONMENT == "production":
        logger.info("Validating production configuration environment...")

        if not MONGODB_URL:
            raise RuntimeError("MONGODB_URL is required in production.")

        if not ADMIN_EMAIL or not ADMIN_PASSWORD:
            raise RuntimeError("ADMIN_EMAIL and ADMIN_PASSWORD are required in production.")
        if ADMIN_PASSWORD in INSECURE_SECRETS or len(ADMIN_PASSWORD) < 12:
            raise RuntimeError("ADMIN_PASSWORD must be a non-default password of at least 12 characters.")

        if not LIVEKIT_URL or not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET:
            raise RuntimeError("LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET are required in production.")

        logger.info("Production configuration validation passed successfully.")
