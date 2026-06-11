from fastapi import APIRouter, HTTPException, Depends
from models.user import User
from jose import JWTError, jwt
import os
from fastapi.security import OAuth2PasswordBearer

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

SECRET_KEY = os.getenv("SECRET_KEY", "zenvora_secret_key_2026")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = await User.find_one(User.email == email)
    if user is None:
        raise credentials_exception
    return user

@router.get("/me")
async def read_users_me(current_user: User = Depends(get_current_user)):
    return {
        "anonymous_username": current_user.anonymous_username,
        "avatar_url": current_user.avatar_url,
        "trust_score": current_user.trust_score,
        "country": current_user.country,
        "interests": current_user.interests
    }

@router.get("/{username}")
async def get_user_profile(username: str):
    user = await User.find_one(User.anonymous_username == username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "anonymous_username": user.anonymous_username,
        "avatar_url": user.avatar_url,
        "trust_score": user.trust_score,
        "country": user.country,
        "interests": user.interests
    }
