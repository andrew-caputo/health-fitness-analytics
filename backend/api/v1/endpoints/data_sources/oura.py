from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
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

# Oura API configuration
OURA_CLIENT_ID = settings.OURA_CLIENT_ID
OURA_CLIENT_SECRET = settings.OURA_CLIENT_SECRET
OURA_REDIRECT_URI = settings.OURA_REDIRECT_URI
OURA_BASE_URL = "https://api.ouraring.com"
OURA_AUTH_URL = "https://cloud.ouraring.com/oauth/authorize"
OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token"

# Oura data type mappings
OURA_ACTIVITY_MAPPINGS = {
    "steps": {"category": "activity", "metric_type": "steps", "unit": "count"},
    "active_calories": {"category": "activity", "metric_type": "active_energy", "unit": "kcal"},
    "total_calories": {"category": "activity", "metric_type": "total_energy", "unit": "kcal"},
    "distance": {"category": "activity", "metric_type": "distance", "unit": "meters"},
    "equivalent_walking_distance": {"category": "activity", "metric_type": "walking_distance", "unit": "meters"},
    "high_activity_met_minutes": {"category": "activity", "metric_type": "high_intensity_minutes", "unit": "minutes"},
    "medium_activity_met_minutes": {"category": "activity", "metric_type": "medium_intensity_minutes", "unit": "minutes"},
    "low_activity_met_minutes": {"category": "activity", "metric_type": "low_intensity_minutes", "unit": "minutes"},
    "non_wear_time": {"category": "activity", "metric_type": "non_wear_time", "unit": "minutes"},
    "resting_time": {"category": "activity", "metric_type": "resting_time", "unit": "minutes"},
    "sedentary_met_minutes": {"category": "activity", "metric_type": "sedentary_minutes", "unit": "minutes"},
    "average_met_minutes": {"category": "activity", "metric_type": "average_met", "unit": "met"}
}

OURA_SLEEP_MAPPINGS = {
    "total_sleep_duration": {"category": "sleep", "metric_type": "sleep_duration", "unit": "seconds"},
    "awake_time": {"category": "sleep", "metric_type": "awake_time", "unit": "seconds"},
    "light_sleep_duration": {"category": "sleep", "metric_type": "light_sleep", "unit": "seconds"},
    "deep_sleep_duration": {"category": "sleep", "metric_type": "deep_sleep", "unit": "seconds"},
    "rem_sleep_duration": {"category": "sleep", "metric_type": "rem_sleep", "unit": "seconds"},
    "sleep_efficiency": {"category": "sleep", "metric_type": "sleep_efficiency", "unit": "percent"},
    "sleep_latency": {"category": "sleep", "metric_type": "sleep_latency", "unit": "seconds"},
    "sleep_score": {"category": "sleep", "metric_type": "sleep_score", "unit": "score"},
    "restfulness": {"category": "sleep", "metric_type": "restfulness", "unit": "score"},
    "timing": {"category": "sleep", "metric_type": "sleep_timing", "unit": "score"},
    "total_bedtime": {"category": "sleep", "metric_type": "bedtime_duration", "unit": "seconds"},
    "time_in_bed": {"category": "sleep", "metric_type": "time_in_bed", "unit": "seconds"}
}

OURA_READINESS_MAPPINGS = {
    "score": {"category": "activity", "metric_type": "readiness_score", "unit": "score"},
    "temperature_deviation": {"category": "activity", "metric_type": "temperature_deviation", "unit": "celsius"},
    "activity_balance": {"category": "activity", "metric_type": "activity_balance", "unit": "score"},
    "body_battery": {"category": "activity", "metric_type": "body_battery", "unit": "score"},
    "hrv_balance": {"category": "activity", "metric_type": "hrv_balance", "unit": "score"},
    "previous_day_activity": {"category": "activity", "metric_type": "previous_day_activity", "unit": "score"},
    "previous_night": {"category": "activity", "metric_type": "previous_night_score", "unit": "score"},
    "recovery_index": {"category": "activity", "metric_type": "recovery_index", "unit": "score"},
    "resting_heart_rate": {"category": "activity", "metric_type": "resting_heart_rate", "unit": "bpm"},
    "sleep_balance": {"category": "activity", "metric_type": "sleep_balance", "unit": "score"}
}

@router.get("/auth/url")
async def get_oura_auth_url(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get Oura OAuth2 authorization URL"""
    
    # Generate state parameter for security
    state = secrets.token_urlsafe(32)
    
    # Store state in user session or database for verification
    # For now, we'll include user_id in state (in production, use proper session management)
    state_with_user = f"{state}:{current_user.id}"
    
    # Build authorization URL
    auth_params = {
        "client_id": OURA_CLIENT_ID,
        "response_type": "code",
        "scope": "daily heartrate workout tag session",
        "redirect_uri": OURA_REDIRECT_URI,
        "state": state_with_user
    }
    
    auth_url = f"{OURA_AUTH_URL}?{urlencode(auth_params)}"
    
    return {
        "auth_url": auth_url,
        "state": state_with_user
    }

@router.post("/auth/callback")
async def oura_auth_callback(
    code: str,
    state: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Handle Oura OAuth2 callback and exchange code for tokens"""
    
    # Verify state parameter (basic verification - in production, use proper session management)
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
        "redirect_uri": OURA_REDIRECT_URI,
        "client_id": OURA_CLIENT_ID,
        "client_secret": OURA_CLIENT_SECRET
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(OURA_TOKEN_URL, data=token_data)
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
    expires_in = token_response.get("expires_in", 3600)
    
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No access token received from Oura"
        )
    
    # Calculate token expiration
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    
    # Check if connection already exists
    existing_connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "oura"
    ).first()
    
    if existing_connection:
        # Update existing connection
        existing_connection.status = "connected"
        existing_connection.meta = {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "expires_at": expires_at.isoformat(),
            "token_type": token_response.get("token_type", "Bearer")
        }
        existing_connection.updated_at = datetime.utcnow()
        connection = existing_connection
    else:
        # Create new connection
        connection = DataSourceConnection(
            user_id=current_user.id,
            source_type="oura",
            status="connected",
            meta={
                "access_token": access_token,
                "refresh_token": refresh_token,
                "expires_at": expires_at.isoformat(),
                "token_type": token_response.get("token_type", "Bearer")
            },
            sync_frequency="daily",
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(connection)
    
    db.commit()
    db.refresh(connection)
    
    # Start initial data sync in background
    background_tasks.add_task(sync_oura_data, connection.id, db)
    
    return {
        "message": "Oura connected successfully",
        "connection_id": connection.id,
        "status": "connected"
    }

@router.post("/sync")
async def sync_oura_data_endpoint(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None
):
    """Manually trigger Oura data synchronization"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "oura",
        DataSourceConnection.status == "connected"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oura connection not found or not connected"
        )
    
    # Start sync in background
    background_tasks.add_task(
        sync_oura_data, 
        connection.id, 
        db, 
        start_date, 
        end_date
    )
    
    return {"message": "Oura data sync started"}

@router.get("/connection", response_model=DataSourceConnectionSchema)
async def get_oura_connection(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get Oura connection status"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "oura"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oura connection not found"
        )
    
    return connection

@router.delete("/connection")
async def disconnect_oura(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect Oura integration"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "oura"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Oura connection not found"
        )
    
    # Update connection status
    connection.status = "disconnected"
    connection.is_active = False
    connection.updated_at = datetime.utcnow()
    
    db.commit()
    
    return {"message": "Oura disconnected successfully"}

@router.get("/data", response_model=List[HealthMetricUnifiedSchema])
async def get_oura_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    category: Optional[str] = None,
    metric_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = 100
):
    """Get Oura health data for the current user"""
    
    query = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.data_source == "oura"
    )
    
    if category:
        query = query.filter(HealthMetricUnified.category == category)
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.timestamp >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.timestamp <= end_date)
    
    data = query.order_by(HealthMetricUnified.timestamp.desc()).limit(limit).all()
    
    return data

async def sync_oura_data(
    connection_id: str, 
    db: Session, 
    start_date: Optional[datetime] = None, 
    end_date: Optional[datetime] = None
):
    """Background task to sync Oura data"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id
    ).first()
    
    if not connection:
        return
    
    try:
        # Update sync status
        connection.last_sync_at = datetime.utcnow()
        db.commit()
        
        # Get access token
        access_token = connection.meta.get("access_token")
        if not access_token:
            raise Exception("No access token available")
        
        # Check if token needs refresh
        expires_at_str = connection.meta.get("expires_at")
        if expires_at_str:
            expires_at = datetime.fromisoformat(expires_at_str)
            if datetime.utcnow() >= expires_at - timedelta(minutes=5):
                # Refresh token
                await refresh_oura_token(connection, db)
                access_token = connection.meta.get("access_token")
        
        # Set date range (default to last 30 days)
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=30)
        if not end_date:
            end_date = datetime.utcnow()
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        async with httpx.AsyncClient() as client:
            # Sync daily activity data
            await sync_oura_daily_activity(client, headers, connection.user_id, start_date, end_date, db)
            
            # Sync sleep data
            await sync_oura_sleep(client, headers, connection.user_id, start_date, end_date, db)
            
            # Sync readiness data
            await sync_oura_readiness(client, headers, connection.user_id, start_date, end_date, db)
        
        # Update connection status
        connection.status = "connected"
        connection.error_message = None
        
    except Exception as e:
        # Update connection with error
        connection.status = "error"
        connection.error_message = str(e)
    
    finally:
        db.commit()

async def refresh_oura_token(connection: DataSourceConnection, db: Session):
    """Refresh Oura access token"""
    
    refresh_token = connection.meta.get("refresh_token")
    if not refresh_token:
        raise Exception("No refresh token available")
    
    token_data = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": OURA_CLIENT_ID,
        "client_secret": OURA_CLIENT_SECRET
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(OURA_TOKEN_URL, data=token_data)
        response.raise_for_status()
        token_response = response.json()
    
    # Update connection with new tokens
    access_token = token_response.get("access_token")
    new_refresh_token = token_response.get("refresh_token", refresh_token)
    expires_in = token_response.get("expires_in", 3600)
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    
    connection.meta.update({
        "access_token": access_token,
        "refresh_token": new_refresh_token,
        "expires_at": expires_at.isoformat()
    })
    
    db.commit()

async def sync_oura_daily_activity(
    client: httpx.AsyncClient, 
    headers: Dict[str, str], 
    user_id: str, 
    start_date: datetime, 
    end_date: datetime, 
    db: Session
):
    """Sync Oura daily activity data"""
    
    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")
    
    url = f"{OURA_BASE_URL}/v2/usercollection/daily_activity"
    params = {"start_date": start_str, "end_date": end_str}
    
    response = await client.get(url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    
    batch_records = []
    
    for activity_data in data.get("data", []):
        day_date = datetime.strptime(activity_data["day"], "%Y-%m-%d")
        
        for field, value in activity_data.items():
            if field in OURA_ACTIVITY_MAPPINGS and value is not None:
                mapping = OURA_ACTIVITY_MAPPINGS[field]
                
                metric = HealthMetricUnified(
                    user_id=user_id,
                    metric_type=mapping["metric_type"],
                    category=mapping["category"],
                    value=float(value),
                    unit=mapping["unit"],
                    timestamp=day_date,
                    data_source="oura",
                    quality_score=0.95,  # High quality for Oura data
                    is_primary=True,
                    source_specific_data={
                        "oura_field": field,
                        "day": activity_data["day"],
                        "score": activity_data.get("score"),
                        "contributors": activity_data.get("contributors", {})
                    },
                    created_at=datetime.utcnow()
                )
                
                batch_records.append(metric)
    
    if batch_records:
        db.add_all(batch_records)
        db.commit()

async def sync_oura_sleep(
    client: httpx.AsyncClient, 
    headers: Dict[str, str], 
    user_id: str, 
    start_date: datetime, 
    end_date: datetime, 
    db: Session
):
    """Sync Oura sleep data"""
    
    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")
    
    url = f"{OURA_BASE_URL}/v2/usercollection/daily_sleep"
    params = {"start_date": start_str, "end_date": end_str}
    
    response = await client.get(url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    
    batch_records = []
    
    for sleep_data in data.get("data", []):
        day_date = datetime.strptime(sleep_data["day"], "%Y-%m-%d")
        
        for field, value in sleep_data.items():
            if field in OURA_SLEEP_MAPPINGS and value is not None:
                mapping = OURA_SLEEP_MAPPINGS[field]
                
                metric = HealthMetricUnified(
                    user_id=user_id,
                    metric_type=mapping["metric_type"],
                    category=mapping["category"],
                    value=float(value),
                    unit=mapping["unit"],
                    timestamp=day_date,
                    data_source="oura",
                    quality_score=0.95,  # High quality for Oura data
                    is_primary=True,
                    source_specific_data={
                        "oura_field": field,
                        "day": sleep_data["day"],
                        "score": sleep_data.get("score"),
                        "contributors": sleep_data.get("contributors", {})
                    },
                    created_at=datetime.utcnow()
                )
                
                batch_records.append(metric)
    
    if batch_records:
        db.add_all(batch_records)
        db.commit()

async def sync_oura_readiness(
    client: httpx.AsyncClient, 
    headers: Dict[str, str], 
    user_id: str, 
    start_date: datetime, 
    end_date: datetime, 
    db: Session
):
    """Sync Oura readiness data"""
    
    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")
    
    url = f"{OURA_BASE_URL}/v2/usercollection/daily_readiness"
    params = {"start_date": start_str, "end_date": end_str}
    
    response = await client.get(url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()
    
    batch_records = []
    
    for readiness_data in data.get("data", []):
        day_date = datetime.strptime(readiness_data["day"], "%Y-%m-%d")
        
        for field, value in readiness_data.items():
            if field in OURA_READINESS_MAPPINGS and value is not None:
                mapping = OURA_READINESS_MAPPINGS[field]
                
                metric = HealthMetricUnified(
                    user_id=user_id,
                    metric_type=mapping["metric_type"],
                    category=mapping["category"],
                    value=float(value),
                    unit=mapping["unit"],
                    timestamp=day_date,
                    data_source="oura",
                    quality_score=0.95,  # High quality for Oura data
                    is_primary=True,
                    source_specific_data={
                        "oura_field": field,
                        "day": readiness_data["day"],
                        "score": readiness_data.get("score"),
                        "contributors": readiness_data.get("contributors", {})
                    },
                    created_at=datetime.utcnow()
                )
                
                batch_records.append(metric)
    
    if batch_records:
        db.add_all(batch_records)
        db.commit() 