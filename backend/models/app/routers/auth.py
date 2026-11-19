from fastapi import APIRouter, HTTPException, Depends, status, Request
from ..models.user import User
from ..core.security import get_password_hash, verify_password, create_access_token
from ..core.rate_limiter import limiter
from ..utils.email import send_otp_email, generate_otp
from pydantic import BaseModel, Field
import logging
import re

# Setup logging
logger = logging.getLogger(__name__)

router = APIRouter()

class UserRegister(BaseModel):
    real_name: str = Field(..., min_length=2)
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    username: str = Field(..., min_length=3, max_length=20)
    age: int = Field(..., ge=13)
    country: str
    interests: list[str] = []

class UserLogin(BaseModel):
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=1)

class VerifyOTP(BaseModel):
    email: str = Field(..., min_length=3)
    otp: str = Field(..., min_length=1)

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
    
    if await User.find_one({"anonymous_username": clean_username}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already taken")
        
    password_hash = get_password_hash(user_data.password)
    otp = generate_otp()
    
    new_user = User(
        real_name=user_data.real_name.strip(),
        email=clean_email,
        password_hash=password_hash,
        age=user_data.age,
        country=user_data.country,
        interests=user_data.interests,
        anonymous_username=clean_username,
        verification_token=otp,
        avatar_url=None,
        profile_photo_url=None
    )
    
    try:
        await new_user.insert()
        await send_otp_email(clean_email, otp)
        logger.info(f"User registration initiated for {clean_email} (@{clean_username})")
        
        return {
            "message": "OTP sent to your email.",
            "email": clean_email
        }
    except Exception as e:
        logger.error(f"Error during registration for {clean_email}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/verify-otp")
async def verify_otp(data: VerifyOTP):
    clean_email = data.email.strip().lower()
    clean_otp = data.otp.strip()

    user = await User.find_one({
        "email": {"$regex": f"^{re.escape(clean_email)}$", "$options": "i"},
        "verification_token": clean_otp
    })

    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP or email")
    
    user.is_active = True
    user.verification_token = None
    await user.save()

    access_token = create_access_token(data={"sub": user.email, "role": user.role})
    logger.info(f"OTP verified successfully for user {user.email}")

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
    logger.info(f"Login request received for email: {clean_email}")

    # Flexible case-insensitive lookup
    user = await User.find_one({"email": {"$regex": f"^{re.escape(clean_email)}$", "$options": "i"}})
    if not user:
        user = await User.find_one({"email": clean_email})

    if not user or not verify_password(credentials.password, user.password_hash):
        logger.warning(f"Invalid login credentials for email: {clean_email}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    
    if not user.is_active:
        logger.warning(f"Login attempt on inactive account: {clean_email}")
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Please verify your email first")

    access_token = create_access_token(data={"sub": user.email, "role": user.role})
    logger.info(f"Login successful for user: {user.anonymous_username} ({user.email})")

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
