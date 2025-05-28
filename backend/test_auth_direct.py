#!/usr/bin/env python3
"""
Direct test of authentication endpoint
"""

import sys
import os

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_auth_endpoint():
    """Test the authentication endpoint directly"""
    try:
        from main import app
        from fastapi.testclient import TestClient
        
        client = TestClient(app)
        
        # Test login
        response = client.post(
            "/api/v1/auth/login",
            data={"username": "test@healthanalytics.com", "password": "testpassword123"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        print(f"✅ Authentication test:")
        print(f"   Status Code: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Access Token: {data.get('access_token', 'N/A')[:50]}...")
            print(f"   Token Type: {data.get('token_type', 'N/A')}")
        else:
            print(f"   Error: {response.text}")
        
        return response.status_code == 200
        
    except Exception as e:
        print(f"❌ Authentication test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🔐 Testing authentication endpoint...")
    print("="*50)
    
    success = test_auth_endpoint()
    
    print("="*50)
    if success:
        print("🎉 Authentication test passed!")
    else:
        print("❌ Authentication test failed")
    print("="*50) 