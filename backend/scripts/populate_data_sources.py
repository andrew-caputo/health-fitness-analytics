#!/usr/bin/env python3
"""
Script to populate the data_source_capabilities table with all supported data sources.
This should be run after the database migration to set up the available data sources.
"""

import sys
import os
from datetime import datetime

# Add the backend directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from core.database import SessionLocal
from core.models import DataSourceCapabilities

def populate_data_sources():
    """Populate the data source capabilities table"""
    
    # Data source configurations
    data_sources = [
        {
            "source_name": "withings",
            "display_name": "Withings",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "WITHINGS_CLIENT_ID",
                "client_secret_env": "WITHINGS_CLIENT_SECRET",
                "authorization_url": "https://account.withings.com/oauth2_user/authorize2",
                "token_url": "https://wbsapi.withings.net/v2/oauth2",
                "scope": "user.metrics,user.activity,user.sleepevents"
            },
            "api_endpoints": {
                "base_url": "https://wbsapi.withings.net",
                "measurements": "/measure",
                "activities": "/v2/measure",
                "sleep": "/v2/sleep"
            },
            "rate_limits": {
                "requests_per_minute": 120,
                "requests_per_hour": 1000
            }
        },
        {
            "source_name": "apple_health",
            "display_name": "Apple Health",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": True,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "file_upload",
            "oauth_config": None,
            "api_endpoints": {
                "file_types": ["xml", "zip"],
                "max_file_size": "100MB",
                "supported_data_types": [
                    "HKQuantityTypeIdentifierStepCount",
                    "HKQuantityTypeIdentifierHeartRate",
                    "HKCategoryTypeIdentifierSleepAnalysis",
                    "HKQuantityTypeIdentifierBodyMass",
                    "HKQuantityTypeIdentifierDietaryEnergyConsumed"
                ]
            },
            "rate_limits": {
                "max_concurrent_uploads": 3,
                "max_file_size_mb": 100
            }
        },
        {
            "source_name": "csv",
            "display_name": "CSV Import",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": True,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "file_upload",
            "oauth_config": None,
            "api_endpoints": {
                "file_types": ["csv"],
                "max_file_size": "50MB",
                "required_columns": {
                    "activity": ["timestamp", "metric_type", "value", "unit"],
                    "sleep": ["timestamp", "metric_type", "value", "unit"],
                    "nutrition": ["timestamp", "metric_type", "value", "unit"],
                    "body_composition": ["timestamp", "metric_type", "value", "unit"]
                }
            },
            "rate_limits": {
                "max_concurrent_uploads": 5,
                "max_file_size_mb": 50
            }
        },
        {
            "source_name": "oura",
            "display_name": "Oura Ring",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": False,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "OURA_CLIENT_ID",
                "client_secret_env": "OURA_CLIENT_SECRET",
                "authorization_url": "https://cloud.ouraring.com/oauth/authorize",
                "token_url": "https://api.ouraring.com/oauth/token",
                "scope": "daily personal"
            },
            "api_endpoints": {
                "base_url": "https://api.ouraring.com",
                "daily_activity": "/v2/usercollection/daily_activity",
                "daily_sleep": "/v2/usercollection/daily_sleep",
                "sessions": "/v2/usercollection/session"
            },
            "rate_limits": {
                "requests_per_minute": 300,
                "requests_per_day": 5000
            }
        },
        {
            "source_name": "myfitnesspal",
            "display_name": "MyFitnessPal",
            "supports_activity": True,
            "supports_sleep": False,
            "supports_nutrition": True,
            "supports_body_composition": False,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "MYFITNESSPAL_CLIENT_ID",
                "client_secret_env": "MYFITNESSPAL_CLIENT_SECRET",
                "authorization_url": "https://www.myfitnesspal.com/api/auth/authorize",
                "token_url": "https://api.myfitnesspal.com/oauth2/token",
                "scope": "diary exercise"
            },
            "api_endpoints": {
                "base_url": "https://api.myfitnesspal.com",
                "diary": "/v1/diary",
                "exercise": "/v1/exercise",
                "nutrition": "/v1/nutrition"
            },
            "rate_limits": {
                "requests_per_minute": 120,
                "requests_per_hour": 1000
            }
        },
        {
            "source_name": "fitbit",
            "display_name": "Fitbit",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "FITBIT_CLIENT_ID",
                "client_secret_env": "FITBIT_CLIENT_SECRET",
                "authorization_url": "https://www.fitbit.com/oauth2/authorize",
                "token_url": "https://api.fitbit.com/oauth2/token",
                "scope": "activity heartrate sleep weight"
            },
            "api_endpoints": {
                "base_url": "https://api.fitbit.com",
                "activities": "/1/user/-/activities",
                "sleep": "/1.2/user/-/sleep",
                "body": "/1/user/-/body"
            },
            "rate_limits": {
                "requests_per_hour": 150,
                "requests_per_day": 1000
            }
        },
        {
            "source_name": "strava",
            "display_name": "Strava",
            "supports_activity": True,
            "supports_sleep": False,
            "supports_nutrition": False,
            "supports_body_composition": False,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "STRAVA_CLIENT_ID",
                "client_secret_env": "STRAVA_CLIENT_SECRET",
                "authorization_url": "https://www.strava.com/oauth/authorize",
                "token_url": "https://www.strava.com/oauth/token",
                "scope": "read,activity:read"
            },
            "api_endpoints": {
                "base_url": "https://www.strava.com/api/v3",
                "activities": "/athlete/activities",
                "activity_detail": "/activities/{id}",
                "athlete": "/athlete"
            },
            "rate_limits": {
                "requests_per_15_minutes": 100,
                "requests_per_day": 1000
            }
        },
        {
            "source_name": "whoop",
            "display_name": "WHOOP",
            "supports_activity": True,
            "supports_sleep": True,
            "supports_nutrition": False,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "WHOOP_CLIENT_ID",
                "client_secret_env": "WHOOP_CLIENT_SECRET",
                "authorization_url": "https://api.prod.whoop.com/oauth/oauth2/auth",
                "token_url": "https://api.prod.whoop.com/oauth/oauth2/token",
                "scope": "read:recovery read:sleep read:workout read:profile read:body_measurement"
            },
            "api_endpoints": {
                "base_url": "https://api.prod.whoop.com",
                "recovery": "/developer/v1/recovery",
                "sleep": "/developer/v1/activity/sleep",
                "workout": "/developer/v1/activity/workout",
                "body": "/developer/v1/measurement/body"
            },
            "rate_limits": {
                "requests_per_minute": 100,
                "requests_per_hour": 1000
            }
        },
        {
            "source_name": "cronometer",
            "display_name": "Cronometer",
            "supports_activity": False,
            "supports_sleep": False,
            "supports_nutrition": True,
            "supports_body_composition": True,
            "supports_heart_health": True,
            "integration_type": "oauth2",
            "oauth_config": {
                "client_id_env": "CRONOMETER_CLIENT_ID",
                "client_secret_env": "CRONOMETER_CLIENT_SECRET",
                "authorization_url": "https://cronometer.com/oauth/authorize",
                "token_url": "https://cronometer.com/oauth/token",
                "scope": "diary biometrics"
            },
            "api_endpoints": {
                "base_url": "https://cronometer.com/api",
                "diary": "/v1/diary",
                "biometrics": "/v1/biometrics",
                "nutrition": "/v1/nutrition"
            },
            "rate_limits": {
                "requests_per_minute": 60,
                "requests_per_hour": 500
            }
        }
    ]
    
    db = SessionLocal()
    try:
        # Check if data sources already exist
        existing_count = db.query(DataSourceCapabilities).count()
        if existing_count > 0:
            print(f"Found {existing_count} existing data sources. Updating...")
        
        for source_data in data_sources:
            # Check if source already exists
            existing_source = db.query(DataSourceCapabilities).filter(
                DataSourceCapabilities.source_name == source_data["source_name"]
            ).first()
            
            if existing_source:
                # Update existing source
                for key, value in source_data.items():
                    if key not in ["source_name"]:  # Don't update the primary identifier
                        setattr(existing_source, key, value)
                existing_source.updated_at = datetime.utcnow()
                print(f"Updated data source: {source_data['display_name']}")
            else:
                # Create new source
                new_source = DataSourceCapabilities(
                    **source_data,
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow()
                )
                db.add(new_source)
                print(f"Added data source: {source_data['display_name']}")
        
        db.commit()
        print("\nData source capabilities populated successfully!")
        
        # Print summary
        total_sources = db.query(DataSourceCapabilities).count()
        active_sources = db.query(DataSourceCapabilities).filter(
            DataSourceCapabilities.is_active == True
        ).count()
        
        print(f"\nSummary:")
        print(f"Total data sources: {total_sources}")
        print(f"Active data sources: {active_sources}")
        
        # Print capabilities summary
        categories = ["activity", "sleep", "nutrition", "body_composition", "heart_health"]
        for category in categories:
            field_name = f"supports_{category}"
            count = db.query(DataSourceCapabilities).filter(
                getattr(DataSourceCapabilities, field_name) == True,
                DataSourceCapabilities.is_active == True
            ).count()
            print(f"Sources supporting {category}: {count}")
        
    except Exception as e:
        print(f"Error populating data sources: {e}")
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    populate_data_sources() 