print("Loaded goals endpoints")
from typing import Any, List
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from backend.api.deps import get_current_active_user, get_db
from backend.core.models import User, UserGoal, HealthMetric
from backend.core.schemas import UserGoal as UserGoalSchema
from backend.core.schemas import UserGoalCreate, UserGoalUpdate

router = APIRouter()

def calculate_goal_progress(
    db: Session,
    goal: UserGoal,
    current_user: User
) -> float:
    """
    Calculate progress for a goal based on health metrics.
    """
    # Get relevant health metrics for the goal
    metrics = db.query(HealthMetric).filter(
        HealthMetric.user_id == current_user.id,
        HealthMetric.metric_type == goal.goal_type,
        HealthMetric.timestamp >= goal.start_date,
        HealthMetric.timestamp <= goal.end_date
    ).all()

    if not metrics:
        return 0.0

    # Calculate progress based on goal type
    if goal.goal_type in ["weight", "body_fat"]:
        # For weight and body fat, we want to see a decrease
        start_value = metrics[0].value
        current_value = metrics[-1].value
        target_value = goal.target_value
        
        if start_value == target_value:
            return 100.0
        
        progress = ((start_value - current_value) / (start_value - target_value)) * 100
        return max(0.0, min(100.0, progress))
    
    elif goal.goal_type in ["steps", "calories_burned", "workout_duration"]:
        # For cumulative metrics, we want to see an increase
        total_value = sum(metric.value for metric in metrics)
        progress = (total_value / goal.target_value) * 100
        return max(0.0, min(100.0, progress))
    
    return 0.0

@router.post("/", response_model=UserGoalSchema)
def create_goal(goal_in: UserGoalCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Create new goal.
    """
    # Validate dates
    if goal_in.end_date <= goal_in.start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End date must be after start date",
        )
    
    # Check for overlapping goals
    overlapping_goal = db.query(UserGoal).filter(
        UserGoal.user_id == current_user.id,
        UserGoal.goal_type == goal_in.goal_type,
        or_(
            and_(
                UserGoal.start_date <= goal_in.start_date,
                UserGoal.end_date >= goal_in.start_date
            ),
            and_(
                UserGoal.start_date <= goal_in.end_date,
                UserGoal.end_date >= goal_in.end_date
            )
        )
    ).first()
    
    if overlapping_goal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Overlapping goal of the same type exists",
        )
    
    goal = UserGoal(
        **goal_in.model_dump(),
        user_id=current_user.id,
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return goal

@router.get("/", response_model=List[UserGoalSchema])
def read_goals(skip: int = 0, limit: int = 100, goal_type: str = None, status: str = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Retrieve goals with optional filtering.
    """
    query = db.query(UserGoal).filter(UserGoal.user_id == current_user.id)
    
    if goal_type:
        query = query.filter(UserGoal.goal_type == goal_type)
    
    if status == "active":
        query = query.filter(UserGoal.end_date >= datetime.utcnow())
    elif status == "completed":
        query = query.filter(UserGoal.end_date < datetime.utcnow())
    
    goals = query.offset(skip).limit(limit).all()
    return goals

@router.get("/{goal_id}", response_model=UserGoalSchema)
def read_goal(goal_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Get goal by ID.
    """
    goal = db.query(UserGoal).filter(
        UserGoal.id == goal_id,
        UserGoal.user_id == current_user.id
    ).first()
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    return goal

@router.put("/{goal_id}", response_model=UserGoalSchema)
def update_goal(goal_id: str, goal_in: UserGoalUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Update goal.
    """
    goal = db.query(UserGoal).filter(
        UserGoal.id == goal_id,
        UserGoal.user_id == current_user.id
    ).first()
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    
    # Validate dates
    if goal_in.end_date <= goal_in.start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End date must be after start date",
        )
    
    # Check for overlapping goals (excluding current goal)
    overlapping_goal = db.query(UserGoal).filter(
        UserGoal.user_id == current_user.id,
        UserGoal.goal_type == goal_in.goal_type,
        UserGoal.id != goal_id,
        or_(
            and_(
                UserGoal.start_date <= goal_in.start_date,
                UserGoal.end_date >= goal_in.start_date
            ),
            and_(
                UserGoal.start_date <= goal_in.end_date,
                UserGoal.end_date >= goal_in.end_date
            )
        )
    ).first()
    
    if overlapping_goal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Overlapping goal of the same type exists",
        )
    
    for field, value in goal_in.model_dump(exclude_unset=True).items():
        setattr(goal, field, value)
    
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return goal

@router.delete("/{goal_id}", response_model=UserGoalSchema)
def delete_goal(goal_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Delete goal.
    """
    goal = db.query(UserGoal).filter(
        UserGoal.id == goal_id,
        UserGoal.user_id == current_user.id
    ).first()
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    
    db.delete(goal)
    db.commit()
    return goal

@router.get("/progress/{goal_id}")
def get_goal_progress(goal_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_active_user)) -> Any:
    """
    Get goal progress.
    """
    goal = db.query(UserGoal).filter(
        UserGoal.id == goal_id,
        UserGoal.user_id == current_user.id
    ).first()
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    
    progress = calculate_goal_progress(db, goal, current_user)
    return {
        "goal_id": goal.id,
        "progress": progress,
        "is_completed": progress >= 100.0
    } 