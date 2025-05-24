from datetime import datetime
from typing import Any, Dict, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

# Token schemas
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenPayload(BaseModel):
    sub: UUID
    exp: datetime

# User schemas
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class UserUpdate(UserBase):
    password: Optional[str] = None

class UserInDB(UserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class User(UserInDB):
    pass

# Health Metric schemas
class HealthMetricBase(BaseModel):
    metric_type: str
    value: float
    source: str
    timestamp: datetime

class HealthMetricCreate(HealthMetricBase):
    pass

class HealthMetricUpdate(HealthMetricBase):
    pass

class HealthMetricInDB(HealthMetricBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

class HealthMetric(HealthMetricInDB):
    pass

# Goal schemas
class UserGoalBase(BaseModel):
    goal_type: str
    target_value: float
    start_date: datetime
    end_date: datetime

class UserGoalCreate(UserGoalBase):
    pass

class UserGoalUpdate(UserGoalBase):
    pass

class UserGoalInDB(UserGoalBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class UserGoal(UserGoalInDB):
    pass

# Data Source schemas
class DataSourceConnectionBase(BaseModel):
    source_type: str

class DataSourceConnectionCreate(DataSourceConnectionBase):
    pass

class DataSourceConnectionUpdate(DataSourceConnectionBase):
    status: Optional[str] = None
    error_message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None

class DataSourceConnectionInDB(DataSourceConnectionBase):
    id: UUID
    user_id: UUID
    status: str
    error_message: Optional[str]
    last_sync_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class DataSourceConnection(DataSourceConnectionInDB):
    pass

class DataSyncLogBase(BaseModel):
    connection_id: UUID
    status: str
    error_message: Optional[str]
    metrics_synced: Optional[Dict[str, int]]

class DataSyncLogCreate(DataSyncLogBase):
    pass

class DataSyncLogUpdate(DataSyncLogBase):
    end_time: Optional[datetime]

class DataSyncLogInDB(DataSyncLogBase):
    id: UUID
    start_time: datetime
    end_time: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True

class DataSyncLog(DataSyncLogInDB):
    pass

# Apple Health specific schemas
class AppleHealthAuthRequest(BaseModel):
    code: str
    state: str

class AppleHealthSyncRequest(BaseModel):
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    metrics: Optional[list[str]] = None

# Withings specific schemas
class WithingsAuthRequest(BaseModel):
    code: str
    state: str

class WithingsSyncRequest(BaseModel):
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    metrics: Optional[list[str]] = None

# CSV Import schemas
class CSVImportRequest(BaseModel):
    file_name: str
    file_type: str
    date_format: Optional[str] = None
    column_mapping: Dict[str, str]

class CSVImportResponse(BaseModel):
    import_id: UUID
    status: str
    records_processed: int
    errors: Optional[list[str]] = None 