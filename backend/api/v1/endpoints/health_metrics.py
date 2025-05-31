print("Loaded health_metrics endpoints")
from typing import Any, List
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_active_user, get_db
from backend.core.models import User, HealthMetric
from backend.core.schemas import HealthMetric as HealthMetricSchema
from backend.core.schemas import HealthMetricCreate, HealthMetricUpdate

router = APIRouter()

@router.post("/", response_model=HealthMetricSchema)
def create_health_metric(metric_in: HealthMetricCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Create new health metric.
    """
    metric = HealthMetric(
        **metric_in.model_dump(),
        user_id=current_user.id,
    )
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return metric

@router.get("/", response_model=List[HealthMetricSchema])
def read_health_metrics(skip: int = 0, limit: int = 100, metric_type: str = None, start_date: datetime = None, end_date: datetime = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Retrieve health metrics.
    """
    query = db.query(HealthMetric).filter(HealthMetric.user_id == current_user.id)
    
    if metric_type:
        query = query.filter(HealthMetric.metric_type == metric_type)
    if start_date:
        query = query.filter(HealthMetric.timestamp >= start_date)
    if end_date:
        query = query.filter(HealthMetric.timestamp <= end_date)
    
    metrics = query.offset(skip).limit(limit).all()
    return metrics

@router.get("/{metric_id}", response_model=HealthMetricSchema)
def read_health_metric(metric_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Get health metric by ID.
    """
    metric = db.query(HealthMetric).filter(
        HealthMetric.id == metric_id,
        HealthMetric.user_id == current_user.id
    ).first()
    if not metric:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health metric not found",
        )
    return metric

@router.put("/{metric_id}", response_model=HealthMetricSchema)
def update_health_metric(metric_id: str, metric_in: HealthMetricUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Update health metric.
    """
    metric = db.query(HealthMetric).filter(
        HealthMetric.id == metric_id,
        HealthMetric.user_id == current_user.id
    ).first()
    if not metric:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health metric not found",
        )
    
    for field, value in metric_in.model_dump(exclude_unset=True).items():
        setattr(metric, field, value)
    
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return metric

@router.delete("/{metric_id}", response_model=HealthMetricSchema)
def delete_health_metric(metric_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Delete health metric.
    """
    metric = db.query(HealthMetric).filter(
        HealthMetric.id == metric_id,
        HealthMetric.user_id == current_user.id
    ).first()
    if not metric:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health metric not found",
        )
    
    db.delete(metric)
    db.commit()
    return metric 