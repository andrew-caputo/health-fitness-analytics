#!/usr/bin/env python3
"""
Minimal authentication test to bypass numpy issues
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_auth_components():
    """Test authentication components individually"""
    print("Testing authentication components...")
    
    try:
        # Test database connection
        from core.database import get_db
        from core.models import User
        print("✅ Database imports successful")
        
        # Test password verification
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        print("✅ Password context created")
        
        # Test JWT creation
        from api.v1.endpoints.auth import create_access_token
        print("✅ JWT functions imported")
        
        # Test schema
        from core.schemas import Token
        print("✅ Token schema imported")
        
        # Test actual user retrieval
        db = next(get_db())
        user = db.query(User).filter(User.email == "test@healthanalytics.com").first()
        if user:
            print(f"✅ User found: {user.email}")
            print(f"   User ID: {user.id} (type: {type(user.id)})")
            
            # Test password verification
            test_password = "testpassword123"
            if pwd_context.verify(test_password, user.hashed_password):
                print("✅ Password verification successful")
                
                # Test token creation
                token_str = create_access_token(str(user.id))
                print(f"✅ Token created: {token_str[:50]}...")
                
                # Test token object creation
                token_obj = Token(access_token=token_str, token_type="bearer")
                print("✅ Token object created")
                
                # Test serialization
                token_dict = token_obj.model_dump()
                print(f"✅ Token serialized: {list(token_dict.keys())}")
                
                return {
                    "access_token": token_str,
                    "token_type": "bearer"
                }
            else:
                print("❌ Password verification failed")
        else:
            print("❌ User not found")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    result = test_auth_components()
    if result:
        print(f"\n🎉 SUCCESS! Authentication token: {result}")
    else:
        print("\n❌ FAILED!") 