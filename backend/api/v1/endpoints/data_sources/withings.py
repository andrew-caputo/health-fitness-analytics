from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from datetime import datetime

from backend.api.deps import get_db, get_current_user
from backend.core.withings.client import WithingsClient
from backend.core.withings.sync import WithingsSyncService
from backend.core.withings.models import WithingsTokenData
from backend.core.withings.state import oauth_state_manager
from backend.core.models import DataSourceConnection, User, DataSyncLog

router = APIRouter()
client = WithingsClient()

@router.get("/auth")
async def get_auth_url(request: Request, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """Get Withings OAuth2 authorization URL."""
    # Generate secure state parameter
    state = oauth_state_manager.generate_state(str(current_user.id))
    
    auth_url = client.get_authorization_url(state)
    return {"auth_url": auth_url, "state": state}

@router.get("/callback")
async def oauth_callback(code: str, state: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """Handle OAuth2 callback from Withings."""
    # Verify state parameter
    if not oauth_state_manager.verify_state(state, str(current_user.id)):
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired state parameter"
        )
    
    try:
        # Exchange code for token
        token_data = await client.exchange_code_for_token(code)
        
        # Get user info
        user_info = await client.get_user_info(token_data["access_token"])
        
        # Create or update connection
        connection = (
            db.query(DataSourceConnection)
            .filter(
                DataSourceConnection.user_id == current_user.id,
                DataSourceConnection.source_type == "withings"
            )
            .first()
        )
        
        if not connection:
            connection = DataSourceConnection(
                user_id=current_user.id,
                source_type="withings",
                access_token=token_data["access_token"],
                refresh_token=token_data["refresh_token"],
                token_expires_at=datetime.fromtimestamp(
                    datetime.utcnow().timestamp() + token_data["expires_in"]
                ),
                status="connected",
                meta={"user_id": user_info["body"]["userid"]}
            )
            db.add(connection)
        else:
            connection.access_token = token_data["access_token"]
            connection.refresh_token = token_data["refresh_token"]
            connection.token_expires_at = datetime.fromtimestamp(
                datetime.utcnow().timestamp() + token_data["expires_in"]
            )
            connection.status = "connected"
        
        db.commit()
        
        return {
            "message": "Successfully connected Withings account",
            "connection_id": connection.id
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Failed to connect Withings account: {str(e)}"
        )

@router.post("/sync/{connection_id}")
async def sync_data(connection_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """Trigger data synchronization for a Withings connection."""
    connection = (
        db.query(DataSourceConnection)
        .filter(
            DataSourceConnection.id == connection_id,
            DataSourceConnection.user_id == current_user.id,
            DataSourceConnection.source_type == "withings"
        )
        .first()
    )
    
    if not connection:
        raise HTTPException(
            status_code=404,
            detail="Withings connection not found"
        )
    
    sync_service = WithingsSyncService(db)
    sync_log = await sync_service.sync_connection(connection)
    
    return {
        "message": "Sync started",
        "sync_id": sync_log.id,
        "status": sync_log.status
    }

@router.get("/sync/{connection_id}/status")
async def get_sync_status(connection_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """Get the status of the latest sync for a Withings connection."""
    connection = (
        db.query(DataSourceConnection)
        .filter(
            DataSourceConnection.id == connection_id,
            DataSourceConnection.user_id == current_user.id,
            DataSourceConnection.source_type == "withings"
        )
        .first()
    )
    
    if not connection:
        raise HTTPException(
            status_code=404,
            detail="Withings connection not found"
        )
    
    sync_log = (
        db.query(DataSyncLog)
        .filter(DataSyncLog.connection_id == connection_id)
        .order_by(DataSyncLog.start_time.desc())
        .first()
    )
    
    if not sync_log:
        raise HTTPException(
            status_code=404,
            detail="No sync found for this connection"
        )
    
    return {
        "sync_id": sync_log.id,
        "status": sync_log.status,
        "started_at": sync_log.start_time,
        "completed_at": sync_log.end_time,
        "metrics_synced": sync_log.metrics_synced,
        "error_message": sync_log.error_message
    } 