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

# WHOOP API configuration
WHOOP_CLIENT_ID = settings.WHOOP_CLIENT_ID
WHOOP_CLIENT_SECRET = settings.WHOOP_CLIENT_SECRET
WHOOP_REDIRECT_URI = settings.WHOOP_REDIRECT_URI
WHOOP_BASE_URL = "https://api.prod.whoop.com/developer/v1"
WHOOP_AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth"
WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token"

# WHOOP API scopes
WHOOP_SCOPES = [
    "read:recovery",
    "read:cycles", 
    "read:workout",
    "read:sleep",
    "read:profile",
    "read:body_measurement",
    "offline"  # Required for refresh tokens
]

@router.get("/auth/url")
async def get_whoop_auth_url(
    current_user: User = Depends(get_current_user)
) -> Dict[str, str]:
    """Generate WHOOP OAuth2 authorization URL"""
    
    if not WHOOP_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="WHOOP client ID not configured"
        )
    
    # Generate secure state parameter (8 characters as required by WHOOP)
    state = f"{secrets.token_urlsafe(6)}:{current_user.id}"
    
    # Build authorization URL
    auth_params = {
        "client_id": WHOOP_CLIENT_ID,
        "response_type": "code",
        "scope": " ".join(WHOOP_SCOPES),
        "redirect_uri": WHOOP_REDIRECT_URI,
        "state": state
    }
    
    auth_url = f"{WHOOP_AUTH_URL}?{urlencode(auth_params)}"
    
    return {
        "auth_url": auth_url,
        "state": state
    }

@router.post("/auth/callback")
async def whoop_auth_callback(
    code: str,
    state: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Handle WHOOP OAuth2 callback and exchange code for tokens"""
    
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
        "redirect_uri": WHOOP_REDIRECT_URI,
        "client_id": WHOOP_CLIENT_ID,
        "client_secret": WHOOP_CLIENT_SECRET,
        "scope": " ".join(WHOOP_SCOPES)
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                WHOOP_TOKEN_URL,
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
    expires_in = token_response.get("expires_in", 3600)  # 1 hour default
    
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No access token received from WHOOP"
        )
    
    # Get user profile to store user ID
    user_profile = None
    try:
        async with httpx.AsyncClient() as client:
            profile_response = await client.get(
                f"{WHOOP_BASE_URL}/user/profile/basic",
                headers={"Authorization": f"Bearer {access_token}"}
            )
            profile_response.raise_for_status()
            user_profile = profile_response.json()
    except:
        pass  # Continue without profile if it fails
    
    # Calculate token expiration
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    
    # Check if connection already exists
    existing_connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "whoop"
    ).first()
    
    if existing_connection:
        # Update existing connection
        existing_connection.access_token = access_token
        existing_connection.refresh_token = refresh_token
        existing_connection.token_expires_at = expires_at
        existing_connection.status = "connected"
        existing_connection.error_message = None
        existing_connection.meta = {"whoop_user_id": user_profile.get("user_id") if user_profile else None}
        existing_connection.updated_at = datetime.utcnow()
        connection = existing_connection
    else:
        # Create new connection
        connection = DataSourceConnection(
            user_id=current_user.id,
            source_type="whoop",
            access_token=access_token,
            refresh_token=refresh_token,
            token_expires_at=expires_at,
            status="connected",
            meta={"whoop_user_id": user_profile.get("user_id") if user_profile else None},
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(connection)
    
    db.commit()
    db.refresh(connection)
    
    # Start background sync
    background_tasks.add_task(sync_whoop_data, str(connection.id), db)
    
    return {
        "message": "Successfully connected WHOOP account",
        "connection_id": str(connection.id),
        "whoop_user_id": user_profile.get("user_id") if user_profile else None
    }

@router.post("/sync/{connection_id}")
async def trigger_whoop_sync(
    connection_id: str,
    background_tasks: BackgroundTasks,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Trigger manual WHOOP data sync"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "whoop"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WHOOP connection not found"
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
    background_tasks.add_task(sync_whoop_data, connection_id, db, start_dt, end_dt)
    
    return {
        "message": "WHOOP sync started",
        "connection_id": connection_id
    }

@router.get("/data/{connection_id}")
async def get_whoop_data(
    connection_id: str,
    limit: int = 100,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[HealthMetricUnifiedSchema]:
    """Get synced WHOOP data"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "whoop"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WHOOP connection not found"
        )
    
    # Get unified health metrics for this user from WHOOP
    metrics = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.data_source == "whoop"
    ).order_by(
        HealthMetricUnified.timestamp.desc()
    ).offset(offset).limit(limit).all()
    
    return metrics

@router.delete("/connection/{connection_id}")
async def disconnect_whoop(
    connection_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect WHOOP account"""
    
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.id == connection_id,
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "whoop"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="WHOOP connection not found"
        )
    
    # Revoke token with WHOOP
    if connection.access_token:
        try:
            async with httpx.AsyncClient() as client:
                await client.delete(
                    f"{WHOOP_BASE_URL}/user/access",
                    headers={"Authorization": f"Bearer {connection.access_token}"}
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
    
    return {"message": "WHOOP account disconnected successfully"}

async def sync_whoop_data(
    connection_id: str, 
    db: Session, 
    start_date: Optional[datetime] = None, 
    end_date: Optional[datetime] = None
):
    """Background task to sync WHOOP data"""
    
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
            await refresh_whoop_token(connection, db)
        
        # Sync different data types
        await sync_whoop_cycles(connection, db, start_date, end_date)
        await sync_whoop_recovery(connection, db, start_date, end_date)
        await sync_whoop_sleep(connection, db, start_date, end_date)
        await sync_whoop_workouts(connection, db, start_date, end_date)
        await sync_whoop_body_measurements(connection, db)
        
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

async def refresh_whoop_token(connection: DataSourceConnection, db: Session):
    """Refresh WHOOP access token"""
    
    if not connection.refresh_token:
        raise Exception("No refresh token available")
    
    token_data = {
        "grant_type": "refresh_token",
        "refresh_token": connection.refresh_token,
        "client_id": WHOOP_CLIENT_ID,
        "client_secret": WHOOP_CLIENT_SECRET,
        "scope": "offline"
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            WHOOP_TOKEN_URL,
            data=token_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        response.raise_for_status()
        token_response = response.json()
    
    # Update connection with new tokens
    connection.access_token = token_response["access_token"]
    if "refresh_token" in token_response:
        connection.refresh_token = token_response["refresh_token"]
    
    expires_in = token_response.get("expires_in", 3600)
    connection.token_expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
    connection.updated_at = datetime.utcnow()
    
    db.commit()

async def sync_whoop_cycles(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync WHOOP cycle data (strain, heart rate, calories)"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Format dates for WHOOP API
    start_str = start_date.isoformat()
    end_str = end_date.isoformat()
    
    async with httpx.AsyncClient() as client:
        try:
            # Get cycles with pagination
            next_token = None
            while True:
                params = {
                    "start": start_str,
                    "end": end_str,
                    "limit": 25
                }
                if next_token:
                    params["nextToken"] = next_token
                
                response = await client.get(
                    f"{WHOOP_BASE_URL}/cycle",
                    headers=headers,
                    params=params
                )
                response.raise_for_status()
                data = response.json()
                
                # Process cycle data
                for cycle in data.get("records", []):
                    if cycle.get("score_state") == "SCORED" and cycle.get("score"):
                        cycle_start = datetime.fromisoformat(
                            cycle["start"].replace("Z", "+00:00")
                        )
                        
                        score = cycle["score"]
                        
                        # Cycle metrics to sync
                        cycle_metrics = [
                            ("strain_score", score.get("strain", 0), "score"),
                            ("calories_burned", score.get("kilojoule", 0) * 0.239006, "kcal"),  # Convert kJ to kcal
                            ("average_heart_rate", score.get("average_heart_rate", 0), "bpm"),
                            ("max_heart_rate", score.get("max_heart_rate", 0), "bpm")
                        ]
                        
                        for metric_type, value, unit in cycle_metrics:
                            if value and value > 0:
                                # Check if metric already exists
                                existing = db.query(HealthMetricUnified).filter(
                                    HealthMetricUnified.user_id == connection.user_id,
                                    HealthMetricUnified.data_source == "whoop",
                                    HealthMetricUnified.metric_type == metric_type,
                                    HealthMetricUnified.timestamp == cycle_start
                                ).first()
                                
                                if not existing:
                                    metric = HealthMetricUnified(
                                        user_id=connection.user_id,
                                        metric_type=metric_type,
                                        category="activity",
                                        value=float(value),
                                        unit=unit,
                                        timestamp=cycle_start,
                                        data_source="whoop",
                                        quality_score=0.95,  # High quality for WHOOP data
                                        is_primary=False,
                                        source_specific_data={
                                            "whoop_cycle": cycle,
                                            "cycle_id": cycle["id"]
                                        },
                                        created_at=datetime.utcnow()
                                    )
                                    db.add(metric)
                
                # Check for next page
                next_token = data.get("next_token")
                if not next_token:
                    break
                
                # Commit batch
                db.commit()
                
        except httpx.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                await asyncio.sleep(60)  # Wait 1 minute
            else:
                raise

async def sync_whoop_recovery(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync WHOOP recovery data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Format dates for WHOOP API
    start_str = start_date.isoformat()
    end_str = end_date.isoformat()
    
    async with httpx.AsyncClient() as client:
        try:
            # Get recovery data with pagination
            next_token = None
            while True:
                params = {
                    "start": start_str,
                    "end": end_str,
                    "limit": 25
                }
                if next_token:
                    params["nextToken"] = next_token
                
                response = await client.get(
                    f"{WHOOP_BASE_URL}/recovery",
                    headers=headers,
                    params=params
                )
                response.raise_for_status()
                data = response.json()
                
                # Process recovery data
                for recovery in data.get("records", []):
                    if recovery.get("score_state") == "SCORED" and recovery.get("score"):
                        recovery_timestamp = datetime.fromisoformat(
                            recovery["created_at"].replace("Z", "+00:00")
                        )
                        
                        score = recovery["score"]
                        
                        # Recovery metrics to sync
                        recovery_metrics = [
                            ("recovery_score", score.get("recovery_score", 0), "score"),
                            ("resting_heart_rate", score.get("resting_heart_rate", 0), "bpm"),
                            ("hrv_rmssd", score.get("hrv_rmssd_milli", 0), "ms"),
                            ("spo2_percentage", score.get("spo2_percentage", 0), "percent"),
                            ("skin_temp_celsius", score.get("skin_temp_celsius", 0), "celsius")
                        ]
                        
                        for metric_type, value, unit in recovery_metrics:
                            if value and value > 0:
                                # Check if metric already exists
                                existing = db.query(HealthMetricUnified).filter(
                                    HealthMetricUnified.user_id == connection.user_id,
                                    HealthMetricUnified.data_source == "whoop",
                                    HealthMetricUnified.metric_type == metric_type,
                                    HealthMetricUnified.timestamp == recovery_timestamp
                                ).first()
                                
                                if not existing:
                                    metric = HealthMetricUnified(
                                        user_id=connection.user_id,
                                        metric_type=metric_type,
                                        category="sleep",  # Recovery is sleep-related
                                        value=float(value),
                                        unit=unit,
                                        timestamp=recovery_timestamp,
                                        data_source="whoop",
                                        quality_score=0.95,
                                        is_primary=False,
                                        source_specific_data={
                                            "whoop_recovery": recovery,
                                            "cycle_id": recovery.get("cycle_id"),
                                            "sleep_id": recovery.get("sleep_id")
                                        },
                                        created_at=datetime.utcnow()
                                    )
                                    db.add(metric)
                
                # Check for next page
                next_token = data.get("next_token")
                if not next_token:
                    break
                
                # Commit batch
                db.commit()
                
        except httpx.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                await asyncio.sleep(60)  # Wait 1 minute
            else:
                raise

async def sync_whoop_sleep(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync WHOOP sleep data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Format dates for WHOOP API
    start_str = start_date.isoformat()
    end_str = end_date.isoformat()
    
    async with httpx.AsyncClient() as client:
        try:
            # Get sleep data with pagination
            next_token = None
            while True:
                params = {
                    "start": start_str,
                    "end": end_str,
                    "limit": 25
                }
                if next_token:
                    params["nextToken"] = next_token
                
                response = await client.get(
                    f"{WHOOP_BASE_URL}/activity/sleep",
                    headers=headers,
                    params=params
                )
                response.raise_for_status()
                data = response.json()
                
                # Process sleep data
                for sleep in data.get("records", []):
                    if not sleep.get("nap", False) and sleep.get("score_state") == "SCORED" and sleep.get("score"):
                        sleep_start = datetime.fromisoformat(
                            sleep["start"].replace("Z", "+00:00")
                        )
                        
                        score = sleep["score"]
                        stage_summary = score.get("stage_summary", {})
                        
                        # Sleep metrics to sync
                        sleep_metrics = [
                            ("sleep_performance_percentage", score.get("sleep_performance_percentage", 0), "percent"),
                            ("sleep_consistency_percentage", score.get("sleep_consistency_percentage", 0), "percent"),
                            ("sleep_efficiency_percentage", score.get("sleep_efficiency_percentage", 0), "percent"),
                            ("respiratory_rate", score.get("respiratory_rate", 0), "breaths_per_minute"),
                            ("total_in_bed_time", stage_summary.get("total_in_bed_time_milli", 0) / 1000 / 60, "minutes"),
                            ("total_awake_time", stage_summary.get("total_awake_time_milli", 0) / 1000 / 60, "minutes"),
                            ("total_light_sleep_time", stage_summary.get("total_light_sleep_time_milli", 0) / 1000 / 60, "minutes"),
                            ("total_slow_wave_sleep_time", stage_summary.get("total_slow_wave_sleep_time_milli", 0) / 1000 / 60, "minutes"),
                            ("total_rem_sleep_time", stage_summary.get("total_rem_sleep_time_milli", 0) / 1000 / 60, "minutes"),
                            ("sleep_cycle_count", stage_summary.get("sleep_cycle_count", 0), "count"),
                            ("disturbance_count", stage_summary.get("disturbance_count", 0), "count")
                        ]
                        
                        for metric_type, value, unit in sleep_metrics:
                            if value and value > 0:
                                # Check if metric already exists
                                existing = db.query(HealthMetricUnified).filter(
                                    HealthMetricUnified.user_id == connection.user_id,
                                    HealthMetricUnified.data_source == "whoop",
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
                                        data_source="whoop",
                                        quality_score=0.95,
                                        is_primary=False,
                                        source_specific_data={
                                            "whoop_sleep": sleep,
                                            "sleep_id": sleep["id"]
                                        },
                                        created_at=datetime.utcnow()
                                    )
                                    db.add(metric)
                
                # Check for next page
                next_token = data.get("next_token")
                if not next_token:
                    break
                
                # Commit batch
                db.commit()
                
        except httpx.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                await asyncio.sleep(60)  # Wait 1 minute
            else:
                raise

async def sync_whoop_workouts(
    connection: DataSourceConnection,
    db: Session,
    start_date: datetime,
    end_date: datetime
):
    """Sync WHOOP workout data"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    # Format dates for WHOOP API
    start_str = start_date.isoformat()
    end_str = end_date.isoformat()
    
    async with httpx.AsyncClient() as client:
        try:
            # Get workout data with pagination
            next_token = None
            while True:
                params = {
                    "start": start_str,
                    "end": end_str,
                    "limit": 25
                }
                if next_token:
                    params["nextToken"] = next_token
                
                response = await client.get(
                    f"{WHOOP_BASE_URL}/activity/workout",
                    headers=headers,
                    params=params
                )
                response.raise_for_status()
                data = response.json()
                
                # Process workout data
                for workout in data.get("records", []):
                    if workout.get("score_state") == "SCORED" and workout.get("score"):
                        workout_start = datetime.fromisoformat(
                            workout["start"].replace("Z", "+00:00")
                        )
                        
                        score = workout["score"]
                        
                        # Workout metrics to sync
                        workout_metrics = [
                            ("workout_strain", score.get("strain", 0), "score"),
                            ("workout_average_heart_rate", score.get("average_heart_rate", 0), "bpm"),
                            ("workout_max_heart_rate", score.get("max_heart_rate", 0), "bpm"),
                            ("workout_calories", score.get("kilojoule", 0) * 0.239006, "kcal"),  # Convert kJ to kcal
                            ("workout_distance", score.get("distance_meter", 0) / 1000, "km"),  # Convert m to km
                            ("workout_altitude_gain", score.get("altitude_gain_meter", 0), "meters"),
                            ("workout_percent_recorded", score.get("percent_recorded", 0), "percent")
                        ]
                        
                        for metric_type, value, unit in workout_metrics:
                            if value and value > 0:
                                # Check if metric already exists
                                existing = db.query(HealthMetricUnified).filter(
                                    HealthMetricUnified.user_id == connection.user_id,
                                    HealthMetricUnified.data_source == "whoop",
                                    HealthMetricUnified.metric_type == metric_type,
                                    HealthMetricUnified.timestamp == workout_start
                                ).first()
                                
                                if not existing:
                                    metric = HealthMetricUnified(
                                        user_id=connection.user_id,
                                        metric_type=metric_type,
                                        category="activity",
                                        value=float(value),
                                        unit=unit,
                                        timestamp=workout_start,
                                        data_source="whoop",
                                        quality_score=0.95,
                                        is_primary=False,
                                        source_specific_data={
                                            "whoop_workout": workout,
                                            "workout_id": workout["id"],
                                            "sport_id": workout.get("sport_id")
                                        },
                                        created_at=datetime.utcnow()
                                    )
                                    db.add(metric)
                
                # Check for next page
                next_token = data.get("next_token")
                if not next_token:
                    break
                
                # Commit batch
                db.commit()
                
        except httpx.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                await asyncio.sleep(60)  # Wait 1 minute
            else:
                raise

async def sync_whoop_body_measurements(
    connection: DataSourceConnection,
    db: Session
):
    """Sync WHOOP body measurements"""
    
    headers = {
        "Authorization": f"Bearer {connection.access_token}",
        "Accept": "application/json"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            # Get body measurements
            response = await client.get(
                f"{WHOOP_BASE_URL}/user/measurement/body",
                headers=headers
            )
            response.raise_for_status()
            data = response.json()
            
            # Current timestamp for body measurements
            timestamp = datetime.utcnow()
            
            # Body measurement metrics to sync
            body_metrics = [
                ("height", data.get("height_meter", 0) * 100, "cm"),  # Convert m to cm
                ("weight", data.get("weight_kilogram", 0), "kg"),
                ("max_heart_rate", data.get("max_heart_rate", 0), "bpm")
            ]
            
            for metric_type, value, unit in body_metrics:
                if value and value > 0:
                    # Check if metric already exists (for today)
                    today_start = timestamp.replace(hour=0, minute=0, second=0, microsecond=0)
                    existing = db.query(HealthMetricUnified).filter(
                        HealthMetricUnified.user_id == connection.user_id,
                        HealthMetricUnified.data_source == "whoop",
                        HealthMetricUnified.metric_type == metric_type,
                        HealthMetricUnified.timestamp >= today_start
                    ).first()
                    
                    if not existing:
                        metric = HealthMetricUnified(
                            user_id=connection.user_id,
                            metric_type=metric_type,
                            category="body_composition",
                            value=float(value),
                            unit=unit,
                            timestamp=timestamp,
                            data_source="whoop",
                            quality_score=0.9,
                            is_primary=False,
                            source_specific_data={
                                "whoop_body_measurement": data
                            },
                            created_at=datetime.utcnow()
                        )
                        db.add(metric)
            
            # Commit body measurements
            db.commit()
            
        except httpx.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                await asyncio.sleep(60)  # Wait 1 minute
            elif e.response.status_code == 404:  # No data available
                pass
            else:
                raise 