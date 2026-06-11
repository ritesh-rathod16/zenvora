import random
from typing import List
import numpy as np
from ..models.user import User

class AIService:
    PERSONALITY_TYPES = [
        "The Adventurer", "The Thinker", "The Socialite", 
        "The Creative", "The Gamer", "The Techie", "The Dreamer"
    ]
    
    CLUSTERS = {
        "Gaming": ["gaming", "esports", "twitch", "steam", "rpg"],
        "Tech": ["programming", "ai", "coding", "web3", "gadgets"],
        "Music": ["jazz", "rock", "pop", "vinyl", "concerts", "lofi"],
        "Art": ["painting", "digital art", "photography", "design"],
        "Deep Talks": ["philosophy", "psychology", "mental health", "secrets"]
    }

    @classmethod
    def assign_personality(cls, user: User) -> str:
        """Assigns a personality type based on interests (mocked AI logic)."""
        if not user.interests:
            return random.choice(cls.PERSONALITY_TYPES)
        
        # Simple weighted choice based on keywords
        score = sum(len(interest) for interest in user.interests)
        idx = score % len(cls.PERSONALITY_TYPES)
        return cls.PERSONALITY_TYPES[idx]

    @classmethod
    def get_interest_cluster(cls, interests: List[str]) -> str:
        """Groups user into a cluster based on their interests."""
        if not interests:
            return "General"
        
        counts = {cluster: 0 for cluster in cls.CLUSTERS}
        for interest in interests:
            interest_lower = interest.lower()
            for cluster, keywords in cls.CLUSTERS.items():
                if any(k in interest_lower for k in keywords):
                    counts[cluster] += 1
        
        max_cluster = max(counts, key=counts.get)
        return max_cluster if counts[max_cluster] > 0 else "General"

    @classmethod
    def calculate_match_score(cls, user1: User, user2: User) -> float:
        """Calculates compatibility score between two users."""
        score = 0.0
        
        # Interest overlap (40%)
        common = set(user1.interests) & set(user2.interests)
        score += (len(common) / max(len(user1.interests), 1)) * 40
        
        # Personality match (30%)
        if user1.personality_type == user2.personality_type:
            score += 30
            
        # Cluster match (20%)
        if user1.interest_cluster == user2.interest_cluster:
            score += 20
            
        # Random spark (10%)
        score += random.random() * 10
        
        return score

ai_service = AIService()
