from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
import asyncio
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from pydantic import BaseModel, Field, validator
from sqlalchemy.orm import Session
from sqlalchemy import and_, desc

from backend.api.deps import get_db, get_current_user
from backend.core.models import User, HealthMetricUnified
from backend.core.schemas import HealthMetricUnified as HealthMetricUnifiedSchema

router = APIRouter()

# Pydantic models for HealthKit data
class HealthKitMetric(BaseModel):
    metric_type: str = Field(..., description="Type of health metric (e.g., 'activity_steps', 'heart_rate')")
    value: float = Field(..., description="Numeric value of the metric")
    unit: str = Field(..., description="Unit of measurement (e.g., 'steps', 'bpm', 'kg')")
    source_type: str = Field(default="healthkit", description="Always 'healthkit' for mobile data")
    recorded_at: datetime = Field(..., description="When the metric was recorded")
    source_app: Optional[str] = Field(None, description="Source app name (e.g., 'MyFitnessPal', 'Nike Run Club')")
    device_name: Optional[str] = Field(None, description="Device name that recorded the metric")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata from HealthKit")
    
    @validator('metric_type')
    def validate_metric_type(cls, v):
        allowed_types = {
            # Activity & Fitness
            'activity_steps', 'activity_distance', 'activity_calories', 'activity_exercise_time',
            'workout_duration', 'workout_calories', 'workout_distance',
            # Body Measurements
            'body_weight', 'body_height', 'body_bmi', 'body_fat_percentage',
            # Heart Health
            'heart_rate', 'heart_rate_variability', 'resting_heart_rate',
            # Nutrition
            'nutrition_calories', 'nutrition_carbohydrates', 'nutrition_protein',
            'nutrition_fat', 'nutrition_fiber', 'nutrition_sugar',
            # Sleep
            'sleep_duration',
            # Mindfulness
            'mindfulness_duration'
        }
        if v not in allowed_types:
            raise ValueError(f'Invalid metric_type. Must be one of: {", ".join(allowed_types)}')
        return v

class HealthKitBatchUpload(BaseModel):
    metrics: List[HealthKitMetric] = Field(..., description="List of health metrics to upload")
    device_info: Optional[Dict[str, str]] = Field(None, description="Device information (iOS version, app version, etc.)")
    sync_timestamp: datetime = Field(default_factory=datetime.utcnow, description="When this sync was initiated")
    
    @validator('metrics')
    def validate_metrics_not_empty(cls, v):
        if not v:
            raise ValueError('Metrics list cannot be empty')
        if len(v) > 1000:  # Reasonable batch size limit
            raise ValueError('Batch size cannot exceed 1000 metrics')
        return v

class SyncStatus(BaseModel):
    status: str = Field(..., description="Sync status: 'success', 'partial', 'failed'")
    processed_count: int = Field(..., description="Number of metrics successfully processed")
    failed_count: int = Field(..., description="Number of metrics that failed to process")
    last_sync: Optional[datetime] = Field(None, description="Last successful sync timestamp")
    next_sync_recommended: Optional[datetime] = Field(None, description="Recommended time for next sync")
    errors: Optional[List[str]] = Field(None, description="List of error messages if any")

@router.post("/batch-upload", response_model=Dict[str, Any])
async def batch_upload_healthkit_data(
    upload_data: HealthKitBatchUpload,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Batch upload HealthKit data from iOS app.
    Processes multiple health metrics in a single request for efficiency.
    """
    sync_id = str(uuid4())
    processed_count = 0
    failed_count = 0
    errors = []
    
    # Note: DataSyncLog requires connection_id for OAuth connections
    # For direct mobile HealthKit sync, we'll track sync internally for now
    
    try:
        # Process each metric
        for metric_data in upload_data.metrics:
            try:
                # Check for duplicate data (same metric type, value, and timestamp within 1 minute)
                existing_metric = db.query(HealthMetricUnified).filter(
                    and_(
                        HealthMetricUnified.user_id == current_user.id,
                        HealthMetricUnified.metric_type == metric_data.metric_type,
                        HealthMetricUnified.value == metric_data.value,
                        HealthMetricUnified.timestamp.between(
                            metric_data.recorded_at - timedelta(minutes=1),
                            metric_data.recorded_at + timedelta(minutes=1)
                        )
                    )
                ).first()
                
                if existing_metric:
                    # Update existing metric if new data has more metadata or newer source
                    current_source_data = existing_metric.source_specific_data or {}
                    if (metric_data.source_app and not current_source_data.get("source_app")) or \
                       (metric_data.metadata and not current_source_data.get("metadata")):
                        
                        updated_source_data = current_source_data.copy()
                        if metric_data.source_app:
                            updated_source_data["source_app"] = metric_data.source_app
                        if metric_data.device_name:
                            updated_source_data["device_name"] = metric_data.device_name
                        if metric_data.metadata:
                            updated_source_data["metadata"] = metric_data.metadata
                        
                        existing_metric.source_specific_data = updated_source_data
                        processed_count += 1
                    # Skip if duplicate
                    continue
                
                # Create new health metric
                health_metric = HealthMetricUnified(
                    user_id=current_user.id,
                    metric_type=metric_data.metric_type,
                    category=_get_category_from_metric_type(metric_data.metric_type),
                    value=metric_data.value,
                    unit=metric_data.unit,
                    timestamp=metric_data.recorded_at,
                    data_source=metric_data.source_type,
                    quality_score=0.9,  # High quality for HealthKit data
                    is_primary=True,
                    source_specific_data={
                        "source_app": metric_data.source_app,
                        "device_name": metric_data.device_name,
                        "metadata": metric_data.metadata
                    },
                    created_at=datetime.utcnow()
                )
                
                db.add(health_metric)
                processed_count += 1
                
            except Exception as e:
                failed_count += 1
                errors.append(f"Failed to process metric {metric_data.metric_type}: {str(e)}")
                continue
        
        # Commit all changes
        db.commit()
        
        # Schedule background analytics update
        background_tasks.add_task(update_user_analytics, current_user.id, db)
        
        return {
            "sync_id": sync_id,
            "status": "success" if failed_count == 0 else "partial",
            "processed_count": processed_count,
            "failed_count": failed_count,
            "total_count": len(upload_data.metrics),
            "errors": errors[:10] if errors else None,  # Limit error list
            "next_sync_recommended": datetime.utcnow() + timedelta(hours=1)
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch upload failed: {str(e)}"
        )

@router.get("/sync-status", response_model=SyncStatus)
async def get_sync_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SyncStatus:
    """
    Get current sync status for HealthKit data.
    Returns information about last sync and recommendations for next sync.
    """
    # Get HealthKit metrics count and last sync time
    healthkit_metrics = db.query(HealthMetricUnified).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.data_source == "healthkit"
        )
    ).all()
    
    if not healthkit_metrics:
        return SyncStatus(
            status="never_synced",
            processed_count=0,
            failed_count=0,
            next_sync_recommended=datetime.utcnow()
        )
    
    # Get last sync time from most recent HealthKit metric
    last_sync = max(metric.created_at for metric in healthkit_metrics)
    
    # Calculate next sync recommendation based on data frequency
    hours_since_sync = (datetime.utcnow() - last_sync).total_seconds() / 3600
    
    # Recommend sync every 4 hours for active users, 12 hours for less active
    if hours_since_sync < 4:
        next_sync = last_sync + timedelta(hours=4)
    else:
        next_sync = datetime.utcnow()
    
    return SyncStatus(
        status="completed",
        processed_count=len(healthkit_metrics),
        failed_count=0,
        last_sync=last_sync,
        next_sync_recommended=next_sync,
        errors=None
    )

@router.post("/sync", response_model=Dict[str, Any])
async def trigger_sync(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Trigger a manual sync process.
    This endpoint can be called by the iOS app to initiate data synchronization.
    """
    sync_id = str(uuid4())
    
    # For HealthKit, manual sync is just a signal to the app to upload data
    # The actual sync happens via the batch-upload endpoint
    
    return {
        "sync_id": sync_id,
        "status": "initiated",
        "message": "Manual sync initiated. Please upload HealthKit data via batch-upload endpoint."
    }

@router.get("/data", response_model=Dict[str, Any])
async def get_healthkit_data(
    metric_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Retrieve HealthKit data for the current user.
    Supports filtering by metric type and date range.
    """
    query = db.query(HealthMetricUnified).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.data_source == "healthkit"
        )
    )
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.timestamp >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.timestamp <= end_date)
    
    # Order by most recent first and apply limit
    metrics = query.order_by(desc(HealthMetricUnified.timestamp)).limit(limit).all()
    
    # Group by metric type for summary
    metric_summary = {}
    for metric in metrics:
        if metric.metric_type not in metric_summary:
            metric_summary[metric.metric_type] = {
                "count": 0,
                "latest_value": None,
                "latest_recorded_at": None,
                "source_apps": set()
            }
        
        summary = metric_summary[metric.metric_type]
        summary["count"] += 1
        
        if not summary["latest_recorded_at"] or metric.timestamp > summary["latest_recorded_at"]:
            summary["latest_value"] = metric.value
            summary["latest_recorded_at"] = metric.timestamp
        
        if metric.source_specific_data and metric.source_specific_data.get("source_app"):
            summary["source_apps"].add(metric.source_specific_data["source_app"])
    
    # Convert sets to lists for JSON serialization
    for summary in metric_summary.values():
        summary["source_apps"] = list(summary["source_apps"])
    
    return {
        "metrics": [
            {
                "id": metric.id,
                "metric_type": metric.metric_type,
                "value": metric.value,
                "unit": metric.unit,
                "recorded_at": metric.timestamp.isoformat(),
                "source_app": metric.source_specific_data.get("source_app") if metric.source_specific_data else None,
                "device_name": metric.source_specific_data.get("device_name") if metric.source_specific_data else None,
                "metadata": metric.source_specific_data.get("metadata") if metric.source_specific_data else None
            }
            for metric in metrics
        ],
        "summary": metric_summary,
        "total_count": len(metrics),
        "has_more": len(metrics) == limit
    }

@router.delete("/data", response_model=Dict[str, str])
async def delete_healthkit_data(
    metric_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict[str, str]:
    """
    Delete HealthKit data for the current user.
    Supports filtering by metric type and date range for selective deletion.
    """
    query = db.query(HealthMetricUnified).filter(
        and_(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.data_source == "healthkit"
        )
    )
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.timestamp >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.timestamp <= end_date)
    
    deleted_count = query.delete()
    db.commit()
    
    return {
        "message": f"Successfully deleted {deleted_count} HealthKit metrics",
        "deleted_count": str(deleted_count)
    }

# Background task functions
async def update_user_analytics(user_id: int, db: Session):
    """Background task to update user analytics after data sync"""
    try:
        # This would typically trigger analytics recalculation
        # For now, we'll just log the update
        print(f"Updating analytics for user {user_id}")
        # TODO: Implement analytics update logic
    except Exception as e:
        print(f"Failed to update analytics for user {user_id}: {str(e)}")

def _get_category_from_metric_type(metric_type: str) -> str:
    """Map metric type to category."""
    category_mapping = {
        # Activity & Fitness
        'activity_steps': 'activity',
        'activity_distance': 'activity', 
        'activity_calories': 'activity',
        'activity_exercise_time': 'activity',
        'workout_duration': 'activity',
        'workout_calories': 'activity',
        'workout_distance': 'activity',
        
        # Body Measurements
        'body_weight': 'body_composition',
        'body_height': 'body_composition',
        'body_bmi': 'body_composition',
        'body_fat_percentage': 'body_composition',
        
        # Heart Health
        'heart_rate': 'activity',
        'heart_rate_variability': 'activity',
        'resting_heart_rate': 'activity',
        
        # Nutrition
        'nutrition_calories': 'nutrition',
        'nutrition_carbohydrates': 'nutrition',
        'nutrition_protein': 'nutrition',
        'nutrition_fat': 'nutrition',
        'nutrition_fiber': 'nutrition',
        'nutrition_sugar': 'nutrition',
        
        # Sleep
        'sleep_duration': 'sleep',
        
        # Mindfulness
        'mindfulness_duration': 'activity'
    }
    
    return category_mapping.get(metric_type, 'activity')  # Default to activity 