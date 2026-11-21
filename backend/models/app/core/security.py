from datetime import datetime, timedelta, timezone
from typing import Optional
import os
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from ..models.user import User
from .config import SECRET_KEY, ALGORITHM

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    if not SECRET_KEY:
        raise RuntimeError("SECRET_KEY is not configured.")
    to_encode = data.copy()
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "iat": now})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> dict:
    if not SECRET_KEY:
        raise RuntimeError("SECRET_KEY is not configured.")
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    db_exception = HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Database connectivity temporarily unavailable."
    )
    try:
        payload = decode_access_token(token)
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    try:
        user = await User.find_one({"email": email})
    except Exception:
        raise db_exception

    if user is None:
        raise credentials_exception
    if not user.is_active or user.is_banned:
        raise credentials_exception
    if payload.get("ver", 0) != getattr(user, "token_version", 0):
        raise credentials_exception
    return user

async def get_current_admin(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin and current_user.role not in ["admin", "super_admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The user does not have enough privileges"
        )
    return current_user

def users_blocked(user: User, other: User) -> bool:
    return (
        other.anonymous_username in (user.blocked_users or [])
        or user.anonymous_username in (other.blocked_users or [])
    )

async def get_optional_current_user(token: Optional[str] = Depends(OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False))) -> Optional[User]:
    if not token:
        return None
    try:
        payload = decode_access_token(token)
        email: str = payload.get("sub")
        if email is None:
            return None
        user = await User.find_one({"email": email})
        if (
            user is None
            or not user.is_active
            or user.is_banned
            or payload.get("ver", 0) != getattr(user, "token_version", 0)
        ):
            return None
        return user
    except JWTError:
        return None
