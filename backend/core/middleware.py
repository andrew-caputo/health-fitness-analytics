import logging
import time
from typing import Callable
from uuid import uuid4

from fastapi import Request, Response, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add security headers to all responses"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        
        # Security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        
        return response

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log all requests with timing and correlation IDs"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate correlation ID
        correlation_id = str(uuid4())
        request.state.correlation_id = correlation_id
        
        # Log request
        start_time = time.time()
        logger.info(
            f"Request started",
            extra={
                "correlation_id": correlation_id,
                "method": request.method,
                "url": str(request.url),
                "client_ip": request.client.host if request.client else None,
                "user_agent": request.headers.get("user-agent"),
            }
        )
        
        try:
            response = await call_next(request)
            
            # Log response
            process_time = time.time() - start_time
            logger.info(
                f"Request completed",
                extra={
                    "correlation_id": correlation_id,
                    "status_code": response.status_code,
                    "process_time": process_time,
                }
            )
            
            # Add correlation ID to response headers
            response.headers["X-Correlation-ID"] = correlation_id
            
            return response
            
        except Exception as e:
            process_time = time.time() - start_time
            logger.error(
                f"Request failed",
                extra={
                    "correlation_id": correlation_id,
                    "error": str(e),
                    "process_time": process_time,
                },
                exc_info=True
            )
            raise

class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple in-memory rate limiting (for production, use Redis)"""
    
    def __init__(self, app, calls: int = 100, period: int = 60):
        super().__init__(app)
        self.calls = calls
        self.period = period
        self.clients = {}
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        current_time = time.time()
        
        # Clean old entries
        self.clients = {
            ip: times for ip, times in self.clients.items()
            if any(t > current_time - self.period for t in times)
        }
        
        # Check rate limit
        if client_ip in self.clients:
            recent_calls = [t for t in self.clients[client_ip] if t > current_time - self.period]
            if len(recent_calls) >= self.calls:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Rate limit exceeded"}
                )
            self.clients[client_ip] = recent_calls + [current_time]
        else:
            self.clients[client_ip] = [current_time]
        
        return await call_next(request)

async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Global exception handler for unhandled errors"""
    correlation_id = getattr(request.state, 'correlation_id', 'unknown')
    
    logger.error(
        f"Unhandled exception",
        extra={
            "correlation_id": correlation_id,
            "error": str(exc),
            "path": request.url.path,
        },
        exc_info=True
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "correlation_id": correlation_id
        }
    )

async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """Handle HTTP exceptions with proper logging"""
    correlation_id = getattr(request.state, 'correlation_id', 'unknown')
    
    logger.warning(
        f"HTTP exception",
        extra={
            "correlation_id": correlation_id,
            "status_code": exc.status_code,
            "detail": exc.detail,
            "path": request.url.path,
        }
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "correlation_id": correlation_id
        }
    ) 