from fastapi import APIRouter

from backend.api.v1.endpoints import (
    auth,
    chat,
    goals,
    health_metrics,
    insights,
    users,
    preferences,
    apple_health,
    csv_import,
    ai_insights,  # Re-enabled for gradual testing with lazy imports
)
from backend.api.v1.endpoints.data_sources import common, withings, oura, fitbit, whoop, strava, fatsecret
from backend.api.v1.endpoints.mobile import auth as mobile_auth, healthkit, user as mobile_user

api_router = APIRouter()

# Auth endpoints
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["authentication"]
)

# User endpoints
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["users"]
)

# Health metrics endpoints
api_router.include_router(
    health_metrics.router,
    prefix="/health-metrics",
    tags=["health metrics"]
)

# Goals endpoints
api_router.include_router(
    goals.router,
    prefix="/goals",
    tags=["goals"]
)

# Insights endpoints
api_router.include_router(
    insights.router,
    prefix="/insights",
    tags=["insights"]
)

# AI Insights endpoints - FULLY RESTORED with lazy imports (no numpy contamination)
api_router.include_router(
    ai_insights.router,
    prefix="/ai",
    tags=["ai insights"]
)

# Chat endpoints
api_router.include_router(
    chat.router,
    prefix="/chat",
    tags=["chat"]
)

# User preferences endpoints
api_router.include_router(
    preferences.router,
    prefix="/preferences",
    tags=["preferences"]
)

# Apple Health endpoints
api_router.include_router(
    apple_health.router,
    prefix="/apple-health",
    tags=["apple health"]
)

# CSV Import endpoints
api_router.include_router(
    csv_import.router,
    prefix="/csv-import",
    tags=["csv import"]
)

# Data source endpoints
api_router.include_router(
    common.router,
    prefix="/data-sources",
    tags=["data sources"]
)

# Withings endpoints
api_router.include_router(
    withings.router,
    prefix="/data-sources/withings",
    tags=["withings"]
)

# Oura endpoints
api_router.include_router(
    oura.router,
    prefix="/data-sources/oura",
    tags=["oura"]
)

# Fitbit endpoints
api_router.include_router(
    fitbit.router,
    prefix="/data-sources/fitbit",
    tags=["fitbit"]
)

# WHOOP endpoints
api_router.include_router(
    whoop.router,
    prefix="/data-sources/whoop",
    tags=["whoop"]
)

# Strava endpoints
api_router.include_router(
    strava.router,
    prefix="/data-sources/strava",
    tags=["strava"]
)

# FatSecret endpoints
api_router.include_router(
    fatsecret.router,
    prefix="/data-sources/fatsecret",
    tags=["fatsecret"]
)

# Mobile API endpoints
api_router.include_router(
    mobile_auth.router,
    prefix="/mobile/auth",
    tags=["mobile auth"]
)

# Mobile HealthKit endpoints
api_router.include_router(
    healthkit.router,
    prefix="/mobile/healthkit",
    tags=["mobile healthkit"]
)

# Mobile User endpoints
api_router.include_router(
    mobile_user.router,
    prefix="/mobile/user",
    tags=["mobile user"]
) 