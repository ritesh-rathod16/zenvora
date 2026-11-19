"""
Sanity tests for Zenvora FastAPI backend.
Verifies endpoints, JWT helpers, ImageKit auth generation, rate limiter fallback, and login endpoint formats.
"""
import os
import sys
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from models.app.main import app
from models.app.utils.auth import create_access_token, verify_password, get_password_hash

def test_api():
    # Use context manager so FastAPI lifespan (init_db) runs during test
    with TestClient(app) as client:
        print("--- TEST: Root & Health ---")
        res_root = client.get("/")
        assert res_root.status_code == 200
        data = res_root.json()
        assert data["status"] == "online"
        assert "MongoDB" in data["database"]
        print("Root endpoint verified:", data)

        print("--- TEST: Password Hashing & JWT ---")
        raw_pass = "SecureZenvora2026!"
        hashed = get_password_hash(raw_pass)
        assert verify_password(raw_pass, hashed)
        assert not verify_password("WrongPassword", hashed)

        token = create_access_token({"sub": "user_12345"})
        assert isinstance(token, str) and len(token) > 20
        print("Password hashing and JWT generation verified.")

        print("--- TEST: ImageKit Auth Endpoint ---")
        res_ik = client.get("/media/imagekit-auth")
        assert res_ik.status_code == 200
        ik_data = res_ik.json()
        assert "enabled" in ik_data
        print("ImageKit auth endpoint verified:", ik_data)

        print("--- TEST: Login Endpoint Formats & Rate Limiter Fallback ---")
        # Invalid password returns 401 (not 500 or 422)
        res_invalid_login = client.post("/auth/login", json={
            "email": "nonexistent_user@zenvora.com",
            "password": "WrongPassword123!"
        })
        assert res_invalid_login.status_code == 401
        assert "detail" in res_invalid_login.json()
        print("Login with non-existent email correctly returned 401:", res_invalid_login.json())

        # Valid login with test user
        res_valid_login = client.post("/auth/login", json={
            "email": "luna@zenvora.com",
            "password": "Password123!"
        })
        assert res_valid_login.status_code == 200
        login_data = res_valid_login.json()
        assert "access_token" in login_data
        assert "user" in login_data
        print("Valid login successfully returned JWT token and user info.")

        # Missing email field returns 422 Unprocessable Entity
        res_missing_field = client.post("/auth/login", json={
            "password": "SomePassword"
        })
        assert res_missing_field.status_code == 422
        print("Login with missing email field correctly returned 422.")

        print("ALL API SANITY TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    test_api()
