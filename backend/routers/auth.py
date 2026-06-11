from fastapi import APIRouter, HTTPException, Depends, status
from models.user import User
from utils.auth import get_password_hash, verify_password, create_access_token
from utils.email import send_verification_email
from pydantic import BaseModel, EmailStr
import random
import string
import uuid

router = APIRouter()

class UserRegister(BaseModel):
    real_name: str
    email: EmailStr
    password: str
    age: int
    country: str
    interests: list[str]

class UserLogin(BaseModel):
    email: EmailStr
    password: str

def generate_anonymous_username():
    adjectives = ["Silent", "Brave", "Mystic", "Swift", "Calm", "Lunar", "Solar", "Frosty", "Neon", "Ethereal"]
    nouns = ["Fox", "Eagle", "Wolf", "Panda", "Tiger", "Owl", "Cat", "Phoenix", "Dragon", "Ghost"]
    return f"{random.choice(adjectives)}{random.choice(nouns)}{random.randint(100, 999)}"

@router.post("/register")
async def register(user_data: UserRegister):
    existing_user = await User.find_one(User.email == user_data.email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    anonymous_username = generate_anonymous_username()
    while await User.find_one(User.anonymous_username == anonymous_username):
        anonymous_username = generate_anonymous_username()
        
    password_hash = get_password_hash(user_data.password)
    verification_token = str(uuid.uuid4())
    
    new_user = User(
        real_name=user_data.real_name,
        email=user_data.email,
        password_hash=password_hash,
        age=user_data.age,
        country=user_data.country,
        interests=user_data.interests,
        anonymous_username=anonymous_username,
        verification_token=verification_token,
        avatar_url=f"https://api.dicebear.com/7.x/avataaars/svg?seed={anonymous_username}"
    )
    
    await new_user.insert()
    send_verification_email(user_data.email, verification_token)
    
    return {"message": "User registered successfully. Please verify your email.", "anonymous_username": anonymous_username}

@router.get("/verify")
async def verify_email(token: str):
    user = await User.find_one(User.verification_token == token)
    if not user:
        raise HTTPException(status_code=400, detail="Invalid verification token")
    
    user.is_active = True
    user.verification_token = None
    await user.save()
    return {"message": "Email verified successfully"}

@router.post("/login")
async def login(credentials: UserLogin):
    user = await User.find_one(User.email == credentials.email)
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Please verify your email first")

    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": {
        "anonymous_username": user.anonymous_username,
        "avatar_url": user.avatar_url,
        "trust_score": user.trust_score
    }}
