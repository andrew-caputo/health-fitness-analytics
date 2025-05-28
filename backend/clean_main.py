#!/usr/bin/env python3
"""
Clean FastAPI application with zero numpy contamination
Only includes authentication functionality
"""

import os
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from jose import jwt
from passlib.context import CryptContext

# Import only essential modules - NO AI imports
from core.database import get_db
from core.models import User
from core.config import settings

# Create clean FastAPI app
app = FastAPI(
    title="Clean Health & Fitness Analytics API",
    description="Numpy-free API for authentication testing",
    version="1.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Auth utilities
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = settings.SECRET_KEY
ALGORITHM = settings.ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES

def create_access_token(subject: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject)}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@app.get("/health")
def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "clean-health-fitness-analytics-api",
        "version": "1.0.0",
        "database_path": os.path.abspath("health_fitness_analytics.db"),
        "database_exists": os.path.exists("health_fitness_analytics.db")
    }

@app.post("/api/v1/auth/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)) -> JSONResponse:
    """
    Clean authentication endpoint with zero numpy contamination
    """
    try:
        print(f"Login attempt for user: {form_data.username}")
        print(f"Working directory: {os.getcwd()}")
        print(f"Database file exists: {os.path.exists('health_fitness_analytics.db')}")
        
        # Get user
        user = db.query(User).filter(User.email == form_data.username).first()
        
        if not user:
            print(f"User not found: {form_data.username}")
            return JSONResponse(
                status_code=401,
                content={
                    "detail": "Incorrect email or password",
                    "error_code": "USER_NOT_FOUND"
                }
            )
        
        print(f"User found: {user.email}, ID: {user.id}")
        
        # Verify password
        if not pwd_context.verify(form_data.password, user.hashed_password):
            print("Password verification failed")
            return JSONResponse(
                status_code=401,
                content={
                    "detail": "Incorrect email or password",
                    "error_code": "INVALID_PASSWORD"
                }
            )
        
        print("Password verification successful")
        
        # Create token
        access_token = create_access_token(str(user.id))
        print(f"Token created successfully: {access_token[:50]}...")
        
        # Return clean JSON response
        response_data = {
            "access_token": access_token,
            "token_type": "bearer",
            "user_id": str(user.id),
            "email": user.email
        }
        
        print(f"Returning successful auth response")
        return JSONResponse(
            status_code=200,
            content=response_data
        )
        
    except Exception as e:
        print(f"Authentication error: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "detail": "Authentication failed",
                "error": str(e)
            }
        )

@app.get("/")
def root():
    """Root endpoint"""
    return {
        "message": "Clean Health & Fitness Analytics API",
        "status": "numpy-free",
        "docs_url": "/docs",
        "health_url": "/health",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003) 