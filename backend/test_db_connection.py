#!/usr/bin/env python3
"""
Test database connectivity and authentication
"""

import sys
import os

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_database_connection():
    """Test basic database connectivity"""
    try:
        from backend.core.database import get_db
        from backend.core.models import User
        
        db = next(get_db())
        
        # Test basic query
        user_count = db.query(User).count()
        print(f"✅ Database connection successful")
        print(f"   Total users: {user_count}")
        
        # Test specific user
        user = db.query(User).filter(User.email == 'test@healthanalytics.com').first()
        if user:
            print(f"✅ Test user found: {user.email}")
            print(f"   ID: {user.id}")
            print(f"   Has password: {bool(user.hashed_password)}")
            print(f"   Password length: {len(user.hashed_password) if user.hashed_password else 0}")
        else:
            print("❌ Test user not found")
        
        db.close()
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_password_verification():
    """Test password hashing and verification"""
    try:
        from backend.core.security import get_password_hash, verify_password
        
        # Test password hashing
        test_password = "testpassword123"
        hashed = get_password_hash(test_password)
        print(f"✅ Password hashing works")
        print(f"   Original: {test_password}")
        print(f"   Hashed length: {len(hashed)}")
        
        # Test verification
        is_valid = verify_password(test_password, hashed)
        print(f"✅ Password verification: {is_valid}")
        
        return True
        
    except Exception as e:
        print(f"❌ Password verification failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_authentication_flow():
    """Test the complete authentication flow"""
    try:
        from backend.core.database import get_db
        from backend.core.models import User
        from backend.core.security import verify_password
        
        db = next(get_db())
        
        # Get test user
        user = db.query(User).filter(User.email == 'test@healthanalytics.com').first()
        if not user:
            print("❌ Test user not found")
            return False
        
        # Test password verification
        test_password = "testpassword123"
        is_valid = verify_password(test_password, user.hashed_password)
        
        print(f"✅ Authentication flow test:")
        print(f"   User exists: {bool(user)}")
        print(f"   Password valid: {is_valid}")
        
        db.close()
        return is_valid
        
    except Exception as e:
        print(f"❌ Authentication flow failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_jwt_token_creation():
    """Test JWT token creation"""
    try:
        from backend.api.v1.endpoints.auth import create_access_token
        
        test_user_id = "630de2aa-b13f-4074-ac8d-e604f7ae4a14"
        token = create_access_token(test_user_id)
        
        print(f"✅ JWT token creation works")
        print(f"   Token length: {len(token)}")
        print(f"   Token preview: {token[:50]}...")
        
        return True
        
    except Exception as e:
        print(f"❌ JWT token creation failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🔍 Testing database and authentication...")
    print("="*50)
    
    test1 = test_database_connection()
    print()
    
    test2 = test_password_verification()
    print()
    
    test3 = test_authentication_flow()
    print()
    
    test4 = test_jwt_token_creation()
    print()
    
    print("="*50)
    if all([test1, test2, test3, test4]):
        print("🎉 All database and authentication tests passed!")
    else:
        print("❌ Some tests failed - need to investigate")
    print("="*50) 