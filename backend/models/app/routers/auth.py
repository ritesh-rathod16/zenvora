from fastapi import APIRouter, HTTPException, Depends, status, Request
from ..models.user import User
from ..core.security import get_password_hash, verify_password, create_access_token, get_current_user, SECRET_KEY
from ..core.rate_limiter import limiter
from ..utils.email import send_otp_email, generate_otp
from pydantic import BaseModel, Field
import logging
import re
import hashlib
import hmac
from datetime import datetime, timedelta, timezone

# Setup logging
logger = logging.getLogger(__name__)

router = APIRouter()

class UserRegister(BaseModel):
    real_name: str = Field(..., min_length=2)
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    username: str = Field(..., min_length=3, max_length=20)
    age: int = Field(..., ge=13, le=120)
    country: str
    interests: list[str] = []

class UserLogin(BaseModel):
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=1)

class VerifyOTP(BaseModel):
    email: str = Field(..., min_length=3)
    otp: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$")

def validate_username_format(username: str):
    if not 3 <= len(username) <= 20:
        return False
    if not re.match(r"^\w+$", username):
        return False
    return True

@router.post("/register")
@limiter.limit("10/minute")
async def register(request: Request, user_data: UserRegister):
    clean_email = user_data.email.strip().lower()
    clean_username = user_data.username.strip()

    if not validate_username_format(clean_username):
        raise HTTPException(status_code=400, detail="Invalid username format")

    if await User.find_one({"email": {"$regex": f"^{re.escape(clean_email)}$", "$options": "i"}}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    
    normalized_username = clean_username.lower()
    if await User.find_one({"normalized_username": normalized_username}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already taken")
        
    password_hash = get_password_hash(user_data.password)
    otp = generate_otp()
    otp_digest = hmac.new(SECRET_KEY.encode("utf-8"), otp.encode("ascii"), hashlib.sha256).hexdigest()
    
    new_user = User(
        real_name=user_data.real_name.strip(),
        email=clean_email,
        password_hash=password_hash,
        age=user_data.age,
        country=user_data.country,
        interests=user_data.interests,
        anonymous_username=clean_username,
        normalized_username=normalized_username,
        verification_token=otp_digest,
        verification_expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        avatar_url=None,
        profile_photo_url=None
    )
    
    try:
        await new_user.insert()
    except Exception:
        logger.error("User registration persistence failed.")
        raise HTTPException(status_code=500, detail="Internal server error")

    try:
        await send_otp_email(clean_email, otp)
    except Exception:
        try:
            await new_user.delete()
        except Exception:
            logger.error("Could not remove the incomplete registration.")
            raise HTTPException(status_code=500, detail="Internal server error")
        logger.error("User registration verification email could not be sent.")
        raise HTTPException(status_code=503, detail="Verification email is temporarily unavailable.")

    logger.info("User registration initiated.")
    return {
        "message": "OTP sent to your email.",
        "email": clean_email
    }

@router.post("/verify-otp")
@limiter.limit("5/minute")
async def verify_otp(request: Request, data: VerifyOTP):
    clean_email = data.email.strip().lower()
    clean_otp = data.otp.strip()
    now = datetime.now(timezone.utc)
    otp_digest = hmac.new(SECRET_KEY.encode("utf-8"), clean_otp.encode("ascii"), hashlib.sha256).hexdigest()

    user = await User.find_one({
        "email": {"$regex": f"^{re.escape(clean_email)}$", "$options": "i"},
        "verification_token": otp_digest,
        "verification_expires_at": {"$gt": now},
    })

    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP or email")
    
    user.is_active = True
    user.verification_token = None
    user.verification_expires_at = None
    await user.save()

    access_token = create_access_token(data={
        "sub": user.email,
        "role": user.role,
        "ver": getattr(user, "token_version", 0),
    })
    logger.info("Email verification completed.")

    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "user": {
            "email": user.email,
            "anonymous_username": user.anonymous_username,
            "avatar_url": user.avatar_url,
            "trust_score": user.trust_score,
            "is_admin": user.is_admin or user.role in ["admin", "super_admin"],
            "role": user.role
        }
    }

@router.post("/login")
@limiter.limit("10/minute")
async def login(request: Request, credentials: UserLogin):
    clean_email = credentials.email.strip().lower()

    # Flexible case-insensitive lookup
    user = await User.find_one({"email": {"$regex": f"^{re.escape(clean_email)}$", "$options": "i"}})
    if not user:
        user = await User.find_one({"email": clean_email})

    if not user or not verify_password(credentials.password, user.password_hash):
        logger.warning("Invalid login credentials.")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    
    if user.is_banned:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is unavailable")
    if not user.is_active:
        logger.warning("Login attempt on inactive account.")
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Please verify your email first")

    access_token = create_access_token(data={
        "sub": user.email,
        "role": user.role,
        "ver": getattr(user, "token_version", 0),
    })
    logger.info("User login successful.")

    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "user": {
            "email": user.email,
            "anonymous_username": user.anonymous_username,
            "avatar_url": user.avatar_url,
            "trust_score": user.trust_score,
            "is_admin": user.is_admin or user.role in ["admin", "super_admin"],
            "role": user.role
        }
    }

@router.post("/logout")
async def logout(current_user: User = Depends(get_current_user)):
    current_user.token_version = getattr(current_user, "token_version", 0) + 1
    await current_user.save()
    return {"message": "Logged out"}
