from datetime import datetime
from typing import Any, Dict, Optional, List
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

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class User(UserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Health Metric schemas
class HealthMetricBase(BaseModel):
    metric_type: str
    value: float
    source: str
    timestamp: Optional[datetime] = None
    data_source: Optional[str] = 'manual'
    quality_score: Optional[float] = None
    meta: Optional[Dict[str, Any]] = None

class HealthMetricCreate(HealthMetricBase):
    pass

class HealthMetricUpdate(HealthMetricBase):
    metric_type: Optional[str] = None
    value: Optional[float] = None
    source: Optional[str] = None
    timestamp: Optional[datetime] = None
    data_source: Optional[str] = None
    quality_score: Optional[float] = None
    meta: Optional[Dict[str, Any]] = None

class HealthMetric(HealthMetricBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

# Goal schemas
class UserGoalBase(BaseModel):
    goal_type: str
    target_value: float
    start_date: datetime
    end_date: datetime

class UserGoalCreate(UserGoalBase):
    pass

class UserGoalUpdate(UserGoalBase):
    goal_type: Optional[str] = None
    target_value: Optional[float] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None

class UserGoal(UserGoalBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Data Source schemas
class DataSourceConnectionBase(BaseModel):
    source_type: str
    sync_frequency: Optional[str] = 'daily'
    sync_preferences: Optional[Dict[str, Any]] = None
    is_active: Optional[bool] = True

class DataSourceConnectionCreate(DataSourceConnectionBase):
    pass

class DataSourceConnection(DataSourceConnectionBase):
    id: UUID
    user_id: UUID
    status: str
    last_sync_at: Optional[datetime] = None
    error_message: Optional[str] = None
    meta: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

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

# New schemas for multi-source support

class UserDataSourcePreferencesBase(BaseModel):
    activity_source: Optional[str] = None
    sleep_source: Optional[str] = None
    nutrition_source: Optional[str] = None
    body_composition_source: Optional[str] = None
    priority_rules: Optional[Dict[str, Any]] = None
    conflict_resolution: Optional[Dict[str, Any]] = None

class UserDataSourcePreferencesCreate(UserDataSourcePreferencesBase):
    pass

class UserDataSourcePreferencesUpdate(UserDataSourcePreferencesBase):
    pass

class UserDataSourcePreferences(UserDataSourcePreferencesBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class HealthMetricUnifiedBase(BaseModel):
    metric_type: str
    category: str  # activity, sleep, nutrition, body_composition
    value: float
    unit: str
    timestamp: datetime
    data_source: str
    quality_score: Optional[float] = None
    is_primary: Optional[bool] = False
    source_specific_data: Optional[Dict[str, Any]] = None

class HealthMetricUnifiedCreate(HealthMetricUnifiedBase):
    pass

class HealthMetricUnified(HealthMetricUnifiedBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

class FileProcessingJobBase(BaseModel):
    file_type: str  # apple_health, csv
    filename: str
    file_path: str

class FileProcessingJobCreate(FileProcessingJobBase):
    pass

class FileProcessingJob(FileProcessingJobBase):
    id: UUID
    user_id: UUID
    status: str  # pending, processing, completed, failed
    progress_percentage: int
    total_records: Optional[int] = None
    processed_records: int
    error_message: Optional[str] = None
    processing_metadata: Optional[Dict[str, Any]] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class DataSourceCapabilitiesBase(BaseModel):
    source_name: str
    display_name: str
    supports_activity: bool = False
    supports_sleep: bool = False
    supports_nutrition: bool = False
    supports_body_composition: bool = False
    integration_type: str  # oauth2, file_upload
    oauth_config: Optional[Dict[str, Any]] = None
    api_endpoints: Optional[Dict[str, Any]] = None
    rate_limits: Optional[Dict[str, Any]] = None
    is_active: bool = True

class DataSourceCapabilitiesCreate(DataSourceCapabilitiesBase):
    pass

class DataSourceCapabilities(DataSourceCapabilitiesBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Response schemas for API endpoints

class DataSourceStatus(BaseModel):
    source_name: str
    display_name: str
    is_connected: bool
    last_sync: Optional[datetime] = None
    status: str
    supports_activity: bool
    supports_sleep: bool
    supports_nutrition: bool
    supports_body_composition: bool

class UserPreferencesResponse(BaseModel):
    preferences: Optional[UserDataSourcePreferences] = None
    available_sources: List[DataSourceCapabilities]
    connected_sources: List[DataSourceStatus]

class FileUploadResponse(BaseModel):
    job_id: UUID
    filename: str
    status: str
    message: str

class DataSourceSummary(BaseModel):
    total_sources: int
    connected_sources: int
    categories_covered: Dict[str, bool]  # activity, sleep, nutrition, body_composition
    last_sync: Optional[datetime] = None

# Metrics aggregation schemas

class MetricAggregation(BaseModel):
    metric_type: str
    category: str
    period: str  # daily, weekly, monthly
    start_date: datetime
    end_date: datetime
    values: List[Dict[str, Any]]  # timestamp, value, data_source
    average: Optional[float] = None
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    trend: Optional[str] = None  # increasing, decreasing, stable

class CategoryMetrics(BaseModel):
    category: str
    metrics: List[MetricAggregation]
    data_sources: List[str]
    coverage_percentage: float  # How much of the time period has data

class HealthDashboard(BaseModel):
    user_id: UUID
    period: str
    start_date: datetime
    end_date: datetime
    activity: Optional[CategoryMetrics] = None
    sleep: Optional[CategoryMetrics] = None
    nutrition: Optional[CategoryMetrics] = None
    body_composition: Optional[CategoryMetrics] = None
    data_source_summary: DataSourceSummary 