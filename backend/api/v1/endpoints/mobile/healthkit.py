from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
import asyncio
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from pydantic import BaseModel, Field, validator
from sqlalchemy.orm import Session
from sqlalchemy import and_, desc

from backend.api.deps import get_db, get_current_user
from backend.core.models import User, HealthMetricUnified, DataSyncLog
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
    
    # Create sync log entry
    sync_log = DataSyncLog(
        user_id=current_user.id,
        source_type="healthkit",
        sync_id=sync_id,
        status="processing",
        started_at=datetime.utcnow(),
        total_records=len(upload_data.metrics)
    )
    db.add(sync_log)
    db.commit()
    
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
                        HealthMetricUnified.recorded_at.between(
                            metric_data.recorded_at - timedelta(minutes=1),
                            metric_data.recorded_at + timedelta(minutes=1)
                        )
                    )
                ).first()
                
                if existing_metric:
                    # Update existing metric if new data has more metadata or newer source
                    if (metric_data.source_app and not existing_metric.source_app) or \
                       (metric_data.metadata and not existing_metric.metadata):
                        existing_metric.source_app = metric_data.source_app or existing_metric.source_app
                        existing_metric.device_name = metric_data.device_name or existing_metric.device_name
                        existing_metric.metadata = metric_data.metadata or existing_metric.metadata
                        existing_metric.updated_at = datetime.utcnow()
                        processed_count += 1
                    # Skip if duplicate
                    continue
                
                # Create new health metric
                health_metric = HealthMetricUnified(
                    user_id=current_user.id,
                    metric_type=metric_data.metric_type,
                    value=metric_data.value,
                    unit=metric_data.unit,
                    source_type=metric_data.source_type,
                    recorded_at=metric_data.recorded_at,
                    source_app=metric_data.source_app,
                    device_name=metric_data.device_name,
                    metadata=metric_data.metadata,
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
        
        # Update sync log
        sync_log.status = "completed" if failed_count == 0 else "partial"
        sync_log.completed_at = datetime.utcnow()
        sync_log.processed_records = processed_count
        sync_log.failed_records = failed_count
        sync_log.error_details = errors if errors else None
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
        # Update sync log with failure
        sync_log.status = "failed"
        sync_log.completed_at = datetime.utcnow()
        sync_log.error_details = [str(e)]
        db.commit()
        
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
    # Get latest sync log
    latest_sync = db.query(DataSyncLog).filter(
        and_(
            DataSyncLog.user_id == current_user.id,
            DataSyncLog.source_type == "healthkit"
        )
    ).order_by(desc(DataSyncLog.started_at)).first()
    
    if not latest_sync:
        return SyncStatus(
            status="never_synced",
            processed_count=0,
            failed_count=0,
            next_sync_recommended=datetime.utcnow()
        )
    
    # Calculate next sync recommendation based on data frequency
    last_sync_time = latest_sync.completed_at or latest_sync.started_at
    hours_since_sync = (datetime.utcnow() - last_sync_time).total_seconds() / 3600
    
    # Recommend sync every 4 hours for active users, 12 hours for less active
    if hours_since_sync < 4:
        next_sync = last_sync_time + timedelta(hours=4)
    else:
        next_sync = datetime.utcnow()
    
    return SyncStatus(
        status=latest_sync.status,
        processed_count=latest_sync.processed_records or 0,
        failed_count=latest_sync.failed_records or 0,
        last_sync=latest_sync.completed_at,
        next_sync_recommended=next_sync,
        errors=latest_sync.error_details[:5] if latest_sync.error_details else None
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
    
    # Create sync log entry
    sync_log = DataSyncLog(
        user_id=current_user.id,
        source_type="healthkit",
        sync_id=sync_id,
        status="initiated",
        started_at=datetime.utcnow()
    )
    db.add(sync_log)
    db.commit()
    
    # Schedule background sync task
    background_tasks.add_task(process_manual_sync, current_user.id, sync_id, db)
    
    return {
        "sync_id": sync_id,
        "status": "initiated",
        "message": "Sync process started. Check sync status for updates."
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
            HealthMetricUnified.source_type == "healthkit"
        )
    )
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.recorded_at >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.recorded_at <= end_date)
    
    # Order by most recent first and apply limit
    metrics = query.order_by(desc(HealthMetricUnified.recorded_at)).limit(limit).all()
    
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
        
        if not summary["latest_recorded_at"] or metric.recorded_at > summary["latest_recorded_at"]:
            summary["latest_value"] = metric.value
            summary["latest_recorded_at"] = metric.recorded_at
        
        if metric.source_app:
            summary["source_apps"].add(metric.source_app)
    
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
                "recorded_at": metric.recorded_at.isoformat(),
                "source_app": metric.source_app,
                "device_name": metric.device_name,
                "metadata": metric.metadata
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
            HealthMetricUnified.source_type == "healthkit"
        )
    )
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.recorded_at >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.recorded_at <= end_date)
    
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

async def process_manual_sync(user_id: int, sync_id: str, db: Session):
    """Background task to process manual sync request"""
    try:
        # Update sync log
        sync_log = db.query(DataSyncLog).filter(DataSyncLog.sync_id == sync_id).first()
        if sync_log:
            sync_log.status = "completed"
            sync_log.completed_at = datetime.utcnow()
            db.commit()
        
        print(f"Manual sync completed for user {user_id}, sync_id: {sync_id}")
        # TODO: Implement actual sync logic if needed
    except Exception as e:
        print(f"Manual sync failed for user {user_id}: {str(e)}")
        
        # Update sync log with failure
        sync_log = db.query(DataSyncLog).filter(DataSyncLog.sync_id == sync_id).first()
        if sync_log:
            sync_log.status = "failed"
            sync_log.completed_at = datetime.utcnow()
            sync_log.error_details = [str(e)]
            db.commit() 