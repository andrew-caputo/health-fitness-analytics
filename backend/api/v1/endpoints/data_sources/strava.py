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

# Strava API configuration
STRAVA_CLIENT_ID = settings.STRAVA_CLIENT_ID
STRAVA_CLIENT_SECRET = settings.STRAVA_CLIENT_SECRET
STRAVA_REDIRECT_URI = settings.STRAVA_REDIRECT_URI

# Strava API endpoints
STRAVA_AUTH_URL = "https://www.strava.com/oauth/authorize"
STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token"
STRAVA_API_BASE_URL = "https://www.strava.com/api/v3"

# Strava OAuth2 scopes
STRAVA_SCOPES = "activity:read_all,profile:read_all"

# Strava API rate limits (100 requests per 15 minutes, 1000 per day)
STRAVA_RATE_LIMIT_REQUESTS = 100
STRAVA_RATE_LIMIT_PERIOD = 900  # 15 minutes


@router.get("/auth/url")
async def get_auth_url(current_user: User = Depends(get_current_user)):
    """Generate Strava OAuth2 authorization URL"""
    state = secrets.token_urlsafe(32)
    
    params = {
        "client_id": STRAVA_CLIENT_ID,
        "redirect_uri": STRAVA_REDIRECT_URI,
        "response_type": "code",
        "scope": STRAVA_SCOPES,
        "state": state,
        "approval_prompt": "auto"
    }
    
    auth_url = f"{STRAVA_AUTH_URL}?{urlencode(params)}"
    
    return {
        "auth_url": auth_url,
        "state": state
    }


@router.post("/auth/callback")
async def auth_callback(
    code: str,
    state: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """Handle Strava OAuth2 callback and exchange code for tokens"""
    try:
        # Exchange authorization code for access token
        async with httpx.AsyncClient() as client:
            token_data = {
                "client_id": STRAVA_CLIENT_ID,
                "client_secret": STRAVA_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code"
            }
            
            response = await client.post(STRAVA_TOKEN_URL, data=token_data)
            response.raise_for_status()
            token_response = response.json()
        
        # Extract tokens and athlete info
        access_token = token_response["access_token"]
        refresh_token = token_response["refresh_token"]
        expires_at = datetime.fromtimestamp(token_response["expires_at"])
        athlete_info = token_response.get("athlete", {})
        
        # Check if connection already exists
        existing_connection = db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == current_user.id,
            DataSourceConnection.source_type == "strava"
        ).first()
        
        if existing_connection:
            # Update existing connection
            existing_connection.access_token = access_token
            existing_connection.refresh_token = refresh_token
            existing_connection.token_expires_at = expires_at
            existing_connection.is_active = True
            existing_connection.last_sync_at = datetime.utcnow()
            existing_connection.external_user_id = str(athlete_info.get("id", ""))
            existing_connection.connection_metadata = {
                "athlete_info": athlete_info,
                "scopes": STRAVA_SCOPES.split(","),
                "connected_at": datetime.utcnow().isoformat()
            }
            connection = existing_connection
        else:
            # Create new connection
            connection = DataSourceConnection(
                user_id=current_user.id,
                source_type="strava",
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=expires_at,
                is_active=True,
                last_sync_at=datetime.utcnow(),
                external_user_id=str(athlete_info.get("id", "")),
                connection_metadata={
                    "athlete_info": athlete_info,
                    "scopes": STRAVA_SCOPES.split(","),
                    "connected_at": datetime.utcnow().isoformat()
                }
            )
            db.add(connection)
        
        db.commit()
        db.refresh(connection)
        
        # Schedule background sync
        background_tasks.add_task(sync_strava_data, current_user.id, db)
        
        return {
            "message": "Strava connected successfully",
            "connection_id": connection.id,
            "athlete_info": athlete_info
        }
        
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to exchange authorization code: {e.response.text}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication failed: {str(e)}"
        )


@router.post("/sync")
async def sync_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """Manually trigger Strava data synchronization"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "strava",
        DataSourceConnection.is_active == True
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Strava connection not found"
        )
    
    # Schedule background sync
    background_tasks.add_task(sync_strava_data, current_user.id, db)
    
    return {"message": "Strava data sync initiated"}


@router.get("/data")
async def get_strava_data(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    metric_types: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve Strava data for the authenticated user"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "strava",
        DataSourceConnection.is_active == True
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Strava connection not found"
        )
    
    # Build query for health metrics
    query = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.source_type == "strava"
    )
    
    # Apply date filters
    if start_date:
        start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        query = query.filter(HealthMetricUnified.recorded_at >= start_dt)
    
    if end_date:
        end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
        query = query.filter(HealthMetricUnified.recorded_at <= end_dt)
    
    # Apply metric type filters
    if metric_types:
        types = [t.strip() for t in metric_types.split(',')]
        query = query.filter(HealthMetricUnified.metric_type.in_(types))
    
    metrics = query.order_by(HealthMetricUnified.recorded_at.desc()).all()
    
    return {
        "connection": {
            "id": connection.id,
            "connected_at": connection.created_at,
            "last_sync": connection.last_sync_at,
            "athlete_info": connection.connection_metadata.get("athlete_info", {})
        },
        "metrics": [
            {
                "id": metric.id,
                "metric_type": metric.metric_type,
                "value": metric.value,
                "unit": metric.unit,
                "recorded_at": metric.recorded_at,
                "metadata": metric.metadata
            }
            for metric in metrics
        ]
    }


@router.delete("/disconnect")
async def disconnect_strava(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect Strava integration"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "strava"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Strava connection not found"
        )
    
    try:
        # Revoke access token with Strava
        async with httpx.AsyncClient() as client:
            revoke_data = {
                "access_token": connection.access_token
            }
            await client.post("https://www.strava.com/oauth/deauthorize", data=revoke_data)
    except Exception:
        # Continue with disconnection even if revocation fails
        pass
    
    # Deactivate connection
    connection.is_active = False
    connection.access_token = None
    connection.refresh_token = None
    
    db.commit()
    
    return {"message": "Strava disconnected successfully"}


async def refresh_access_token(connection: DataSourceConnection, db: Session) -> bool:
    """Refresh Strava access token using refresh token"""
    try:
        async with httpx.AsyncClient() as client:
            refresh_data = {
                "client_id": STRAVA_CLIENT_ID,
                "client_secret": STRAVA_CLIENT_SECRET,
                "grant_type": "refresh_token",
                "refresh_token": connection.refresh_token
            }
            
            response = await client.post(STRAVA_TOKEN_URL, data=refresh_data)
            response.raise_for_status()
            token_data = response.json()
        
        # Update connection with new tokens
        connection.access_token = token_data["access_token"]
        connection.refresh_token = token_data["refresh_token"]
        connection.token_expires_at = datetime.fromtimestamp(token_data["expires_at"])
        
        db.commit()
        return True
        
    except Exception as e:
        print(f"Failed to refresh Strava token: {e}")
        return False


async def sync_strava_data(user_id: int, db: Session):
    """Background task to sync Strava data"""
    try:
        connection = db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == user_id,
            DataSourceConnection.source_type == "strava",
            DataSourceConnection.is_active == True
        ).first()
        
        if not connection:
            return
        
        # Check if token needs refresh
        if connection.token_expires_at and connection.token_expires_at <= datetime.utcnow():
            if not await refresh_access_token(connection, db):
                return
        
        # Sync activities data
        await sync_activities(connection, db)
        
        # Update last sync time
        connection.last_sync_at = datetime.utcnow()
        db.commit()
        
    except Exception as e:
        print(f"Strava sync failed for user {user_id}: {e}")


async def sync_activities(connection: DataSourceConnection, db: Session):
    """Sync Strava activities data"""
    try:
        headers = {"Authorization": f"Bearer {connection.access_token}"}
        
        # Get activities from the last 30 days
        after_timestamp = int((datetime.utcnow() - timedelta(days=30)).timestamp())
        
        async with httpx.AsyncClient() as client:
            # Handle rate limiting
            page = 1
            per_page = 50
            
            while True:
                params = {
                    "after": after_timestamp,
                    "page": page,
                    "per_page": per_page
                }
                
                response = await client.get(
                    f"{STRAVA_API_BASE_URL}/athlete/activities",
                    headers=headers,
                    params=params
                )
                
                if response.status_code == 429:
                    # Rate limited - wait and retry
                    await asyncio.sleep(60)
                    continue
                
                response.raise_for_status()
                activities = response.json()
                
                if not activities:
                    break
                
                # Process activities
                for activity in activities:
                    await process_activity(activity, connection, db)
                
                # Check if we got fewer results than requested (last page)
                if len(activities) < per_page:
                    break
                
                page += 1
                
                # Rate limiting - wait between requests
                await asyncio.sleep(1)
                
    except Exception as e:
        print(f"Failed to sync Strava activities: {e}")


async def process_activity(activity: Dict[str, Any], connection: DataSourceConnection, db: Session):
    """Process individual Strava activity"""
    try:
        activity_id = activity.get("id")
        start_date = datetime.fromisoformat(activity.get("start_date", "").replace('Z', '+00:00'))
        
        # Check if activity already exists
        existing = db.query(HealthMetricUnified).filter(
            HealthMetricUnified.user_id == connection.user_id,
            HealthMetricUnified.source_type == "strava",
            HealthMetricUnified.external_id == str(activity_id)
        ).first()
        
        if existing:
            return  # Skip if already processed
        
        # Extract activity metrics
        activity_type = activity.get("type", "").lower()
        distance = activity.get("distance", 0)  # meters
        moving_time = activity.get("moving_time", 0)  # seconds
        elapsed_time = activity.get("elapsed_time", 0)  # seconds
        total_elevation_gain = activity.get("total_elevation_gain", 0)  # meters
        average_speed = activity.get("average_speed", 0)  # m/s
        max_speed = activity.get("max_speed", 0)  # m/s
        calories = activity.get("calories", 0)
        average_heartrate = activity.get("average_heartrate")
        max_heartrate = activity.get("max_heartrate")
        average_watts = activity.get("average_watts")
        max_watts = activity.get("max_watts")
        
        # Create activity summary metric
        activity_metric = HealthMetricUnified(
            user_id=connection.user_id,
            source_type="strava",
            metric_type="activity",
            value=distance,
            unit="meters",
            recorded_at=start_date,
            external_id=str(activity_id),
            metadata={
                "activity_type": activity_type,
                "name": activity.get("name", ""),
                "distance": distance,
                "moving_time": moving_time,
                "elapsed_time": elapsed_time,
                "elevation_gain": total_elevation_gain,
                "average_speed": average_speed,
                "max_speed": max_speed,
                "calories": calories,
                "average_heartrate": average_heartrate,
                "max_heartrate": max_heartrate,
                "average_watts": average_watts,
                "max_watts": max_watts,
                "kudos_count": activity.get("kudos_count", 0),
                "achievement_count": activity.get("achievement_count", 0),
                "trainer": activity.get("trainer", False),
                "commute": activity.get("commute", False)
            }
        )
        db.add(activity_metric)
        
        # Create individual metrics for key data points
        if calories and calories > 0:
            calories_metric = HealthMetricUnified(
                user_id=connection.user_id,
                source_type="strava",
                metric_type="calories_burned",
                value=calories,
                unit="kcal",
                recorded_at=start_date,
                external_id=f"{activity_id}_calories",
                metadata={"activity_type": activity_type, "activity_name": activity.get("name", "")}
            )
            db.add(calories_metric)
        
        if average_heartrate:
            hr_metric = HealthMetricUnified(
                user_id=connection.user_id,
                source_type="strava",
                metric_type="heart_rate",
                value=average_heartrate,
                unit="bpm",
                recorded_at=start_date,
                external_id=f"{activity_id}_avg_hr",
                metadata={
                    "activity_type": activity_type,
                    "activity_name": activity.get("name", ""),
                    "measurement_type": "average",
                    "max_heartrate": max_heartrate
                }
            )
            db.add(hr_metric)
        
        if moving_time > 0:
            duration_metric = HealthMetricUnified(
                user_id=connection.user_id,
                source_type="strava",
                metric_type="exercise_duration",
                value=moving_time,
                unit="seconds",
                recorded_at=start_date,
                external_id=f"{activity_id}_duration",
                metadata={
                    "activity_type": activity_type,
                    "activity_name": activity.get("name", ""),
                    "elapsed_time": elapsed_time
                }
            )
            db.add(duration_metric)
        
        if average_watts:
            power_metric = HealthMetricUnified(
                user_id=connection.user_id,
                source_type="strava",
                metric_type="power",
                value=average_watts,
                unit="watts",
                recorded_at=start_date,
                external_id=f"{activity_id}_avg_power",
                metadata={
                    "activity_type": activity_type,
                    "activity_name": activity.get("name", ""),
                    "measurement_type": "average",
                    "max_watts": max_watts
                }
            )
            db.add(power_metric)
        
        db.commit()
        
    except Exception as e:
        print(f"Failed to process Strava activity {activity.get('id')}: {e}")
        db.rollback() 