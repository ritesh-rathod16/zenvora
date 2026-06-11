from fastapi import APIRouter, HTTPException, Depends, status
from ..models.user import User
from ..core.security import get_password_hash, verify_password, create_access_token
from ..utils.email import send_otp_email, generate_otp
from pydantic import BaseModel, EmailStr, Field
import logging
import re

# Setup logging
logger = logging.getLogger(__name__)

router = APIRouter()

class UserRegister(BaseModel):
    real_name: str = Field(..., min_length=2)
    email: EmailStr
    password: str = Field(..., min_length=6)
    username: str = Field(..., min_length=3, max_length=20)
    age: int = Field(..., ge=13)
    country: str
    interests: list[str] = []

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class VerifyOTP(BaseModel):
    email: EmailStr
    otp: str

def validate_username_format(username: str):
    if not 3 <= len(username) <= 20:
        return False
    if not re.match(r"^\w+$", username):
        return False
    return True

@router.post("/register")
async def register(user_data: UserRegister):
    if not validate_username_format(user_data.username):
        raise HTTPException(status_code=400, detail="Invalid username format")

    if await User.find_one({"email": user_data.email}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    
    if await User.find_one({"anonymous_username": user_data.username}):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already taken")
        
    password_hash = get_password_hash(user_data.password)
    otp = generate_otp()
    
    new_user = User(
        real_name=user_data.real_name,
        email=user_data.email,
        password_hash=password_hash,
        age=user_data.age,
        country=user_data.country,
        interests=user_data.interests,
        anonymous_username=user_data.username,
        verification_token=otp,
        avatar_url=f"https://api.dicebear.com/7.x/avataaars/svg?seed={user_data.username}"
    )
    
    try:
        await new_user.insert()
        await send_otp_email(user_data.email, otp)
        
        return {
            "message": "OTP sent to your email.",
            "email": user_data.email
        }
    except Exception as e:
        logger.error(f"Error during registration: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/verify-otp")
async def verify_otp(data: VerifyOTP):
    user = await User.find_one({"email": data.email, "verification_token": data.otp})
    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP or email")
    
    user.is_active = True
    user.verification_token = None
    await user.save()

    access_token = create_access_token(data={"sub": user.email, "role": user.role})
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
async def login(credentials: UserLogin):
    user = await User.find_one({"email": credentials.email})
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Please verify your email first")

    access_token = create_access_token(data={"sub": user.email, "role": user.role})
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
