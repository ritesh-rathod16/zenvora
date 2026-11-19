import os
import sys
import asyncio
from dotenv import load_dotenv

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
load_dotenv()

from models.app.core.database import init_db, close_db
from models.app.models.user import User
from models.app.utils.auth import get_password_hash

async def main():
    await init_db()
    emails = [
        "riteshrathod016@gmail.com",
        "rathodritesh2580@gmail.com",
        "riteshrathodjee23@gmail.com",
        "zenvora@gmail.com"
    ]
    new_hash = get_password_hash("Password123!")

    for email in emails:
        user = await User.find_one({"email": email})
        if user:
            user.password_hash = new_hash
            user.is_active = True
            await user.save()
            print(f"Reset password for {email} to 'Password123!' (Active=True)")
        else:
            print(f"User {email} not found")

    await close_db()

if __name__ == "__main__":
    asyncio.run(main())
