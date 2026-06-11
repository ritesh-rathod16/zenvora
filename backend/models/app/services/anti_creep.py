from typing import List, Dict
import time
from ..models.user import User

class AntiCreepService:
    def __init__(self):
        # Memory-based tracking for real-time safety
        # user_id -> List of timestamps of recent reports
        self.report_history: Dict[str, List[float]] = {}
        # user_id -> Last matched time to detect spam switching
        self.last_match_time: Dict[str, float] = {}

    def is_flagged(self, user: User) -> bool:
        """Checks if a user is currently flagged as a 'creep' or 'spammer'."""
        # 1. Low Trust Score (below 40)
        if user.trust_score < 40:
            return True
        
        # 2. Frequent Reports (3+ in the last 10 minutes)
        reports = self.report_history.get(user.anonymous_username, [])
        now = time.time()
        recent_reports = [t for t in reports if now - t < 600]
        if len(recent_reports) >= 3:
            return True
            
        return False

    def track_report(self, reported_username: str):
        """Logs a report for a user in real-time."""
        if reported_username not in self.report_history:
            self.report_history[reported_username] = []
        self.report_history[reported_username].append(time.time())

    def update_match_time(self, username: str):
        """Tracks how quickly a user is jumping between matches."""
        self.last_match_time[username] = time.time()

    def detect_spam_skipping(self, username: str) -> bool:
        """Detects if a user is skipping matches too fast (bot/creep behavior)."""
        last_time = self.last_match_time.get(username, 0)
        now = time.time()
        # Less than 3 seconds per match for 5 consecutive matches?
        if now - last_time < 3:
            return True
        return False

anti_creep = AntiCreepService()
