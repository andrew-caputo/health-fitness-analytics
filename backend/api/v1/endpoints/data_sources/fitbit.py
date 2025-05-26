from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import asyncio
import httpx
import secrets
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.models import User, DataSourceConnection, HealthMetricUnified
from backend.api.deps import get_current_user
from backend.core.schemas import (
    DataSourceConnection as DataSourceConnectionSchema,
    HealthMetricUnified as HealthMetricUnifiedSchema
)
from backend.core.config import settings

router = APIRouter()

# Fitbit API configuration
FITBIT_CLIENT_ID = settings.FITBIT_CLIENT_ID
FITBIT_CLIENT_SECRET = settings.FITBIT_CLIENT_SECRET
FITBIT_REDIRECT_URI = settings.FITBIT_REDIRECT_URI
FITBIT_BASE_URL = "https://api.fitbit.com"
FITBIT_AUTH_URL = "https://www.fitbit.com/oauth2/authorize"
FITBIT_TOKEN_URL = "https://api.fitbit.com/oauth2/token"

# Fitbit API scopes
FITBIT_SCOPES = [
    "activity",
    "heartrate", 
    "location",
    "nutrition",
    "profile",
    "settings",
    "sleep",
    "social",
    "weight"
]

@router.get("/auth/url")
async def get_fitbit_auth_url(
    current_user: User = Depends(get_current_user)
) -> Dict[str, str]:
    """Generate Fitbit OAuth2 authorization URL"""
    
    if not FITBIT_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Fitbit client ID not configured"
        )
    
    # Generate secure state parameter
    state = f"{secrets.token_urlsafe(32)}:{current_user.id}"
    
    # Build authorization URL
    auth_params = {
        "client_id": FITBIT_CLIENT_ID,
        "response_type": "code",
        "scope": " ".join(FITBIT_SCOPES),
        "redirect_uri": FITBIT_REDIRECT_URI,
        "state": state,
        "expires_in": "31536000"  # 1 year
    }
    
    auth_url = f"{FITBIT_AUTH_URL}?{urlencode(auth_params)}"
    
    return {
        "auth_url": auth_url,
        "state": state
    }

@router.post("/auth/callback")
async def fitbit_auth_callback(
    code: str,
    state: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Handle Fitbit OAuth2 callback and exchange code for tokens"""
    
    # Verify state parameter
    if not state or ":" not in state:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid state parameter"
        )
    
    state_token, user_id_str = state.split(":", 1)
    if str(current_user.id) != user_id_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="State parameter mismatch"
        )
    
    # Exchange authorization code for access token
    token_data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": FITBIT_REDIRECT_URI,
        "client_id": FITBIT_CLIENT_ID,
        "client_secret": FITBIT_CLIENT_SECRET
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                FITBIT_TOKEN_URL,
                data=token_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            token_response = response.json()
        except httpx.HTTPError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Failed to exchange code for token: {str(e)}"
            )
    
    # Extract tokens
    access_token = token_response.get("access_token")
    refresh_token = token_response.get("refresh_token")
    expires_in = token_response.get("expires_in", 28800)  # 8 hours default
    user_id = token_response.get("user_id")
    
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No access token received from Fitbit"
        )
    
    # Calculate token expiration
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    
    # Check if connection already exists
    existing_connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fitbit"
    ).first()
    
    if existing_connection:
        # Update existing connection
        existing_connection.access_token = access_token
        existing_connection.refresh_token = refresh_token
        existing_connection.token_expires_at = expires_at
        existing_connection.status = "connected"
        existing_connection.error_message = None
        existing_connection.meta = {"fitbit_user_id": user_id}
        existing_connection.updated_at = datetime.utcnow()
        connection = existing_connection
    else:
        # Create new connection
        connection = DataSourceConnection(
            user_id=current_user.id,
            source_type="fitbit",
            access_token=access_token,
            refresh_token=refresh_token,
            token_expires_at=expires_at,
            status="connected",
            meta={"fitbit_user_id": user_id},
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(connection)
    
    db.commit()
    db.refresh(connection)
    
    # Start background sync
    background_tasks.add_task(sync_fitbit_data, str(connection.id), db)
    
    return {
        "message": "Successfully connected Fitbit account",
        "connection_id": str(connection.id),
        "fitbit_user_id": user_id
    }

@router.post("/sync/{connection_id}")
async def trigger_fitbit_sync(
    connection_id: str,
    background_tasks: BackgroundTasks,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Trigger manual Fitbit data sync"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fitbit"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fitbit connection not found"
        )
    
    # Parse dates if provided
    start_dt = None
    end_dt = None
    if start_date:
        try:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid start_date format. Use ISO format."
            )
    
    if end_date:
        try:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid end_date format. Use ISO format."
            )
    
    # Start background sync
    background_tasks.add_task(sync_fitbit_data, connection_id, db, start_dt, end_dt)
    
    return {
        "message": "Fitbit sync started",
        "connection_id": connection_id
    }

@router.get("/data/{connection_id}")
async def get_fitbit_data(
    connection_id: str,
    limit: int = 100,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[HealthMetricUnifiedSchema]:
    """Get synced Fitbit data"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fitbit"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fitbit connection not found"
        )
    
    # Get unified health metrics for this user from Fitbit
    metrics = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.data_source == "fitbit"
    ).order_by(
        HealthMetricUnified.timestamp.desc()
    ).offset(offset).limit(limit).all()
    
    return metrics

@router.delete("/connection/{connection_id}")
async def disconnect_fitbit(
    connection_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect Fitbit account"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fitbit"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fitbit connection not found"
        )
    
    # Revoke token with Fitbit (optional)
    if connection.access_token:
        try:
            async with httpx.AsyncClient() as client:
                await client.post(
                    "https://api.fitbit.com/oauth2/revoke",
                    data={"token": connection.access_token},
                    headers={
                        "Authorization": f"Basic {FITBIT_CLIENT_ID}:{FITBIT_CLIENT_SECRET}",
                        "Content-Type": "application/x-www-form-urlencoded"
                    }
                )
        except:
            pass  # Continue even if revocation fails
    
    # Update connection status
    connection.status = "disconnected"
    connection.access_token = None
    connection.refresh_token = None
    connection.token_expires_at = None
    connection.updated_at = datetime.utcnow()
    
    db.commit()
    
    return {"message": "Fitbit account disconnected successfully"}

async def sync_fitbit_data(
    connection_id: str, 
    db: Session, 
    start_date: Optional[datetime] = None, 
    end_date: Optional[datetime] = None
):
    """Background task to sync Fitbit data"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id
    ).first()
    
    if not connection:
        return
    
    try:
        # Set default date range (last 30 days)
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()
        
        # Check if token needs refresh
        if connection.token_expires_at and connection.token_expires_at <= datetime.utcnow():
            await refresh_fitbit_token(connection, db)
        
        # Sync different data types
        await sync_fitbit_activities(connection, db, start_date, end_date)
        await sync_fitbit_sleep(connection, db, start_date, end_date)
        await sync_fitbit_body_composition(connection, db, start_date, end_date)
        
        # Update connection status
        connection.last_sync_at = datetime.utcnow()
        connection.status = "connected"
        connection.error_message = None
        
    except Exception as e:
        # Update connection with error
        connection.status = "error"
        connection.error_message = str(e)
    
    finally:
        db.commit()

async def refresh_fitbit_token(connection: DataSourceConnection, db: Session):
    """Refresh Fitbit access token"""
    
    if not connection.refresh_token:
        raise Exception("No refresh token available")
    
    token_data = {
        "grant_type": "refresh_token",
        "refresh_token": connection.refresh_token,
        "client_id": FITBIT_CLIENT_ID,
        "client_secret": FITBIT_CLIENT_SECRET
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            FITBIT_TOKEN_URL,
            data=token_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        response.raise_for_status()
        token_response = response.json()
    
    # Update connection with new tokens
    connection.access_token = token_response["access_token"]
    if "refresh_token" in token_response:
        connection.refresh_token = token_response["refresh_token"]
    
    expires_in = token_response.get("expires_in", 28800)
    connection.token_expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    connection.updated_at = datetime.utcnow()
    
    db.commit()

async def sync_fitbit_activities(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync Fitbit activity data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Sync daily activity summaries
    current_date = start_date.date()
    end_date_only = end_date.date()
    
    async with httpx.AsyncClient() as client:
        while current_date <= end_date_only:
            date_str = current_date.strftime("%Y-%m-%d")
            
            try:
                # Get daily activity summary
                response = await client.get(
                    f"{FITBIT_BASE_URL}/1/user/-/activities/date/{date_str}.json",
                    headers=headers
                )
                response.raise_for_status()
                data = response.json()
                
                # Process activity data
                summary = data.get("summary", {})
                
                # Create timestamp for the day
                day_timestamp = datetime.combine(current_date, datetime.min.time())
                
                # Activity metrics to sync
                activity_metrics = [
                    ("steps", summary.get("steps", 0), "count"),
                    ("distance", summary.get("distances", [{}])[0].get("distance", 0), "km"),
                    ("calories_burned", summary.get("caloriesOut", 0), "kcal"),
                    ("active_minutes", summary.get("fairlyActiveMinutes", 0) + summary.get("veryActiveMinutes", 0), "minutes"),
                    ("floors", summary.get("floors", 0), "count"),
                    ("elevation", summary.get("elevation", 0), "meters")
                ]
                
                for metric_type, value, unit in activity_metrics:
                    if value and value > 0:
                        # Check if metric already exists
                        existing = db.query(HealthMetricUnified).filter(
                            HealthMetricUnified.user_id == connection.user_id,
                            HealthMetricUnified.data_source == "fitbit",
                            HealthMetricUnified.metric_type == metric_type,
                            HealthMetricUnified.timestamp == day_timestamp
                        ).first()
                        
                        if not existing:
                            metric = HealthMetricUnified(
                                user_id=connection.user_id,
                                metric_type=metric_type,
                                category="activity",
                                value=float(value),
                                unit=unit,
                                timestamp=day_timestamp,
                                data_source="fitbit",
                                quality_score=0.9,  # High quality for Fitbit data
                                is_primary=False,
                                source_specific_data={
                                    "fitbit_summary": summary,
                                    "date": date_str
                                },
                                created_at=datetime.utcnow()
                            )
                            db.add(metric)
                
                # Commit daily data
                db.commit()
                
            except httpx.HTTPError as e:
                if e.response.status_code == 429:  # Rate limit
                    await asyncio.sleep(60)  # Wait 1 minute
                    continue
                else:
                    raise
            
            current_date += timedelta(days=1)

async def sync_fitbit_sleep(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync Fitbit sleep data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Sync sleep data
    current_date = start_date.date()
    end_date_only = end_date.date()
    
    async with httpx.AsyncClient() as client:
        while current_date <= end_date_only:
            date_str = current_date.strftime("%Y-%m-%d")
            
            try:
                # Get sleep data for the date
                response = await client.get(
                    f"{FITBIT_BASE_URL}/1.2/user/-/sleep/date/{date_str}.json",
                    headers=headers
                )
                response.raise_for_status()
                data = response.json()
                
                # Process sleep data
                sleep_logs = data.get("sleep", [])
                
                for sleep_log in sleep_logs:
                    if sleep_log.get("isMainSleep", True):  # Only main sleep
                        sleep_start = datetime.fromisoformat(
                            sleep_log["startTime"].replace("Z", "+00:00")
                        )
                        
                        # Sleep metrics to sync
                        sleep_metrics = [
                            ("sleep_duration", sleep_log.get("duration", 0) / 1000 / 60, "minutes"),  # Convert ms to minutes
                            ("sleep_efficiency", sleep_log.get("efficiency", 0), "percent"),
                            ("time_in_bed", sleep_log.get("timeInBed", 0), "minutes"),
                            ("minutes_asleep", sleep_log.get("minutesAsleep", 0), "minutes"),
                            ("minutes_awake", sleep_log.get("minutesAwake", 0), "minutes"),
                            ("awake_count", sleep_log.get("awakeCount", 0), "count"),
                            ("restless_count", sleep_log.get("restlessCount", 0), "count")
                        ]
                        
                        # Add sleep stage data if available
                        levels = sleep_log.get("levels", {})
                        if "summary" in levels:
                            summary = levels["summary"]
                            sleep_metrics.extend([
                                ("deep_sleep_minutes", summary.get("deep", {}).get("minutes", 0), "minutes"),
                                ("light_sleep_minutes", summary.get("light", {}).get("minutes", 0), "minutes"),
                                ("rem_sleep_minutes", summary.get("rem", {}).get("minutes", 0), "minutes"),
                                ("wake_minutes", summary.get("wake", {}).get("minutes", 0), "minutes")
                            ])
                        
                        for metric_type, value, unit in sleep_metrics:
                            if value and value > 0:
                                # Check if metric already exists
                                existing = db.query(HealthMetricUnified).filter(
                                    HealthMetricUnified.user_id == connection.user_id,
                                    HealthMetricUnified.data_source == "fitbit",
                                    HealthMetricUnified.metric_type == metric_type,
                                    HealthMetricUnified.timestamp == sleep_start
                                ).first()
                                
                                if not existing:
                                    metric = HealthMetricUnified(
                                        user_id=connection.user_id,
                                        metric_type=metric_type,
                                        category="sleep",
                                        value=float(value),
                                        unit=unit,
                                        timestamp=sleep_start,
                                        data_source="fitbit",
                                        quality_score=0.9,
                                        is_primary=False,
                                        source_specific_data={
                                            "fitbit_sleep_log": sleep_log,
                                            "date": date_str
                                        },
                                        created_at=datetime.utcnow()
                                    )
                                    db.add(metric)
                
                # Commit daily data
                db.commit()
                
            except httpx.HTTPError as e:
                if e.response.status_code == 429:  # Rate limit
                    await asyncio.sleep(60)  # Wait 1 minute
                    continue
                else:
                    raise
            
            current_date += timedelta(days=1)

async def sync_fitbit_body_composition(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync Fitbit body composition data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Body composition metrics to sync
    body_metrics = [
        ("weight", "kg"),
        ("fat", "percent"),
        ("bmi", "count")
    ]
    
    async with httpx.AsyncClient() as client:
        for metric_name, unit in body_metrics:
            try:
                # Get body composition data
                start_str = start_date.strftime("%Y-%m-%d")
                end_str = end_date.strftime("%Y-%m-%d")
                
                response = await client.get(
                    f"{FITBIT_BASE_URL}/1/user/-/body/{metric_name}/date/{start_str}/{end_str}.json",
                    headers=headers
                )
                response.raise_for_status()
                data = response.json()
                
                # Process body composition data
                measurements = data.get(f"body-{metric_name}", [])
                
                for measurement in measurements:
                    timestamp = datetime.strptime(measurement["date"], "%Y-%m-%d")
                    value = float(measurement["value"])
                    
                    # Check if metric already exists
                    existing = db.query(HealthMetricUnified).filter(
                        HealthMetricUnified.user_id == connection.user_id,
                        HealthMetricUnified.data_source == "fitbit",
                        HealthMetricUnified.metric_type == metric_name,
                        HealthMetricUnified.timestamp == timestamp
                    ).first()
                    
                    if not existing:
                        metric = HealthMetricUnified(
                            user_id=connection.user_id,
                            metric_type=metric_name,
                            category="body_composition",
                            value=value,
                            unit=unit,
                            timestamp=timestamp,
                            data_source="fitbit",
                            quality_score=0.9,
                            is_primary=False,
                            source_specific_data={
                                "fitbit_measurement": measurement
                            },
                            created_at=datetime.utcnow()
                        )
                        db.add(metric)
                
                # Commit metric data
                db.commit()
                
            except httpx.HTTPError as e:
                if e.response.status_code == 429:  # Rate limit
                    await asyncio.sleep(60)  # Wait 1 minute
                    continue
                elif e.response.status_code == 404:  # No data available
                    continue
                else:
                    raise 