#!/usr/bin/env python3
"""
Direct test of health endpoint functionality
"""

import sys
import os

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_health_endpoint():
    """Test the health endpoint directly"""
    try:
        from backend.api.v1.endpoints.health import health_check
        import asyncio
        
        # Test the health check function directly
        result = asyncio.run(health_check())
        print("✅ Health check function works:")
        print(f"   Status: {result['status']}")
        print(f"   Service: {result['service']}")
        print(f"   Version: {result['version']}")
        return True
        
    except Exception as e:
        print(f"❌ Health check function failed: {e}")
        return False

def test_app_routes():
    """Test that the app has the health routes registered"""
    try:
        from main import app
        
        routes = [route.path for route in app.routes]
        health_routes = [route for route in routes if 'health' in route]
        
        print(f"✅ Found {len(health_routes)} health routes:")
        for route in health_routes:
            print(f"   {route}")
        
        return len(health_routes) > 0
        
    except Exception as e:
        print(f"❌ App routes test failed: {e}")
        return False

def test_fastapi_app():
    """Test the FastAPI app directly"""
    try:
        from main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        response = client.get("/health")
        
        print(f"✅ Direct FastAPI test:")
        print(f"   Status Code: {response.status_code}")
        print(f"   Response: {response.json()}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"❌ FastAPI app test failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing health endpoint functionality...")
    print("="*50)
    
    test1 = test_health_endpoint()
    test2 = test_app_routes()
    test3 = test_fastapi_app()
    
    print("="*50)
    if all([test1, test2, test3]):
        print("🎉 All tests passed!")
    else:
        print("❌ Some tests failed")
        
    print("="*50) 