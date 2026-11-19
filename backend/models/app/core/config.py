import os
import sys
import logging

logger = logging.getLogger(__name__)

ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()
MONGODB_URL = os.getenv("MONGODB_URL")
DATABASE_NAME = os.getenv("DATABASE_NAME", "zenvora")
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@zenvora.app")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

REDIS_URL = os.getenv("REDIS_URL")

INSECURE_SECRETS = {
    "your_super_secret_jwt_key_here",
    "change_this_master_admin_password_in_production",
    "qwertyuiop",
    "secret",
    "password"
}

def validate_production_config():
    """Verify that mandatory secrets are set and secure in production mode."""
    if ENVIRONMENT == "production":
        logger.info("Validating production configuration environment...")

        if not MONGODB_URL:
            logger.critical("FATAL: MONGODB_URL is missing in production configuration!")
            sys.exit(1)

        if not SECRET_KEY or SECRET_KEY in INSECURE_SECRETS:
            logger.critical("FATAL: Insecure or missing SECRET_KEY in production mode!")
            sys.exit(1)

        if not ADMIN_PASSWORD or ADMIN_PASSWORD in INSECURE_SECRETS:
            logger.critical("FATAL: Default or missing ADMIN_PASSWORD in production mode!")
            sys.exit(1)

        logger.info("Production configuration validation passed successfully.")
