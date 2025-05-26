from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import JSON, Column, DateTime, Float, ForeignKey, Index, String, Text, Boolean, Integer, Numeric
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    email = Column(String(255), unique=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    health_metrics = relationship("HealthMetric", back_populates="user")
    goals = relationship("UserGoal", back_populates="user")
    data_sources = relationship("DataSourceConnection", back_populates="user")
    preferences = relationship("UserDataSourcePreferences", back_populates="user", uselist=False)
    unified_metrics = relationship("HealthMetricUnified", back_populates="user")
    file_processing_jobs = relationship("FileProcessingJob", back_populates="user")

class HealthMetric(Base):
    __tablename__ = "health_metrics"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False)
    metric_type = Column(String(50), nullable=False)
    value = Column(Float, nullable=False)
    source = Column(String(50), nullable=False)
    timestamp = Column(DateTime, nullable=False, default=datetime.utcnow)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    meta = Column(JSON, nullable=True)  # For additional metric-specific data
    data_source = Column(String(50), nullable=True, default='manual')  # New column for multi-source support
    quality_score = Column(Numeric(precision=3, scale=2), nullable=True)  # Data quality indicator

    user = relationship("User", back_populates="health_metrics")

class UserGoal(Base):
    __tablename__ = "user_goals"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False)
    goal_type = Column(String(50), nullable=False)
    target_value = Column(Float, nullable=False)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="goals")

class DataSourceConnection(Base):
    __tablename__ = "data_source_connections"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False)
    source_type = Column(String(50), nullable=False)  # "apple_health", "withings", "csv"
    access_token = Column(Text, nullable=True)
    refresh_token = Column(Text, nullable=True)
    token_expires_at = Column(DateTime, nullable=True)
    last_sync_at = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False, default="disconnected")  # "connected", "disconnected", "error"
    error_message = Column(Text, nullable=True)
    meta = Column(JSON, nullable=True)  # For source-specific configuration
    sync_frequency = Column(String(20), nullable=False, default='daily')  # New column
    sync_preferences = Column(JSON, nullable=True)  # New column for sync preferences
    is_active = Column(Boolean, nullable=False, default=True)  # New column
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="data_sources")

class DataSyncLog(Base):
    __tablename__ = "data_sync_logs"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    connection_id = Column(PGUUID, ForeignKey("data_source_connections.id"), nullable=False)
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False)  # "success", "error", "in_progress"
    error_message = Column(Text, nullable=True)
    metrics_synced = Column(JSON, nullable=True)  # Count of metrics synced by type
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

class WithingsMeasurement(Base):
    __tablename__ = "withings_measurements"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    connection_id = Column(PGUUID, ForeignKey("data_source_connections.id"), nullable=False, index=True)
    timestamp = Column(DateTime, index=True, nullable=False)
    type = Column(String(50), index=True, nullable=False)  # e.g., "weight", "fat_mass", etc.
    value = Column(Float, nullable=False)
    unit = Column(String(10), nullable=False)
    device_id = Column(String(100), nullable=True)
    raw_data = Column(JSON, nullable=True)

    __table_args__ = (
        Index('ix_withings_measurements_connection_id_type_timestamp', 'connection_id', 'type', 'timestamp'),
    )

# New models for multi-source support

class UserDataSourcePreferences(Base):
    __tablename__ = "user_data_source_preferences"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False, index=True, unique=True)
    activity_source = Column(String(50), nullable=True)  # User's preferred activity data source
    sleep_source = Column(String(50), nullable=True)  # User's preferred sleep data source
    nutrition_source = Column(String(50), nullable=True)  # User's preferred nutrition data source
    body_composition_source = Column(String(50), nullable=True)  # User's preferred body composition source
    priority_rules = Column(JSON, nullable=True)  # Rules for handling multiple sources
    conflict_resolution = Column(JSON, nullable=True)  # How to resolve conflicts between sources
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="preferences")

class HealthMetricUnified(Base):
    __tablename__ = "health_metrics_unified"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False, index=True)
    metric_type = Column(String(50), nullable=False, index=True)  # e.g., "steps", "weight", "sleep_duration"
    category = Column(String(30), nullable=False, index=True)  # activity, sleep, nutrition, body_composition
    value = Column(Numeric(precision=10, scale=3), nullable=False)
    unit = Column(String(20), nullable=False)
    timestamp = Column(DateTime, nullable=False, index=True)
    data_source = Column(String(50), nullable=False)  # Source of this data point
    quality_score = Column(Numeric(precision=3, scale=2), nullable=True)  # Data quality (0.0-1.0)
    is_primary = Column(Boolean, nullable=False, default=False)  # Is this the primary data point for this timestamp
    source_specific_data = Column(JSON, nullable=True)  # Original data from source
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user = relationship("User", back_populates="unified_metrics")

    __table_args__ = (
        Index('ix_health_metrics_unified_user_category_timestamp', 'user_id', 'category', 'timestamp'),
    )

class FileProcessingJob(Base):
    __tablename__ = "file_processing_jobs"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    user_id = Column(PGUUID, ForeignKey("users.id"), nullable=False, index=True)
    file_type = Column(String(20), nullable=False)  # apple_health, csv
    filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)
    status = Column(String(20), nullable=False, index=True)  # pending, processing, completed, failed
    progress_percentage = Column(Integer, nullable=False, default=0)
    total_records = Column(Integer, nullable=True)
    processed_records = Column(Integer, nullable=False, default=0)
    error_message = Column(Text, nullable=True)
    processing_metadata = Column(JSON, nullable=True)  # File-specific processing info
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user = relationship("User", back_populates="file_processing_jobs")

class DataSourceCapabilities(Base):
    __tablename__ = "data_source_capabilities"

    id = Column(PGUUID, primary_key=True, default=uuid4)
    source_name = Column(String(50), nullable=False, index=True, unique=True)
    display_name = Column(String(100), nullable=False)
    supports_activity = Column(Boolean, nullable=False, default=False)
    supports_sleep = Column(Boolean, nullable=False, default=False)
    supports_nutrition = Column(Boolean, nullable=False, default=False)
    supports_body_composition = Column(Boolean, nullable=False, default=False)
    integration_type = Column(String(20), nullable=False)  # oauth2, file_upload
    oauth_config = Column(JSON, nullable=True)  # OAuth2 configuration
    api_endpoints = Column(JSON, nullable=True)  # API endpoint configuration
    rate_limits = Column(JSON, nullable=True)  # Rate limiting configuration
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow) 