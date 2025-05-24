from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_active_user, get_db
from backend.core.models import User, DataSourceConnection, DataSyncLog
from backend.core.schemas import DataSourceConnection as DataSourceConnectionSchema
from backend.core.schemas import DataSyncLog as DataSyncLogSchema
from backend.core.common import update_connection_status, create_sync_log, update_sync_log

router = APIRouter()

@router.get("/connections", response_model=List[DataSourceConnectionSchema])
def list_connections(current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)) -> Any:
    """
    List all data source connections for the current user.
    """
    connections = db.query(DataSourceConnection).filter(DataSourceConnection.user_id == current_user.id).all()
    return connections

@router.get("/connections/{source_type}", response_model=DataSourceConnectionSchema)
def get_connection(source_type: str, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)) -> Any:
    """
    Get a specific data source connection.
    """
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == source_type
    ).first()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No connection found for source type: {source_type}"
        )
    return connection

@router.delete("/connections/{source_type}", response_model=DataSourceConnectionSchema)
def disconnect_source(source_type: str, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)) -> Any:
    """
    Disconnect a data source.
    """
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == source_type
    ).first()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No connection found for source type: {source_type}"
        )
    
    update_connection_status(connection, "disconnected")
    return connection

@router.get("/sync-logs/{source_type}", response_model=List[DataSyncLogSchema])
def get_sync_logs(source_type: str, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)) -> Any:
    """
    Get sync logs for a data source.
    """
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == source_type
    ).first()
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No connection found for source type: {source_type}"
        )
    
    logs = db.query(DataSyncLog).filter(
        DataSyncLog.connection_id == connection.id
    ).order_by(DataSyncLog.created_at.desc()).all()
    return logs 