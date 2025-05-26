import pytest
import time
from uuid import uuid4
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime, timedelta
from fastapi.testclient import TestClient

from backend.core.withings.client import WithingsClient
from backend.core.withings.sync import WithingsSyncService
from backend.core.withings.state import OAuthStateManager
from backend.core.models import DataSourceConnection, DataSyncLog, HealthMetric, WithingsMeasurement, User


class TestWithingsClient:
    """Test Withings API client."""
    
    def test_get_authorization_url(self):
        """Test OAuth authorization URL generation."""
        client = WithingsClient()
        state = "test_state_123"
        
        url = client.get_authorization_url(state)
        
        assert "account.withings.com/oauth2_user/authorize2" in url
        assert f"state={state}" in url
        assert "client_id=" in url
        assert "redirect_uri=" in url
        assert "scope=" in url

    @pytest.mark.asyncio
    async def test_exchange_code_for_token(self):
        """Test OAuth code exchange."""
        client = WithingsClient()
        
        mock_response = {
            "access_token": "test_access_token",
            "refresh_token": "test_refresh_token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        
        mock_http_response = MagicMock()
        mock_http_response.json.return_value = mock_response
        mock_http_response.raise_for_status = MagicMock()
        
        with patch("httpx.AsyncClient") as mock_client:
            mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_http_response)
            
            result = await client.exchange_code_for_token("test_code")
            
            assert result["access_token"] == "test_access_token"
            assert result["refresh_token"] == "test_refresh_token"


class TestOAuthStateManager:
    """Test OAuth state management."""
    
    def test_generate_and_verify_state(self):
        """Test state generation and verification."""
        manager = OAuthStateManager()
        user_id = "test_user_123"
        
        # Generate state
        state = manager.generate_state(user_id)
        assert len(state) == 32
        
        # Verify state
        assert manager.verify_state(state, user_id) is True
        
        # State should be marked as used
        assert manager.verify_state(state, user_id) is False
    
    def test_verify_invalid_state(self):
        """Test verification of invalid state."""
        manager = OAuthStateManager()
        
        # Non-existent state
        assert manager.verify_state("invalid_state", "user_123") is False
        
        # Wrong user
        state = manager.generate_state("user_123")
        assert manager.verify_state(state, "user_456") is False


class TestWithingsSyncService:
    """Test Withings data synchronization."""
    
    @pytest.mark.asyncio
    async def test_sync_measurements(self, db_session):
        """Test measurement synchronization."""
        # Create test user first
        test_user = User(
            email="test@example.com",
            hashed_password="hashed_password"
        )
        db_session.add(test_user)
        db_session.commit()
        
        # Create test connection
        connection = DataSourceConnection(
            user_id=test_user.id,
            source_type="withings",
            access_token="test_token",
            refresh_token="test_refresh",
            token_expires_at=datetime.utcnow() + timedelta(hours=1),
            status="connected"
        )
        db_session.add(connection)
        db_session.commit()
        
        sync_service = WithingsSyncService(db_session)
        
        # Mock API response
        mock_response = {
            "body": {
                "measuregrps": [
                    {
                        "date": 1640995200,
                        "deviceid": "test_device",
                        "measures": [
                            {
                                "type": 1,  # weight
                                "value": 75000,
                                "unit": -3
                            }
                        ]
                    }
                ]
            }
        }
        
        with patch.object(sync_service.client, 'get_measurements', return_value=mock_response):
            count = await sync_service._sync_measurements(
                connection,
                "test_token",
                datetime(2022, 1, 1),
                datetime(2022, 1, 2)
            )
            
            assert count == 1
            
            # Check database records
            withings_measurement = db_session.query(WithingsMeasurement).first()
            assert withings_measurement is not None
            assert withings_measurement.type == "weight"
            assert withings_measurement.value == 75.0
            
            health_metric = db_session.query(HealthMetric).first()
            assert health_metric is not None
            assert health_metric.metric_type == "weight"
            assert health_metric.source == "withings" 