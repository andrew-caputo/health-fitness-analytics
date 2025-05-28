#!/usr/bin/env python3
"""
Sample Health Data Seeding Script for Phase 5 Week 1 Testing

This script creates realistic health data for testing all AI endpoints
and validating the complete user journey with comprehensive data patterns.
"""

import sys
import os
from datetime import datetime, timedelta
import random
import uuid
from decimal import Decimal

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from backend.core.database import get_db, engine
from backend.core.models import (
    Base, User, HealthMetricUnified, UserDataSourcePreferences,
    DataSourceConnection, DataSourceCapabilities
)
from backend.core.security import get_password_hash

def create_sample_user() -> User:
    """Create a sample user for testing"""
    user = User(
        id=uuid.uuid4(),
        email="test@healthanalytics.com",
        hashed_password=get_password_hash("testpassword123"),
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    return user

def create_data_source_capabilities(db: Session):
    """Create data source capabilities configuration"""
    capabilities = [
        {
            "source_name": "apple_health",
            "display_name": "Apple Health",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": True,
            "supports_body_composition": True,
            "integration_type": "file_upload"
        },
        {
            "source_name": "withings",
            "display_name": "Withings",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": True,
            "integration_type": "oauth2"
        },
        {
            "source_name": "fitbit",
            "display_name": "Fitbit",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": True,
            "supports_body_composition": False,
            "integration_type": "oauth2"
        },
        {
            "source_name": "oura",
            "display_name": "Oura Ring",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": False,
            "integration_type": "oauth2"
        }
    ]
    
    for cap_data in capabilities:
        capability = DataSourceCapabilities(
            id=uuid.uuid4(),
            **cap_data,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(capability)

def create_user_preferences(user: User, db: Session):
    """Create user data source preferences"""
    preferences = UserDataSourcePreferences(
        id=uuid.uuid4(),
        user_id=user.id,
        activity_source="apple_health",
        sleep_source="oura",
        nutrition_source="fitbit",
        body_composition_source="withings",
        priority_rules={
            "activity": ["apple_health", "fitbit", "withings"],
            "sleep": ["oura", "apple_health", "fitbit"],
            "nutrition": ["fitbit", "apple_health"],
            "body_composition": ["withings", "apple_health"]
        },
        conflict_resolution={
            "strategy": "prefer_primary",
            "fallback": "average",
            "quality_threshold": 0.8
        },
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    db.add(preferences)
    return preferences

def create_data_source_connections(user: User, db: Session):
    """Create sample data source connections"""
    connections = [
        {
            "source_type": "apple_health",
            "status": "connected",
            "last_sync_at": datetime.utcnow() - timedelta(hours=1)
        },
        {
            "source_type": "withings",
            "status": "connected",
            "access_token": "sample_withings_token",
            "last_sync_at": datetime.utcnow() - timedelta(hours=2)
        },
        {
            "source_type": "fitbit",
            "status": "connected",
            "access_token": "sample_fitbit_token",
            "last_sync_at": datetime.utcnow() - timedelta(hours=3)
        },
        {
            "source_type": "oura",
            "status": "connected",
            "access_token": "sample_oura_token",
            "last_sync_at": datetime.utcnow() - timedelta(hours=1)
        }
    ]
    
    for conn_data in connections:
        connection = DataSourceConnection(
            id=uuid.uuid4(),
            user_id=user.id,
            **conn_data,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        db.add(connection)

def generate_activity_data(user: User, days: int = 90) -> list:
    """Generate realistic activity data"""
    metrics = []
    base_steps = 8000
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        
        # Steps with weekly patterns and random variation
        day_of_week = date.weekday()
        weekend_factor = 0.8 if day_of_week >= 5 else 1.0
        steps = int(base_steps * weekend_factor * random.uniform(0.7, 1.4))
        
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="activity_steps",
            category="activity",
            value=Decimal(str(steps)),
            unit="steps",
            timestamp=date,
            data_source="apple_health",
            quality_score=Decimal("0.95"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Active energy
        active_energy = int(steps * 0.04 * random.uniform(0.8, 1.2))
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="activity_active_energy",
            category="activity",
            value=Decimal(str(active_energy)),
            unit="kcal",
            timestamp=date,
            data_source="apple_health",
            quality_score=Decimal("0.90"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Exercise minutes (3-4 times per week)
        if random.random() < 0.5:
            exercise_minutes = random.randint(20, 60)
            metrics.append(HealthMetricUnified(
                id=uuid.uuid4(),
                user_id=user.id,
                metric_type="activity_exercise_minutes",
                category="activity",
                value=Decimal(str(exercise_minutes)),
                unit="minutes",
                timestamp=date,
                data_source="fitbit",
                quality_score=Decimal("0.85"),
                is_primary=True,
                created_at=datetime.utcnow()
            ))
    
    return metrics

def generate_sleep_data(user: User, days: int = 90) -> list:
    """Generate realistic sleep data"""
    metrics = []
    base_sleep = 7.5  # hours
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        
        # Sleep duration with weekly patterns
        day_of_week = date.weekday()
        weekend_factor = 1.2 if day_of_week >= 5 else 1.0
        sleep_hours = base_sleep * weekend_factor * random.uniform(0.8, 1.2)
        
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="sleep_duration",
            category="sleep",
            value=Decimal(str(round(sleep_hours, 2))),
            unit="hours",
            timestamp=date,
            data_source="oura",
            quality_score=Decimal("0.92"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Sleep quality score
        quality = random.uniform(0.6, 0.95)
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="sleep_quality",
            category="sleep",
            value=Decimal(str(round(quality, 2))),
            unit="score",
            timestamp=date,
            data_source="oura",
            quality_score=Decimal("0.88"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # REM sleep percentage
        rem_percentage = random.uniform(15, 25)
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="sleep_rem_percentage",
            category="sleep",
            value=Decimal(str(round(rem_percentage, 1))),
            unit="percentage",
            timestamp=date,
            data_source="oura",
            quality_score=Decimal("0.85"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
    
    return metrics

def generate_nutrition_data(user: User, days: int = 90) -> list:
    """Generate realistic nutrition data"""
    metrics = []
    base_calories = 2200
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        
        # Skip some days to simulate inconsistent tracking
        if random.random() < 0.3:
            continue
        
        # Calories with variation
        calories = int(base_calories * random.uniform(0.7, 1.3))
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="nutrition_calories",
            category="nutrition",
            value=Decimal(str(calories)),
            unit="kcal",
            timestamp=date,
            data_source="fitbit",
            quality_score=Decimal("0.80"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Water intake
        water_liters = round(random.uniform(1.5, 3.5), 1)
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="nutrition_water_intake",
            category="nutrition",
            value=Decimal(str(water_liters)),
            unit="liters",
            timestamp=date,
            data_source="apple_health",
            quality_score=Decimal("0.75"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Protein
        protein_grams = int(calories * 0.15 / 4)  # 15% of calories from protein
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="nutrition_protein",
            category="nutrition",
            value=Decimal(str(protein_grams)),
            unit="grams",
            timestamp=date,
            data_source="fitbit",
            quality_score=Decimal("0.78"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
    
    return metrics

def generate_body_composition_data(user: User, days: int = 90) -> list:
    """Generate realistic body composition data"""
    metrics = []
    base_weight = 75.0  # kg
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        
        # Weight measurements (not every day)
        if i % 3 == 0:  # Every 3 days
            # Gradual weight trend with daily variation
            trend = -0.01 * i  # Slight weight loss trend
            weight = base_weight + trend + random.uniform(-0.5, 0.5)
            
            metrics.append(HealthMetricUnified(
                id=uuid.uuid4(),
                user_id=user.id,
                metric_type="body_weight",
                category="body_composition",
                value=Decimal(str(round(weight, 1))),
                unit="kg",
                timestamp=date,
                data_source="withings",
                quality_score=Decimal("0.95"),
                is_primary=True,
                created_at=datetime.utcnow()
            ))
            
            # Body fat percentage
            body_fat = random.uniform(12, 18)
            metrics.append(HealthMetricUnified(
                id=uuid.uuid4(),
                user_id=user.id,
                metric_type="body_fat_percentage",
                category="body_composition",
                value=Decimal(str(round(body_fat, 1))),
                unit="percentage",
                timestamp=date,
                data_source="withings",
                quality_score=Decimal("0.88"),
                is_primary=True,
                created_at=datetime.utcnow()
            ))
    
    return metrics

def generate_heart_data(user: User, days: int = 90) -> list:
    """Generate realistic heart rate data"""
    metrics = []
    base_resting_hr = 65
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        
        # Resting heart rate with fitness improvement trend
        fitness_improvement = -0.02 * i  # Gradual improvement
        resting_hr = int(base_resting_hr + fitness_improvement + random.uniform(-3, 3))
        
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="heart_rate_resting",
            category="heart_health",
            value=Decimal(str(resting_hr)),
            unit="bpm",
            timestamp=date,
            data_source="apple_health",
            quality_score=Decimal("0.92"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
        
        # Heart rate variability
        hrv = random.uniform(25, 45)
        metrics.append(HealthMetricUnified(
            id=uuid.uuid4(),
            user_id=user.id,
            metric_type="heart_rate_variability",
            category="heart_health",
            value=Decimal(str(round(hrv, 1))),
            unit="ms",
            timestamp=date,
            data_source="oura",
            quality_score=Decimal("0.85"),
            is_primary=True,
            created_at=datetime.utcnow()
        ))
    
    return metrics

def seed_database():
    """Main function to seed the database with sample data"""
    print("🌱 Starting database seeding for Phase 5 Week 1 testing...")
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    # Get database session
    db = next(get_db())
    
    try:
        # Create sample user
        print("👤 Creating sample user...")
        user = create_sample_user()
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Create data source capabilities
        print("🔧 Setting up data source capabilities...")
        create_data_source_capabilities(db)
        
        # Create user preferences
        print("⚙️ Creating user preferences...")
        create_user_preferences(user, db)
        
        # Create data source connections
        print("🔗 Setting up data source connections...")
        create_data_source_connections(user, db)
        
        # Generate health metrics
        print("📊 Generating activity data...")
        activity_metrics = generate_activity_data(user, 90)
        
        print("😴 Generating sleep data...")
        sleep_metrics = generate_sleep_data(user, 90)
        
        print("🍎 Generating nutrition data...")
        nutrition_metrics = generate_nutrition_data(user, 90)
        
        print("⚖️ Generating body composition data...")
        body_metrics = generate_body_composition_data(user, 90)
        
        print("❤️ Generating heart rate data...")
        heart_metrics = generate_heart_data(user, 90)
        
        # Add all metrics to database
        all_metrics = (activity_metrics + sleep_metrics + nutrition_metrics + 
                      body_metrics + heart_metrics)
        
        print(f"💾 Saving {len(all_metrics)} health metrics to database...")
        for metric in all_metrics:
            db.add(metric)
        
        db.commit()
        
        print("✅ Database seeding completed successfully!")
        print(f"📈 Created {len(all_metrics)} health data points")
        print(f"👤 Test user email: {user.email}")
        print(f"🔑 Test user password: testpassword123")
        print(f"🆔 User ID: {user.id}")
        
        return user
        
    except Exception as e:
        print(f"❌ Error seeding database: {e}")
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed_database() 