from datetime import datetime
from typing import Optional, Dict, Any

from pydantic import BaseModel, Field

class WithingsMeasurement(BaseModel):
    """Model for Withings measurement data."""
    timestamp: datetime
    value: float
    unit: str
    type: str
    category: str
    source: str = "withings"
    device_id: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None

class WithingsBodyComposition(BaseModel):
    """Model for Withings body composition data."""
    timestamp: datetime
    fat_mass: Optional[float] = None
    fat_free_mass: Optional[float] = None
    fat_ratio: Optional[float] = None
    muscle_mass: Optional[float] = None
    muscle_mass_ratio: Optional[float] = None
    hydration: Optional[float] = None
    bone_mass: Optional[float] = None
    source: str = "withings"
    device_id: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None

class WithingsActivity(BaseModel):
    """Model for Withings activity data."""
    date: datetime
    steps: int
    distance: float
    calories: float
    elevation: float
    active_time: int  # in seconds
    source: str = "withings"
    device_id: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None

class WithingsSleep(BaseModel):
    """Model for Withings sleep data."""
    start_time: datetime
    end_time: datetime
    duration: int  # in seconds
    deep_sleep_duration: int  # in seconds
    light_sleep_duration: int  # in seconds
    rem_sleep_duration: int  # in seconds
    wake_duration: int  # in seconds
    sleep_score: Optional[int] = None
    source: str = "withings"
    device_id: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None

class WithingsUserInfo(BaseModel):
    """Model for Withings user information."""
    user_id: str
    firstname: str
    lastname: str
    shortname: Optional[str] = None
    gender: Optional[int] = None
    birthdate: Optional[datetime] = None
    email: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None

class WithingsTokenData(BaseModel):
    """Model for Withings OAuth2 token data."""
    access_token: str
    refresh_token: str
    expires_at: datetime
    token_type: str = "Bearer"
    scope: str
    user_id: str
    raw_data: Optional[Dict[str, Any]] = None 