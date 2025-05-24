from datetime import datetime, timedelta
from typing import Dict, Optional

from cryptography.fernet import Fernet
from fastapi import HTTPException, status

from backend.core.database import get_db
from backend.core.models import DataSourceConnection, DataSyncLog

# TODO: Move to environment variables
ENCRYPTION_KEY = Fernet.generate_key()  # Change this in production
fernet = Fernet(ENCRYPTION_KEY)

class DataSourceError(Exception):
    """Base exception for data source errors."""
    pass

class AuthenticationError(DataSourceError):
    """Raised when authentication fails."""
    pass

class SyncError(DataSourceError):
    """Raised when data synchronization fails."""
    pass

def encrypt_token(token: str) -> str:
    """Encrypt a token for storage."""
    return fernet.encrypt(token.encode()).decode()

def decrypt_token(encrypted_token: str) -> str:
    """Decrypt a stored token."""
    return fernet.decrypt(encrypted_token.encode()).decode()

def update_connection_status(
    connection: DataSourceConnection,
    status: str,
    error_message: Optional[str] = None
) -> None:
    """Update the status of a data source connection."""
    connection.status = status
    connection.error_message = error_message
    connection.updated_at = datetime.utcnow()
    
    db = next(get_db())
    db.add(connection)
    db.commit()

def create_sync_log(connection_id: str) -> DataSyncLog:
    """Create a new sync log entry."""
    db = next(get_db())
    sync_log = DataSyncLog(
        connection_id=connection_id,
        status="in_progress"
    )
    db.add(sync_log)
    db.commit()
    db.refresh(sync_log)
    return sync_log

def update_sync_log(
    sync_log: DataSyncLog,
    status: str,
    error_message: Optional[str] = None,
    metrics_synced: Optional[Dict[str, int]] = None
) -> None:
    """Update a sync log entry."""
    sync_log.status = status
    sync_log.error_message = error_message
    sync_log.metrics_synced = metrics_synced
    sync_log.end_time = datetime.utcnow()
    
    db = next(get_db())
    db.add(sync_log)
    db.commit()

def get_connection(user_id: str, source_type: str) -> Optional[DataSourceConnection]:
    """Get a data source connection for a user."""
    db = next(get_db())
    return db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == user_id,
        DataSourceConnection.source_type == source_type
    ).first()

def validate_token_expiration(connection: DataSourceConnection) -> bool:
    """Check if a token is expired or about to expire."""
    if not connection.token_expires_at:
        return False
    
    # Consider token expired if it expires in less than 5 minutes
    return connection.token_expires_at <= datetime.utcnow() + timedelta(minutes=5)

def handle_data_source_error(error: DataSourceError) -> None:
    """Handle data source errors and raise appropriate HTTP exceptions."""
    if isinstance(error, AuthenticationError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(error)
        )
    elif isinstance(error, SyncError):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(error)
        )
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        ) 