import os
import sys
import asyncio
from dotenv import load_dotenv

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
load_dotenv()

from models.app.core.database import init_db, close_db
from models.app.models.user import User

async def main():
    await init_db()
    users = await User.find_all().to_list()
    print(f"Total users in DB: {len(users)}")
    active_count = sum(1 for user in users if user.is_active)
    admin_count = sum(1 for user in users if user.is_admin or user.role in {"admin", "super_admin"})
    print(f"Active users: {active_count}; admin accounts: {admin_count}")
    await close_db()

if __name__ == "__main__":
    asyncio.run(main())
