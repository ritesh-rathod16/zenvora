import os
import sys
import asyncio
import logging
from dotenv import load_dotenv

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
load_dotenv()

from models.app.core.database import init_db, close_db
from models.app.models.user import User
from models.app.utils.auth import get_password_hash
from models.app.core.config import INSECURE_SECRETS

logger = logging.getLogger(__name__)

async def main():
    emails = [email.strip().lower() for email in os.getenv("RESET_USER_EMAILS", "").split(",") if email.strip()]
    new_password = os.getenv("RESET_USER_PASSWORD")
    if not emails or not new_password:
        raise RuntimeError("RESET_USER_EMAILS and RESET_USER_PASSWORD must be configured.")
    if len(new_password) < 12 or new_password in INSECURE_SECRETS:
        raise RuntimeError("RESET_USER_PASSWORD must be a non-default password of at least 12 characters.")

    await init_db()
    try:
        new_hash = get_password_hash(new_password)
        updated_count = 0
        for email in emails:
            user = await User.find_one({"email": email})
            if user:
                user.password_hash = new_hash
                user.token_version = getattr(user, "token_version", 0) + 1
                await user.save()
                updated_count += 1
        logger.info("Password reset completed for %s configured account(s).", updated_count)
    finally:
        await close_db()

if __name__ == "__main__":
    asyncio.run(main())
