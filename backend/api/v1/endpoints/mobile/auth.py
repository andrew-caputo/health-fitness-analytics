from datetime import datetime, timedelta
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from jose import jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from backend.api.deps import get_db, get_current_user, SECRET_KEY, ALGORITHM
from backend.core.models import User
from backend.core.schemas import Token, UserCreate, User as UserSchema

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Mobile apps get longer token expiration (7 days)
MOBILE_ACCESS_TOKEN_EXPIRE_MINUTES = 7 * 24 * 60  # 7 days

def create_mobile_access_token(subject: str) -> str:
    """Create access token with extended expiration for mobile apps"""
    expire = datetime.utcnow() + timedelta(minutes=MOBILE_ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject), "type": "mobile"}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@router.post("/login", response_model=Dict[str, Any])
def mobile_login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)) -> Any:
    """
    Mobile app login with extended token expiration.
    Returns user profile along with token for mobile optimization.
    """
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not pwd_context.verify(form_data.password, getattr(user, "hashed_password", None)):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_mobile_access_token(user.id)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": MOBILE_ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # seconds
        "user": {
            "id": user.id,
            "email": user.email,
            "created_at": user.created_at.isoformat() if user.created_at else None
        }
    }

@router.post("/register", response_model=Dict[str, Any])
def mobile_register(user_in: UserCreate, db: Session = Depends(get_db)) -> Any:
    """
    Mobile app registration with automatic login.
    Returns user profile and token for seamless onboarding.
    """
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    user = User(
        email=user_in.email,
        hashed_password=pwd_context.hash(user_in.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # Automatically create access token for new user
    access_token = create_mobile_access_token(user.id)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": MOBILE_ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # seconds
        "user": {
            "id": user.id,
            "email": user.email,
            "created_at": user.created_at.isoformat() if user.created_at else None
        },
        "message": "Account created successfully"
    }

@router.post("/refresh", response_model=Dict[str, Any])
def refresh_mobile_token(current_user: User = Depends(get_current_user)) -> Any:
    """
    Refresh mobile access token.
    Mobile apps can refresh tokens before expiration.
    """
    access_token = create_mobile_access_token(current_user.id)
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": MOBILE_ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # seconds
        "user": {
            "id": current_user.id,
            "email": current_user.email,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None
        }
    }

@router.post("/logout")
def mobile_logout(current_user: User = Depends(get_current_user)) -> Dict[str, str]:
    """
    Mobile app logout.
    Note: JWT tokens are stateless, so this is mainly for client-side cleanup.
    In production, consider implementing token blacklisting.
    """
    return {"message": "Successfully logged out"}

@router.get("/verify")
def verify_mobile_token(current_user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """
    Verify mobile token validity and return user info.
    Useful for app startup to check if stored token is still valid.
    """
    return {
        "valid": True,
        "user": {
            "id": current_user.id,
            "email": current_user.email,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None
        }
    } 