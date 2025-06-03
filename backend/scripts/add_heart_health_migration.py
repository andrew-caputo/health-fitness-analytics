#!/usr/bin/env python3
"""
Migration script to add heart health support to the database.
This adds:
1. heart_health_source column to user_data_source_preferences
2. supports_heart_health column to data_source_capabilities  
3. Updates existing data sources to support heart health where appropriate
"""

import sys
import os

# Add the backend directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from sqlalchemy import text
from core.database import SessionLocal
from core.models import DataSourceCapabilities

def add_heart_health_support():
    """Add heart health support to the database"""
    
    db = SessionLocal()
    try:
        print("Adding heart health support to database...")
        
        # Add heart_health_source column to user_data_source_preferences
        print("1. Adding heart_health_source column to user_data_source_preferences...")
        try:
            db.execute(text("""
                ALTER TABLE user_data_source_preferences 
                ADD COLUMN heart_health_source VARCHAR(50);
            """))
            print("   ✅ Successfully added heart_health_source column")
        except Exception as e:
            if "already exists" in str(e) or "duplicate column" in str(e).lower():
                print("   ⚠️ heart_health_source column already exists")
            else:
                print(f"   ❌ Error adding heart_health_source column: {e}")
                raise
        
        # Add supports_heart_health column to data_source_capabilities
        print("2. Adding supports_heart_health column to data_source_capabilities...")
        try:
            db.execute(text("""
                ALTER TABLE data_source_capabilities 
                ADD COLUMN supports_heart_health BOOLEAN NOT NULL DEFAULT FALSE;
            """))
            print("   ✅ Successfully added supports_heart_health column")
        except Exception as e:
            if "already exists" in str(e) or "duplicate column" in str(e).lower():
                print("   ⚠️ supports_heart_health column already exists")
            else:
                print(f"   ❌ Error adding supports_heart_health column: {e}")
                raise
        
        db.commit()
        
        # Update existing data sources to support heart health
        print("3. Updating existing data sources with heart health support...")
        
        # Sources that support heart health
        heart_health_sources = [
            "withings",      # Heart rate, HRV
            "apple_health",  # Heart rate, HRV, resting HR
            "csv",           # Custom heart health data
            "oura",          # Heart rate, HRV
            "fitbit",        # Heart rate, resting HR
            "strava",        # Exercise heart rate
            "whoop",         # Heart rate, HRV, recovery
            "cronometer"     # Some heart health metrics
        ]
        
        for source_name in heart_health_sources:
            source = db.query(DataSourceCapabilities).filter(
                DataSourceCapabilities.source_name == source_name
            ).first()
            
            if source:
                source.supports_heart_health = True
                print(f"   ✅ Updated {source.display_name} to support heart health")
            else:
                print(f"   ⚠️ Source '{source_name}' not found in database")
        
        db.commit()
        
        print("\n🎉 Heart health migration completed successfully!")
        
        # Print summary
        heart_health_count = db.query(DataSourceCapabilities).filter(
            DataSourceCapabilities.supports_heart_health == True
        ).count()
        
        print(f"\nSummary:")
        print(f"✅ Database schema updated")
        print(f"✅ {heart_health_count} data sources now support heart health")
        print(f"✅ Ready for heart health data source selection")
        
    except Exception as e:
        db.rollback()
        print(f"\n❌ Migration failed: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    add_heart_health_support() 