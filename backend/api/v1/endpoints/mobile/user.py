from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import and_, desc, func

from backend.api.deps import get_db, get_current_user
from backend.core.models import User, HealthMetricUnified, DataSourceConnection, UserDataSourcePreferences
from backend.core.schemas import User as UserSchema

router = APIRouter()

# Pydantic models for mobile user management
class MobileUserProfile(BaseModel):
    id: int
    email: str
    created_at: Optional[datetime]
    total_metrics: int = Field(..., description="Total number of health metrics")
    connected_sources: int = Field(..., description="Number of connected data sources")
    last_sync: Optional[datetime] = Field(None, description="Last data synchronization")
    healthkit_enabled: bool = Field(False, description="Whether HealthKit is connected")
    
class MobileUserPreferences(BaseModel):
    sync_frequency: str = Field(default="auto", description="Sync frequency: 'auto', 'manual', 'hourly', 'daily'")
    notifications_enabled: bool = Field(default=True, description="Whether to send push notifications")
    data_retention_days: int = Field(default=365, description="How long to keep data (days)")
    preferred_units: Dict[str, str] = Field(default_factory=dict, description="Preferred units for metrics")
    privacy_level: str = Field(default="standard", description="Privacy level: 'minimal', 'standard', 'detailed'")
    background_sync: bool = Field(default=True, description="Allow background data synchronization")
    
class UpdateUserPreferences(BaseModel):
    sync_frequency: Optional[str] = None
    notifications_enabled: Optional[bool] = None
    data_retention_days: Optional[int] = None
    preferred_units: Optional[Dict[str, str]] = None
    privacy_level: Optional[str] = None
    background_sync: Optional[bool] = None

class HealthDataSummary(BaseModel):
    metric_type: str
    total_count: int
    latest_value: Optional[float]
    latest_recorded_at: Optional[datetime]
    source_apps: List[str]
    date_range: Dict[str, Optional[datetime]]

@router.get("/profile", response_model=MobileUserProfile)
async def get_mobile_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> MobileUserProfile:
    """
    Get comprehensive user profile for mobile app.
    Includes health data statistics and connection status.
    """
    # Count total health metrics
    total_metrics = db.query(func.count(HealthMetricUnified.id)).filter(
        HealthMetricUnified.user_id == current_user.id
    ).scalar() or 0
    
    # Count connected data sources
    connected_sources = db.query(func.count(DataSourceConnection.id)).filter(
        and_(
            DataSourceConnection.user_id == current_user.id,
            DataSourceConnection.is_active == True
        )
    ).scalar() or 0
    
    # Get last sync time
    last_sync = db.query(func.max(HealthMetricUnified.created_at)).filter(
        HealthMetricUnified.user_id == current_user.id
    ).scalar()
    
    # Check if HealthKit is enabled (has HealthKit data)
    healthkit_enabled = db.query(HealthMetricUnified).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.source_type == "healthkit"
        )
    ).first() is not None
    
    return MobileUserProfile(
        id=current_user.id,
        email=current_user.email,
        created_at=current_user.created_at,
        total_metrics=total_metrics,
        connected_sources=connected_sources,
        last_sync=last_sync,
        healthkit_enabled=healthkit_enabled
    )

@router.get("/preferences", response_model=MobileUserPreferences)
async def get_user_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> MobileUserPreferences:
    """
    Get user preferences for mobile app.
    Returns default preferences if none are set.
    """
    preferences = db.query(UserDataSourcePreferences).filter(
        UserDataSourcePreferences.user_id == current_user.id
    ).first()
    
    if not preferences:
        # Return default preferences
        return MobileUserPreferences()
    
    # Parse preferences from database (using priority_rules as preferences storage)
    prefs_data = preferences.priority_rules or {}
    return MobileUserPreferences(
        sync_frequency=prefs_data.get("sync_frequency", "auto"),
        notifications_enabled=prefs_data.get("notifications_enabled", True),
        data_retention_days=prefs_data.get("data_retention_days", 365),
        preferred_units=prefs_data.get("preferred_units", {}),
        privacy_level=prefs_data.get("privacy_level", "standard"),
        background_sync=prefs_data.get("background_sync", True)
    )

@router.put("/preferences", response_model=MobileUserPreferences)
async def update_user_preferences(
    preferences_update: UpdateUserPreferences,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> MobileUserPreferences:
    """
    Update user preferences for mobile app.
    Only updates provided fields, keeps existing values for others.
    """
    # Get existing preferences or create new
    preferences = db.query(UserDataSourcePreferences).filter(
        UserDataSourcePreferences.user_id == current_user.id
    ).first()
    
    if not preferences:
        preferences = UserDataSourcePreferences(
            user_id=current_user.id,
            priority_rules={}
        )
        db.add(preferences)
    
    # Update only provided fields
    update_data = preferences_update.dict(exclude_unset=True)
    prefs_data = preferences.priority_rules or {}
    for key, value in update_data.items():
        prefs_data[key] = value
    
    preferences.priority_rules = prefs_data
    preferences.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(preferences)
    
    # Return updated preferences
    return MobileUserPreferences(
        sync_frequency=prefs_data.get("sync_frequency", "auto"),
        notifications_enabled=prefs_data.get("notifications_enabled", True),
        data_retention_days=prefs_data.get("data_retention_days", 365),
        preferred_units=prefs_data.get("preferred_units", {}),
        privacy_level=prefs_data.get("privacy_level", "standard"),
        background_sync=prefs_data.get("background_sync", True)
    )

@router.get("/health-summary", response_model=List[HealthDataSummary])
async def get_health_data_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[HealthDataSummary]:
    """
    Get summary of user's health data by metric type.
    Useful for mobile app dashboard and data overview.
    """
    # Query health metrics grouped by type
    metrics_query = db.query(
        HealthMetricUnified.metric_type,
        func.count(HealthMetricUnified.id).label('total_count'),
        func.max(HealthMetricUnified.value).label('latest_value'),
        func.max(HealthMetricUnified.recorded_at).label('latest_recorded_at'),
        func.min(HealthMetricUnified.recorded_at).label('earliest_recorded_at')
    ).filter(
        HealthMetricUnified.user_id == current_user.id
    ).group_by(HealthMetricUnified.metric_type).all()
    
    summaries = []
    for metric in metrics_query:
        # Get source apps for this metric type
        source_apps = db.query(HealthMetricUnified.source_app).filter(
            and_(
                HealthMetricUnified.user_id == current_user.id,
                HealthMetricUnified.metric_type == metric.metric_type,
                HealthMetricUnified.source_app.isnot(None)
            )
        ).distinct().all()
        
        source_app_names = [app[0] for app in source_apps if app[0]]
        
        summaries.append(HealthDataSummary(
            metric_type=metric.metric_type,
            total_count=metric.total_count,
            latest_value=metric.latest_value,
            latest_recorded_at=metric.latest_recorded_at,
            source_apps=source_app_names,
            date_range={
                "earliest": metric.earliest_recorded_at,
                "latest": metric.latest_recorded_at
            }
        ))
    
    return summaries

@router.get("/connected-sources", response_model=List[Dict[str, Any]])
async def get_connected_sources(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[Dict[str, Any]]:
    """
    Get list of connected data sources for mobile app.
    Includes both OAuth2 connections and HealthKit status.
    """
    # Get OAuth2 connections
    oauth_connections = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id
    ).all()
    
    sources = []
    
    # Add OAuth2 sources
    for connection in oauth_connections:
        sources.append({
            "source_type": connection.source_type,
            "connection_type": "oauth2",
            "is_active": connection.is_active,
            "connected_at": connection.created_at.isoformat() if connection.created_at else None,
            "last_sync": connection.last_sync_at.isoformat() if connection.last_sync_at else None,
            "status": "connected" if connection.is_active else "disconnected"
        })
    
    # Check HealthKit status
    healthkit_metrics = db.query(func.count(HealthMetricUnified.id)).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.source_type == "healthkit"
        )
    ).scalar() or 0
    
    if healthkit_metrics > 0:
        last_healthkit_sync = db.query(func.max(HealthMetricUnified.created_at)).filter(
            and_(
                HealthMetricUnified.user_id == current_user.id,
                HealthMetricUnified.source_type == "healthkit"
            )
        ).scalar()
        
        sources.append({
            "source_type": "healthkit",
            "connection_type": "mobile_app",
            "is_active": True,
            "connected_at": None,  # HealthKit doesn't have explicit connection time
            "last_sync": last_healthkit_sync.isoformat() if last_healthkit_sync else None,
            "status": "connected",
            "metrics_count": healthkit_metrics
        })
    
    return sources

@router.delete("/account", response_model=Dict[str, str])
async def delete_user_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, str]:
    """
    Delete user account and all associated data.
    This is a destructive operation that cannot be undone.
    """
    try:
        # Delete health metrics
        db.query(HealthMetricUnified).filter(
            HealthMetricUnified.user_id == current_user.id
        ).delete()
        
        # Delete data source connections
        db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == current_user.id
        ).delete()
        
        # Delete user preferences
        db.query(UserDataSourcePreferences).filter(
            UserDataSourcePreferences.user_id == current_user.id
        ).delete()
        
        # Delete user account
        db.delete(current_user)
        db.commit()
        
        return {"message": "Account successfully deleted"}
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete account: {str(e)}"
        )

@router.get("/data-export", response_model=Dict[str, Any])
async def export_user_data(
    format: str = "json",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Export all user data for backup or migration.
    Supports JSON format for mobile app data portability.
    """
    if format not in ["json"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JSON format is currently supported"
        )
    
    # Get all health metrics
    health_metrics = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id
    ).all()
    
    # Get data source connections
    connections = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id
    ).all()
    
    # Get user preferences
    preferences = db.query(UserDataSourcePreferences).filter(
        UserDataSourcePreferences.user_id == current_user.id
    ).first()
    
    export_data = {
        "user": {
            "id": current_user.id,
            "email": current_user.email,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None
        },
        "health_metrics": [
            {
                "metric_type": metric.metric_type,
                "value": metric.value,
                "unit": metric.unit,
                "source_type": metric.source_type,
                "recorded_at": metric.recorded_at.isoformat(),
                "source_app": metric.source_app,
                "device_name": metric.device_name,
                "metadata": metric.metadata,
                "created_at": metric.created_at.isoformat() if metric.created_at else None
            }
            for metric in health_metrics
        ],
        "data_sources": [
            {
                "source_type": conn.source_type,
                "is_active": conn.is_active,
                "created_at": conn.created_at.isoformat() if conn.created_at else None,
                "last_sync_at": conn.last_sync_at.isoformat() if conn.last_sync_at else None
            }
            for conn in connections
        ],
        "preferences": preferences.priority_rules if preferences else {},
        "export_metadata": {
            "exported_at": datetime.utcnow().isoformat(),
            "format": format,
            "total_metrics": len(health_metrics),
            "total_connections": len(connections)
        }
    }
    
    return export_data

@router.get("/stats", response_model=Dict[str, Any])
async def get_user_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Get user statistics for mobile app dashboard.
    Provides quick overview of data and activity.
    """
    # Basic counts
    total_metrics = db.query(func.count(HealthMetricUnified.id)).filter(
        HealthMetricUnified.user_id == current_user.id
    ).scalar() or 0
    
    # Metrics by source type
    source_counts = db.query(
        HealthMetricUnified.source_type,
        func.count(HealthMetricUnified.id).label('count')
    ).filter(
        HealthMetricUnified.user_id == current_user.id
    ).group_by(HealthMetricUnified.source_type).all()
    
    # Recent activity (last 7 days)
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    recent_metrics = db.query(func.count(HealthMetricUnified.id)).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.created_at >= seven_days_ago
        )
    ).scalar() or 0
    
    # Data date range
    date_range = db.query(
        func.min(HealthMetricUnified.recorded_at).label('earliest'),
        func.max(HealthMetricUnified.recorded_at).label('latest')
    ).filter(
        HealthMetricUnified.user_id == current_user.id
    ).first()
    
    return {
        "total_metrics": total_metrics,
        "recent_metrics_7_days": recent_metrics,
        "source_breakdown": {source.source_type: source.count for source in source_counts},
        "data_date_range": {
            "earliest": date_range.earliest.isoformat() if date_range.earliest else None,
            "latest": date_range.latest.isoformat() if date_range.latest else None
        },
        "account_age_days": (datetime.utcnow() - current_user.created_at).days if current_user.created_at else 0
    } 