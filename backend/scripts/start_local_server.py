#!/usr/bin/env python3
"""
Local Development Server Startup Script for Phase 5 Week 1

This script starts the FastAPI server with proper configuration for local testing,
including database initialization, sample data seeding, and comprehensive monitoring.
"""

import sys
import os
import subprocess
import time
import requests
from pathlib import Path
from dotenv import load_dotenv

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment configuration
load_dotenv('config/local.env')
load_dotenv('.env')

def check_dependencies():
    """Check if all required dependencies are installed"""
    print("🔍 Checking dependencies...")
    
    try:
        import uvicorn
        import fastapi
        import sqlalchemy
        import pydantic
        print("✅ Core dependencies found")
        return True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        print("💡 Run: pip install -r requirements.txt")
        return False

def setup_directories():
    """Create necessary directories for local development"""
    print("📁 Setting up directories...")
    
    directories = [
        "data/uploads",
        "data/temp", 
        "logs",
        "config"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        print(f"✅ Created directory: {directory}")

def initialize_database():
    """Initialize database and seed with sample data"""
    print("🗄️ Initializing database...")
    
    try:
        # Run database seeding script
        result = subprocess.run([
            sys.executable, 
            "scripts/seed_sample_data.py"
        ], capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(__file__)))
        
        if result.returncode == 0:
            print("✅ Database initialized successfully")
            print(result.stdout)
            return True
        else:
            print(f"❌ Database initialization failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Error initializing database: {e}")
        return False

def test_ai_endpoints():
    """Test that AI endpoints are working"""
    print("🤖 Testing AI endpoints...")
    
    try:
        # Run AI endpoint tests
        result = subprocess.run([
            sys.executable, 
            "test_ai_endpoints.py"
        ], capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(__file__)))
        
        if result.returncode == 0:
            print("✅ AI endpoints test passed")
            return True
        else:
            print(f"❌ AI endpoints test failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing AI endpoints: {e}")
        return False

def start_server():
    """Start the FastAPI server with development configuration"""
    print("🚀 Starting FastAPI server...")
    
    # Server configuration from environment
    host = os.getenv('API_HOST', '0.0.0.0')
    port = int(os.getenv('API_PORT', '8001'))
    reload = os.getenv('API_RELOAD', 'true').lower() == 'true'
    
    try:
        # Start server using uvicorn
        cmd = [
            sys.executable, "-m", "uvicorn",
            "main:app",
            "--host", host,
            "--port", str(port),
            "--reload" if reload else "--no-reload",
            "--log-level", "info",
            "--access-log"
        ]
        
        print(f"🌐 Server starting at http://{host}:{port}")
        print(f"📚 API Documentation: http://localhost:{port}/docs")
        print(f"🔧 Alternative docs: http://localhost:{port}/redoc")
        print(f"❤️ Health check: http://localhost:{port}/health")
        print("\n🛑 Press Ctrl+C to stop the server\n")
        
        # Start the server
        subprocess.run(cmd, cwd=os.path.dirname(os.path.dirname(__file__)))
        
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")

def wait_for_server(host="localhost", port=None, timeout=30):
    """Wait for server to be ready"""
    if port is None:
        port = int(os.getenv('API_PORT', '8001'))
        
    print(f"⏳ Waiting for server at {host}:{port}...")
    
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"http://{host}:{port}/health", timeout=5)
            if response.status_code == 200:
                print("✅ Server is ready!")
                return True
        except requests.exceptions.RequestException:
            pass
        
        time.sleep(1)
    
    print(f"❌ Server not ready after {timeout} seconds")
    return False

def run_health_check():
    """Run comprehensive health check"""
    print("🏥 Running health check...")
    
    port = int(os.getenv('API_PORT', '8001'))
    base_url = f"http://localhost:{port}"
    
    endpoints_to_test = [
        "/health",
        "/api/v1/auth/test",
        "/api/v1/ai/health-score",
        "/api/v1/ai/insights",
        "/api/v1/data-sources/capabilities"
    ]
    
    for endpoint in endpoints_to_test:
        try:
            response = requests.get(f"{base_url}{endpoint}", timeout=10)
            status = "✅" if response.status_code < 400 else "❌"
            print(f"{status} {endpoint} - Status: {response.status_code}")
        except Exception as e:
            print(f"❌ {endpoint} - Error: {e}")

def print_startup_info():
    """Print startup information and instructions"""
    port = int(os.getenv('API_PORT', '8001'))
    
    print("\n" + "="*60)
    print("🎯 PHASE 5 WEEK 1: LOCAL TESTING & VALIDATION")
    print("="*60)
    print("📱 Health & Fitness Analytics Platform")
    print("🤖 AI-Powered Health Coaching System")
    print("="*60)
    
    print("\n📋 TEST CREDENTIALS:")
    print("   Email: test@healthanalytics.com")
    print("   Password: testpassword123")
    
    print("\n🔗 IMPORTANT URLS:")
    print(f"   🌐 API Server: http://localhost:{port}")
    print(f"   📚 API Docs: http://localhost:{port}/docs")
    print(f"   🔧 ReDoc: http://localhost:{port}/redoc")
    print(f"   ❤️ Health: http://localhost:{port}/health")
    
    print("\n🧪 TESTING CHECKLIST:")
    print("   □ User authentication and registration")
    print("   □ Data source connections and preferences")
    print("   □ Health data upload and processing")
    print("   □ AI insights and recommendations")
    print("   □ Goal optimization and coaching")
    print("   □ Achievement tracking and celebrations")
    print("   □ Multi-source data integration")
    print("   □ iOS app backend connectivity")
    
    print("\n🚀 NEXT STEPS:")
    print("   1. Test all API endpoints using /docs interface")
    print("   2. Validate AI processing with sample data")
    print("   3. Test iOS app connection to local backend")
    print("   4. Verify end-to-end user journey")
    print("   5. Performance testing with realistic data loads")
    
    print("\n" + "="*60)

def main():
    """Main startup sequence"""
    print_startup_info()
    
    # Pre-flight checks
    if not check_dependencies():
        return False
    
    setup_directories()
    
    # Initialize database with sample data
    if not initialize_database():
        print("❌ Database initialization failed. Exiting.")
        return False
    
    # Test AI endpoints
    if not test_ai_endpoints():
        print("⚠️ AI endpoints test failed, but continuing...")
    
    # Start the server
    start_server()
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 