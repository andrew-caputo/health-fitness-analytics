#!/usr/bin/env python3
"""
Comprehensive test script to verify AI endpoints are working
"""

import sys
import os
import asyncio
import traceback

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_ai_imports():
    """Test that all AI modules can be imported"""
    try:
        print("Testing AI module imports...")
        
        # Test core AI modules
        from backend.ai.health_insights_engine import health_insights_engine, HealthInsight, HealthScore
        print("✅ health_insights_engine imported successfully")
        
        from backend.ai.goal_optimizer import GoalOptimizer, GoalDifficulty
        print("✅ goal_optimizer imported successfully")
        
        from backend.ai.achievement_engine import AchievementEngine, Achievement, AchievementType, BadgeLevel, CelebrationLevel
        print("✅ achievement_engine imported successfully")
        
        from backend.ai.health_coach import HealthCoach
        print("✅ health_coach imported successfully")
        
        from backend.ai.recommendation_engine import RecommendationEngine
        print("✅ recommendation_engine imported successfully")
        
        from backend.ai.anomaly_detector import AnomalyDetector
        print("✅ anomaly_detector imported successfully")
        
        from backend.ai.pattern_recognition import PatternRecognizer
        print("✅ pattern_recognition imported successfully")
        
        from backend.ai.correlation_analyzer import CorrelationAnalyzer
        print("✅ correlation_analyzer imported successfully")
        
        # Test ai_insights import
        from backend.api.v1.endpoints import ai_insights
        print("✅ ai_insights endpoint imported successfully")
        
        # Test router exists
        if hasattr(ai_insights, 'router'):
            print("✅ ai_insights.router exists")
            
            # Check routes
            routes = [route.path for route in ai_insights.router.routes if hasattr(route, 'path')]
            print(f"✅ Found {len(routes)} routes in ai_insights router:")
            for route in routes:
                print(f"   - {route}")
        else:
            print("❌ ai_insights.router not found")
            return False
            
        return True
        
    except Exception as e:
        print(f"❌ Error importing AI modules: {e}")
        traceback.print_exc()
        return False

def test_ai_engine_initialization():
    """Test that AI engines can be initialized"""
    try:
        print("\nTesting AI engine initialization...")
        
        from backend.ai.goal_optimizer import GoalOptimizer
        goal_optimizer = GoalOptimizer()
        print("✅ GoalOptimizer initialized successfully")
        
        from backend.ai.achievement_engine import AchievementEngine
        achievement_engine = AchievementEngine()
        print("✅ AchievementEngine initialized successfully")
        
        from backend.ai.health_coach import HealthCoach
        health_coach = HealthCoach()
        print("✅ HealthCoach initialized successfully")
        
        from backend.ai.recommendation_engine import RecommendationEngine
        rec_engine = RecommendationEngine()
        print("✅ RecommendationEngine initialized successfully")
        
        from backend.ai.anomaly_detector import AnomalyDetector
        anomaly_detector = AnomalyDetector()
        print("✅ AnomalyDetector initialized successfully")
        
        from backend.ai.pattern_recognition import PatternRecognizer
        pattern_recognizer = PatternRecognizer()
        print("✅ PatternRecognizer initialized successfully")
        
        from backend.ai.correlation_analyzer import CorrelationAnalyzer
        correlation_analyzer = CorrelationAnalyzer()
        print("✅ CorrelationAnalyzer initialized successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Error initializing AI engines: {e}")
        traceback.print_exc()
        return False

def test_database_models():
    """Test that database models can be imported and used"""
    try:
        print("\nTesting database models...")
        
        from backend.core.models import User, HealthMetricUnified, UserDataSourcePreferences
        print("✅ Database models imported successfully")
        
        # Test model attributes
        user_attrs = ['id', 'email', 'hashed_password', 'created_at', 'updated_at']
        for attr in user_attrs:
            if hasattr(User, attr):
                print(f"✅ User.{attr} exists")
            else:
                print(f"❌ User.{attr} missing")
                return False
        
        metric_attrs = ['id', 'user_id', 'metric_type', 'value', 'unit', 'timestamp', 'data_source']
        for attr in metric_attrs:
            if hasattr(HealthMetricUnified, attr):
                print(f"✅ HealthMetricUnified.{attr} exists")
            else:
                print(f"❌ HealthMetricUnified.{attr} missing")
                return False
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing database models: {e}")
        traceback.print_exc()
        return False

def test_main_router():
    """Test that the main router includes AI endpoints"""
    try:
        print("\nTesting main router...")
        
        from backend.api.v1.router import api_router
        print("✅ Main API router imported successfully")
        
        # Check all routes
        all_routes = []
        for route in api_router.routes:
            if hasattr(route, 'path'):
                all_routes.append(route.path)
            elif hasattr(route, 'path_regex'):
                # For mounted sub-routers
                prefix = getattr(route, 'path', '')
                if hasattr(route, 'app') and hasattr(route.app, 'routes'):
                    for sub_route in route.app.routes:
                        if hasattr(sub_route, 'path'):
                            all_routes.append(f"{prefix}{sub_route.path}")
        
        print(f"✅ Found {len(all_routes)} total routes")
        
        # Look for AI routes
        ai_routes = [route for route in all_routes if '/ai/' in route or route.startswith('/ai')]
        print(f"✅ Found {len(ai_routes)} AI routes:")
        for route in ai_routes:
            print(f"   - {route}")
            
        return len(ai_routes) > 0
        
    except Exception as e:
        print(f"❌ Error testing main router: {e}")
        traceback.print_exc()
        return False

def test_fastapi_app():
    """Test that the FastAPI app includes AI endpoints"""
    try:
        print("\nTesting FastAPI app...")
        
        from main import app
        print("✅ FastAPI app imported successfully")
        
        # Get all routes from the app
        all_routes = []
        for route in app.routes:
            if hasattr(route, 'path'):
                all_routes.append(route.path)
            elif hasattr(route, 'path_regex') and hasattr(route, 'app'):
                # For mounted sub-routers
                prefix = getattr(route, 'path', '')
                if hasattr(route.app, 'routes'):
                    for sub_route in route.app.routes:
                        if hasattr(sub_route, 'path'):
                            full_path = f"{prefix.rstrip('/')}{sub_route.path}"
                            all_routes.append(full_path)
        
        print(f"✅ Found {len(all_routes)} total app routes")
        
        # Look for AI routes
        ai_routes = [route for route in all_routes if '/ai/' in route or '/ai' in route]
        print(f"✅ Found {len(ai_routes)} AI routes in app:")
        for route in ai_routes:
            print(f"   - {route}")
            
        return len(ai_routes) > 0
        
    except Exception as e:
        print(f"❌ Error testing FastAPI app: {e}")
        traceback.print_exc()
        return False

def test_ai_endpoint_functions():
    """Test that AI endpoint functions can be called"""
    try:
        print("\nTesting AI endpoint functions...")
        
        from backend.api.v1.endpoints.ai_insights import (
            test_ai_endpoint,
            get_health_score,
            get_health_insights,
            get_goal_recommendations,
            get_achievements,
            get_coaching_messages
        )
        
        print("✅ AI endpoint functions imported successfully")
        
        # Test the test endpoint (synchronous)
        result = asyncio.run(test_ai_endpoint())
        if result and 'message' in result:
            print("✅ test_ai_endpoint function works")
        else:
            print("❌ test_ai_endpoint function failed")
            return False
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing AI endpoint functions: {e}")
        traceback.print_exc()
        return False

def test_dependencies():
    """Test that all required dependencies are available"""
    try:
        print("\nTesting dependencies...")
        
        import pandas as pd
        print("✅ pandas imported successfully")
        
        import numpy as np
        print("✅ numpy imported successfully")
        
        from sqlalchemy.orm import Session
        print("✅ sqlalchemy imported successfully")
        
        from fastapi import APIRouter, Depends, HTTPException, Query
        print("✅ fastapi imported successfully")
        
        from pydantic import BaseModel
        print("✅ pydantic imported successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing dependencies: {e}")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🧪 Comprehensive AI Endpoints Testing\n")
    
    success = True
    success &= test_dependencies()
    success &= test_database_models()
    success &= test_ai_imports()
    success &= test_ai_engine_initialization()
    success &= test_main_router()
    success &= test_fastapi_app()
    success &= test_ai_endpoint_functions()
    
    print(f"\n{'✅ All tests passed!' if success else '❌ Some tests failed!'}")
    
    if success:
        print("\n🎉 AI endpoints are ready for Phase 5 testing!")
        print("Next steps:")
        print("1. Start the backend server: uvicorn main:app --reload")
        print("2. Test endpoints at: http://localhost:8000/docs")
        print("3. Verify AI endpoints under /ai/ section")
    else:
        print("\n🔧 Please fix the failing tests before proceeding to Phase 5")
    
    sys.exit(0 if success else 1) 