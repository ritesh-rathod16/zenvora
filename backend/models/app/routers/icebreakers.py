from fastapi import APIRouter, Depends
from typing import List
import random
from ..core.security import get_current_user
from ..models.user import User

router = APIRouter()

ICEBREAKERS = [
    "Describe your life in 3 emojis.",
    "What's your biggest secret talent?",
    "If you could live anywhere where would it be?",
    "What's the most spontaneous thing you've ever done?",
    "What's your go-to comfort food?",
    "If you were a superhero, what would your power be?",
    "What's the last thing that made you laugh out loud?",
    "What's your favorite way to spend a rainy day?",
    "If you could have dinner with anyone, dead or alive, who would it be?",
    "What's the best piece of advice you've ever received?",
    "If you could travel back in time, where would you go?",
    "What's your most used app on your phone?",
    "What's a hobby you've always wanted to try but haven't yet?",
    "What's your favorite childhood memory?",
    "If you won the lottery tomorrow, what's the first thing you'd buy?"
]

@router.get("/", response_model=List[str])
async def get_icebreakers(count: int = 3, current_user: User = Depends(get_current_user)):
    """Returns a list of random icebreaker questions."""
    return random.sample(ICEBREAKERS, min(count, len(ICEBREAKERS)))
