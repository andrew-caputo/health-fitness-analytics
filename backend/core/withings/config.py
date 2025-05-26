import os
from typing import Dict, Any

# Withings OAuth2 configuration
WITHINGS_CLIENT_ID = os.getenv("WITHINGS_CLIENT_ID", "your-client-id")
WITHINGS_CLIENT_SECRET = os.getenv("WITHINGS_CLIENT_SECRET", "your-client-secret")
WITHINGS_REDIRECT_URI = os.getenv("WITHINGS_REDIRECT_URI", "http://localhost:8000/api/v1/data-sources/withings/callback")

# Withings API endpoints
WITHINGS_API_BASE_URL = "https://wbsapi.withings.net"
WITHINGS_AUTH_URL = "https://account.withings.com/oauth2_user/authorize2"
WITHINGS_TOKEN_URL = "https://wbsapi.withings.net/v2/oauth2"

# Withings API scopes
WITHINGS_SCOPES = [
    "user.info",
    "user.metrics",
    "user.activity",
    "user.sleepevents"
]

# Withings metric types mapping
WITHINGS_METRICS = {
    "weight": {
        "type": "instantaneous",
        "unit": "kg",
        "description": "Body weight",
        "api_field": "weight",
        "category": "body"
    },
    "body_composition": {
        "type": "instantaneous",
        "metrics": {
            "fat_mass": {
                "unit": "kg",
                "description": "Fat mass",
                "api_field": "fat_mass",
                "category": "body"
            },
            "fat_free_mass": {
                "unit": "kg",
                "description": "Fat free mass",
                "api_field": "fat_free_mass",
                "category": "body"
            },
            "fat_ratio": {
                "unit": "%",
                "description": "Fat ratio",
                "api_field": "fat_ratio",
                "category": "body"
            },
            "muscle_mass": {
                "unit": "kg",
                "description": "Muscle mass",
                "api_field": "muscle_mass",
                "category": "body"
            },
            "muscle_mass_ratio": {
                "unit": "%",
                "description": "Muscle mass ratio",
                "api_field": "muscle_mass_ratio",
                "category": "body"
            },
            "hydration": {
                "unit": "%",
                "description": "Hydration level",
                "api_field": "hydration",
                "category": "body"
            },
            "bone_mass": {
                "unit": "kg",
                "description": "Bone mass",
                "api_field": "bone_mass",
                "category": "body"
            }
        }
    }
}

# API rate limits
WITHINGS_RATE_LIMITS = {
    "requests_per_minute": 60,
    "requests_per_hour": 1000
}

# Sync configuration
WITHINGS_SYNC_CONFIG = {
    "batch_size": 100,
    "max_retries": 3,
    "retry_delay": 5,  # seconds
    "sync_interval": 900  # 15 minutes in seconds
} 