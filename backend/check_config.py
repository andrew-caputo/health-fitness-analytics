#!/usr/bin/env python3
"""
Check current configuration
"""

import os
import sys

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def check_config():
    """Check current configuration"""
    try:
        from backend.core.config import Settings
        
        settings = Settings()
        
        print("🔧 Current Configuration:")
        print(f"   DATABASE_URL: {settings.DATABASE_URL}")
        print(f"   SECRET_KEY: {settings.SECRET_KEY[:20]}...")
        print(f"   ALGORITHM: {settings.ALGORITHM}")
        print(f"   DEBUG: {settings.DEBUG}")
        print(f"   ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")
        
        print("\n🌍 Environment Variables:")
        print(f"   DATABASE_URL: {os.getenv('DATABASE_URL', 'NOT SET')}")
        print(f"   SECRET_KEY: {os.getenv('SECRET_KEY', 'NOT SET')[:20] if os.getenv('SECRET_KEY') else 'NOT SET'}...")
        
        return True
        
    except Exception as e:
        print(f"❌ Configuration check failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🔍 Checking configuration...")
    print("="*50)
    
    check_config()
    
    print("="*50) 