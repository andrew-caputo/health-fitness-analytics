from datetime import datetime
from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.config import settings

router = APIRouter()

@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "health-fitness-analytics-api",
        "version": "1.0.0"
    }

@router.get("/health/detailed")
async def detailed_health_check(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Detailed health check including database connectivity"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "health-fitness-analytics-api",
        "version": "1.0.0",
        "checks": {}
    }
    
    # Database connectivity check
    try:
        db.execute(text("SELECT 1"))
        health_status["checks"]["database"] = {
            "status": "healthy",
            "message": "Database connection successful"
        }
    except Exception as e:
        health_status["status"] = "unhealthy"
        health_status["checks"]["database"] = {
            "status": "unhealthy",
            "message": f"Database connection failed: {str(e)}"
        }
    
    # Configuration check
    config_issues = []
    if not settings.SECRET_KEY or settings.SECRET_KEY == "your-secret-key-here":
        config_issues.append("SECRET_KEY not properly configured")
    if not settings.DATABASE_URL:
        config_issues.append("DATABASE_URL not configured")
    
    if config_issues:
        health_status["status"] = "degraded"
        health_status["checks"]["configuration"] = {
            "status": "degraded",
            "message": f"Configuration issues: {', '.join(config_issues)}"
        }
    else:
        health_status["checks"]["configuration"] = {
            "status": "healthy",
            "message": "Configuration is valid"
        }
    
    return health_status

@router.get("/health/ready")
async def readiness_check(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """Readiness check for Kubernetes/container orchestration"""
    try:
        # Check database connectivity
        db.execute(text("SELECT 1"))
        
        # Check critical configuration
        if not settings.SECRET_KEY or settings.SECRET_KEY == "your-secret-key-here":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service not ready: SECRET_KEY not configured"
            )
        
        return {
            "status": "ready",
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service not ready: {str(e)}"
        )

@router.get("/health/live")
async def liveness_check() -> Dict[str, Any]:
    """Liveness check for Kubernetes/container orchestration"""
    return {
        "status": "alive",
        "timestamp": datetime.utcnow().isoformat()
    } 