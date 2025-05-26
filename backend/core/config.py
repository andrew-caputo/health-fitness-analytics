import os
from typing import Optional, Dict, Any, List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/health_fitness_analytics")
    
    # JWT
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-here")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Withings API
    WITHINGS_CLIENT_ID: str = os.getenv("WITHINGS_CLIENT_ID", "")
    WITHINGS_CLIENT_SECRET: str = os.getenv("WITHINGS_CLIENT_SECRET", "")
    WITHINGS_REDIRECT_URI: str = os.getenv("WITHINGS_REDIRECT_URI", "http://localhost:3000/auth/withings/callback")
    
    # Oura API
    OURA_CLIENT_ID: str = os.getenv("OURA_CLIENT_ID", "")
    OURA_CLIENT_SECRET: str = os.getenv("OURA_CLIENT_SECRET", "")
    OURA_REDIRECT_URI: str = os.getenv("OURA_REDIRECT_URI", "http://localhost:3000/auth/oura/callback")
    
    # Fitbit API
    FITBIT_CLIENT_ID: str = os.getenv("FITBIT_CLIENT_ID", "")
    FITBIT_CLIENT_SECRET: str = os.getenv("FITBIT_CLIENT_SECRET", "")
    FITBIT_REDIRECT_URI: str = os.getenv("FITBIT_REDIRECT_URI", "http://localhost:3000/auth/fitbit/callback")
    
    # WHOOP API
    WHOOP_CLIENT_ID: str = os.getenv("WHOOP_CLIENT_ID", "")
    WHOOP_CLIENT_SECRET: str = os.getenv("WHOOP_CLIENT_SECRET", "")
    WHOOP_REDIRECT_URI: str = os.getenv("WHOOP_REDIRECT_URI", "http://localhost:3000/auth/whoop/callback")
    
    # Strava API
    STRAVA_CLIENT_ID: str = os.getenv("STRAVA_CLIENT_ID", "")
    STRAVA_CLIENT_SECRET: str = os.getenv("STRAVA_CLIENT_SECRET", "")
    STRAVA_REDIRECT_URI: str = os.getenv("STRAVA_REDIRECT_URI", "http://localhost:3000/auth/strava/callback")
    
    # MyFitnessPal API
    MYFITNESSPAL_CLIENT_ID: str = os.getenv("MYFITNESSPAL_CLIENT_ID", "")
    MYFITNESSPAL_CLIENT_SECRET: str = os.getenv("MYFITNESSPAL_CLIENT_SECRET", "")
    MYFITNESSPAL_REDIRECT_URI: str = os.getenv("MYFITNESSPAL_REDIRECT_URI", "http://localhost:3000/auth/myfitnesspal/callback")
    
    # Cronometer API
    CRONOMETER_CLIENT_ID: str = os.getenv("CRONOMETER_CLIENT_ID", "")
    CRONOMETER_CLIENT_SECRET: str = os.getenv("CRONOMETER_CLIENT_SECRET", "")
    CRONOMETER_REDIRECT_URI: str = os.getenv("CRONOMETER_REDIRECT_URI", "http://localhost:3000/auth/cronometer/callback")
    
    # CORS and Security
    ALLOWED_HOSTS: List[str] = os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1,0.0.0.0").split(",")
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "true").lower() == "true"
    
    # Rate Limiting
    RATE_LIMIT_CALLS: int = int(os.getenv("RATE_LIMIT_CALLS", "100"))
    RATE_LIMIT_PERIOD: int = int(os.getenv("RATE_LIMIT_PERIOD", "60"))
    
    class Config:
        env_file = ".env"


# Withings API endpoints and configuration
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

# Withings API rate limits
WITHINGS_RATE_LIMITS = {
    "requests_per_minute": 60,
    "requests_per_hour": 1000
}

# Withings sync configuration
WITHINGS_SYNC_CONFIG = {
    "batch_size": 100,
    "max_retries": 3,
    "retry_delay": 5,  # seconds
    "sync_interval": 900  # 15 minutes in seconds
}

# Oura API endpoints and configuration
OURA_BASE_URL = "https://api.ouraring.com"
OURA_AUTH_URL = "https://cloud.ouraring.com/oauth/authorize"
OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token"

# Oura API scopes
OURA_SCOPES = ["daily", "heartrate", "workout", "tag", "session"]

# Oura API rate limits
OURA_RATE_LIMITS = {
    "requests_per_minute": 300,
    "requests_per_hour": 5000
}

# Oura sync configuration
OURA_SYNC_CONFIG = {
    "batch_size": 50,
    "max_retries": 3,
    "retry_delay": 5,
    "sync_interval": 900
}

# Apple Health configuration
APPLE_HEALTH_CONFIG = {
    "supported_formats": [".zip"],
    "max_file_size": 100 * 1024 * 1024,  # 100MB
    "batch_size": 1000,
    "processing_timeout": 3600  # 1 hour
}

# CSV Import configuration
CSV_IMPORT_CONFIG = {
    "supported_formats": [".csv"],
    "max_file_size": 10 * 1024 * 1024,  # 10MB
    "batch_size": 1000,
    "max_rows": 100000
}

# General sync configuration
GENERAL_SYNC_CONFIG = {
    "default_sync_interval": 900,  # 15 minutes
    "max_concurrent_syncs": 5,
    "sync_timeout": 1800,  # 30 minutes
    "retry_exponential_base": 2,
    "max_retry_delay": 300  # 5 minutes
}

# File upload configuration
FILE_UPLOAD_CONFIG = {
    "upload_dir": "uploads",
    "temp_dir": "temp",
    "max_file_age_days": 7,
    "cleanup_interval": 3600  # 1 hour
}

settings = Settings() 