from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import JSON, Column, DateTime, Float, ForeignKey, Index, String, Text
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