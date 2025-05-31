import os
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from backend.core.config import Settings

# Load settings which will read from .env file
settings = Settings()

# Main database URL from settings
DATABASE_URL = settings.DATABASE_URL

# Test database URL (can be overridden by environment variable for CI/CD)
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL", "sqlite:///./tests/test_health_fitness_analytics.db")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Engine and session for testing
if "pytest" in os.sys.modules:  # Check if running under pytest
    test_engine = create_engine(TEST_DATABASE_URL)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
else:
    test_engine = None
    TestingSessionLocal = None

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close() 