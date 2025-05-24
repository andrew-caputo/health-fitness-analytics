import time
from datetime import datetime
from typing import Any, Dict, Optional

import httpx

from .config import (
    WITHINGS_API_BASE_URL,
    WITHINGS_AUTH_URL,
    WITHINGS_CLIENT_ID,
    WITHINGS_CLIENT_SECRET,
    WITHINGS_RATE_LIMITS,
    WITHINGS_REDIRECT_URI,
    WITHINGS_SCOPES,
    WITHINGS_TOKEN_URL,
)

class WithingsClient:
    def __init__(self):
        self.client_id = WITHINGS_CLIENT_ID
        self.client_secret = WITHINGS_CLIENT_SECRET
        self.redirect_uri = WITHINGS_REDIRECT_URI
        self.base_url = WITHINGS_API_BASE_URL
        self.auth_url = WITHINGS_AUTH_URL
        self.token_url = WITHINGS_TOKEN_URL
        self.scopes = WITHINGS_SCOPES
        self.rate_limits = WITHINGS_RATE_LIMITS
        self._last_request_time = 0
        self._request_count = 0
        self._request_window_start = time.time()

    def get_authorization_url(self, state: str) -> str:
        """Generate Withings OAuth2 authorization URL."""
        params = {
            "response_type": "code",
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "scope": " ".join(self.scopes),
            "state": state
        }
        query_string = "&".join(f"{k}={v}" for k, v in params.items())
        return f"{self.auth_url}?{query_string}"

    async def exchange_code_for_token(self, code: str) -> Dict[str, Any]:
        """Exchange authorization code for access token."""
        data = {
            "grant_type": "authorization_code",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "code": code,
            "redirect_uri": self.redirect_uri
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(self.token_url, data=data)
            response.raise_for_status()
            return response.json()

    async def refresh_token(self, refresh_token: str) -> Dict[str, Any]:
        """Refresh access token using refresh token."""
        data = {
            "grant_type": "refresh_token",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "refresh_token": refresh_token
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(self.token_url, data=data)
            response.raise_for_status()
            return response.json()

    async def _make_request(
        self,
        method: str,
        endpoint: str,
        access_token: str,
        params: Optional[Dict[str, Any]] = None,
        data: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Make authenticated request to Withings API with rate limiting."""
        # Rate limiting
        current_time = time.time()
        if current_time - self._request_window_start >= 60:
            self._request_count = 0
            self._request_window_start = current_time
        
        if self._request_count >= self.rate_limits["requests_per_minute"]:
            sleep_time = 60 - (current_time - self._request_window_start)
            if sleep_time > 0:
                time.sleep(sleep_time)
            self._request_count = 0
            self._request_window_start = time.time()

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }

        url = f"{self.base_url}{endpoint}"
        
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=method,
                url=url,
                headers=headers,
                params=params,
                json=data
            )
            response.raise_for_status()
            self._request_count += 1
            return response.json()

    async def get_user_info(self, access_token: str) -> Dict[str, Any]:
        """Get user information from Withings API."""
        return await self._make_request(
            method="GET",
            endpoint="/v2/user",
            access_token=access_token
        )

    async def get_measurements(
        self,
        access_token: str,
        start_date: datetime,
        end_date: datetime,
        category: int = 1  # 1 for body metrics
    ) -> Dict[str, Any]:
        """Get measurements from Withings API."""
        params = {
            "action": "getmeas",
            "startdate": int(start_date.timestamp()),
            "enddate": int(end_date.timestamp()),
            "category": category
        }
        
        return await self._make_request(
            method="GET",
            endpoint="/v2/measure",
            access_token=access_token,
            params=params
        )

    async def get_activities(
        self,
        access_token: str,
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Get activities from Withings API."""
        params = {
            "action": "getactivity",
            "startdate": int(start_date.timestamp()),
            "enddate": int(end_date.timestamp())
        }
        
        return await self._make_request(
            method="GET",
            endpoint="/v2/measure",
            access_token=access_token,
            params=params
        )

    async def get_sleep(
        self,
        access_token: str,
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Get sleep data from Withings API."""
        params = {
            "action": "get",
            "startdate": int(start_date.timestamp()),
            "enddate": int(end_date.timestamp())
        }
        
        return await self._make_request(
            method="GET",
            endpoint="/v2/sleep",
            access_token=access_token,
            params=params
        ) 