import time
import hashlib
import secrets
from typing import Dict, Optional

class OAuthStateManager:
    """Simple in-memory state manager for OAuth flows."""
    
    def __init__(self, expiry_seconds: int = 600):  # 10 minutes
        self._states: Dict[str, Dict] = {}
        self._expiry_seconds = expiry_seconds
    
    def generate_state(self, user_id: str) -> str:
        """Generate a secure state parameter for OAuth."""
        # Create a unique state using user_id, timestamp, and random data
        timestamp = str(int(time.time()))
        random_data = secrets.token_urlsafe(16)
        state_data = f"{user_id}:{timestamp}:{random_data}"
        
        # Create a hash for the state
        state = hashlib.sha256(state_data.encode()).hexdigest()[:32]
        
        # Store state with metadata
        self._states[state] = {
            "user_id": user_id,
            "created_at": time.time(),
            "used": False
        }
        
        return state
    
    def verify_state(self, state: str, user_id: str) -> bool:
        """Verify a state parameter and mark it as used."""
        if state not in self._states:
            return False
        
        state_data = self._states[state]
        
        # Check if already used
        if state_data["used"]:
            return False
        
        # Check if expired
        if time.time() - state_data["created_at"] > self._expiry_seconds:
            del self._states[state]
            return False
        
        # Check if user_id matches
        if state_data["user_id"] != user_id:
            return False
        
        # Mark as used and return success
        state_data["used"] = True
        return True
    
    def cleanup_expired(self):
        """Remove expired states."""
        current_time = time.time()
        expired_states = [
            state for state, data in self._states.items()
            if current_time - data["created_at"] > self._expiry_seconds
        ]
        
        for state in expired_states:
            del self._states[state]

# Global state manager instance
oauth_state_manager = OAuthStateManager() 