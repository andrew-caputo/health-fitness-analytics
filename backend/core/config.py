import os
from typing import Optional
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
    
    # CORS
    ALLOWED_HOSTS: list = ["localhost", "127.0.0.1", "0.0.0.0"]
    
    class Config:
        env_file = ".env"


settings = Settings() 