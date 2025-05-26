from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.router import api_router
from backend.api.v1.endpoints.health import router as health_router
from backend.core.middleware import (
    SecurityHeadersMiddleware,
    RequestLoggingMiddleware,
    RateLimitMiddleware,
    global_exception_handler,
    http_exception_handler
)
from backend.core.logging_config import setup_logging
from backend.core.config import settings

# Setup logging
setup_logging()

app = FastAPI(
    title="Health & Fitness Analytics API",
    description="API for health and fitness data analytics and insights",
    version="1.0.0",
)

# Add middleware (order matters - first added is outermost)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware, calls=100, period=60)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_HOSTS,  # Use configured hosts instead of "*"
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add exception handlers
app.add_exception_handler(Exception, global_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)

# Include routers
app.include_router(health_router, tags=["health"])
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {
        "message": "Welcome to Health & Fitness Analytics API",
        "docs_url": "/docs",
        "redoc_url": "/redoc",
        "health_url": "/health",
    } 