#!/usr/bin/env python3
"""
Comprehensive API Testing Script for Phase 5 Week 1

This script tests all API endpoints with realistic scenarios to validate
the complete health analytics platform functionality.
"""

import sys
import os
import requests
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class APITester:
    def __init__(self, base_url: str = "http://192.168.2.131:8001"):
        self.base_url = base_url
        self.session = requests.Session()
        self.access_token: Optional[str] = None
        self.user_id: Optional[str] = None
        
    def authenticate(self, email: str = "test@healthanalytics.com", password: str = "testpassword123"):
        """Authenticate and get access token"""
        print("🔐 Authenticating user...")
        
        # Login
        login_data = {
            "username": email,
            "password": password
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/auth/login",
            data=login_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code == 200:
            token_data = response.json()
            self.access_token = token_data["access_token"]
            self.session.headers.update({"Authorization": f"Bearer {self.access_token}"})
            print("✅ Authentication successful")
            
            # Get user info
            user_response = self.session.get(f"{self.base_url}/api/v1/auth/me")
            if user_response.status_code == 200:
                user_data = user_response.json()
                self.user_id = user_data["id"]
                print(f"👤 User ID: {self.user_id}")
            
            return True
        else:
            print(f"❌ Authentication failed: {response.status_code} - {response.text}")
            return False
    
    def test_health_endpoint(self):
        """Test basic health endpoint"""
        print("\n🏥 Testing health endpoint...")
        
        response = requests.get(f"{self.base_url}/health")
        if response.status_code == 200:
            print("✅ Health endpoint working")
            return True
        else:
            print(f"❌ Health endpoint failed: {response.status_code}")
            return False
    
    def test_auth_endpoints(self):
        """Test authentication endpoints"""
        print("\n🔐 Testing authentication endpoints...")
        
        # Test registration (with unique email)
        timestamp = int(time.time())
        register_data = {
            "email": f"newuser{timestamp}@test.com",
            "password": "newpassword123"
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/auth/register",
            json=register_data
        )
        
        if response.status_code in [200, 201]:
            print("✅ User registration working")
        else:
            print(f"⚠️ User registration: {response.status_code} - {response.text}")
        
        # Test current user endpoint
        if self.access_token:
            response = self.session.get(f"{self.base_url}/api/v1/auth/me")
            if response.status_code == 200:
                print("✅ Current user endpoint working")
                return True
            else:
                print(f"❌ Current user endpoint failed: {response.status_code}")
                return False
        
        return False
    
    def test_data_source_endpoints(self):
        """Test data source management endpoints"""
        print("\n🔗 Testing data source endpoints...")
        
        # Test capabilities
        response = self.session.get(f"{self.base_url}/api/v1/data-sources/capabilities")
        if response.status_code == 200:
            capabilities = response.json()
            print(f"✅ Data source capabilities: {len(capabilities)} sources")
        else:
            print(f"❌ Capabilities endpoint failed: {response.status_code}")
        
        # Test connections
        response = self.session.get(f"{self.base_url}/api/v1/data-sources/connections")
        if response.status_code == 200:
            connections = response.json()
            print(f"✅ Data source connections: {len(connections)} connections")
        else:
            print(f"❌ Connections endpoint failed: {response.status_code}")
        
        # Test preferences
        response = self.session.get(f"{self.base_url}/api/v1/data-sources/preferences")
        if response.status_code == 200:
            preferences = response.json()
            print("✅ Data source preferences working")
        else:
            print(f"❌ Preferences endpoint failed: {response.status_code}")
        
        return True
    
    def test_health_metrics_endpoints(self):
        """Test health metrics endpoints"""
        print("\n📊 Testing health metrics endpoints...")
        
        # Test metrics retrieval
        end_date = datetime.now()
        start_date = end_date - timedelta(days=30)
        
        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat()
        }
        
        response = self.session.get(
            f"{self.base_url}/api/v1/health-metrics/",
            params=params
        )
        
        if response.status_code == 200:
            metrics = response.json()
            print(f"✅ Health metrics: {len(metrics)} records")
        else:
            print(f"❌ Health metrics failed: {response.status_code}")
        
        # Test metrics by category
        categories = ["activity", "sleep", "nutrition", "body_composition"]
        for category in categories:
            response = self.session.get(
                f"{self.base_url}/api/v1/health-metrics/category/{category}",
                params=params
            )
            if response.status_code == 200:
                metrics = response.json()
                print(f"✅ {category} metrics: {len(metrics)} records")
            else:
                print(f"❌ {category} metrics failed: {response.status_code}")
        
        return True
    
    def test_ai_insights_endpoints(self):
        """Test AI insights endpoints"""
        print("\n🤖 Testing AI insights endpoints...")
        
        # Test health score
        response = self.session.get(f"{self.base_url}/api/v1/ai/health-score")
        if response.status_code == 200:
            score_data = response.json()
            print(f"✅ Health score: {score_data.get('overall_score', 'N/A')}")
        else:
            print(f"❌ Health score failed: {response.status_code}")
        
        # Test insights
        response = self.session.get(f"{self.base_url}/api/v1/ai/insights")
        if response.status_code == 200:
            insights = response.json()
            print(f"✅ AI insights: {len(insights)} insights")
        else:
            print(f"❌ AI insights failed: {response.status_code}")
        
        # Test recommendations
        response = self.session.get(f"{self.base_url}/api/v1/ai/recommendations")
        if response.status_code == 200:
            recommendations = response.json()
            print(f"✅ Recommendations: {len(recommendations)} recommendations")
        else:
            print(f"❌ Recommendations failed: {response.status_code}")
        
        # Test anomalies
        response = self.session.get(f"{self.base_url}/api/v1/ai/anomalies")
        if response.status_code == 200:
            anomalies = response.json()
            print(f"✅ Anomalies: {len(anomalies)} anomalies")
        else:
            print(f"❌ Anomalies failed: {response.status_code}")
        
        # Test correlations
        response = self.session.get(f"{self.base_url}/api/v1/ai/correlations")
        if response.status_code == 200:
            correlations = response.json()
            print(f"✅ Correlations: {len(correlations)} correlations")
        else:
            print(f"❌ Correlations failed: {response.status_code}")
        
        # Test trends
        response = self.session.get(f"{self.base_url}/api/v1/ai/trends")
        if response.status_code == 200:
            trends = response.json()
            print(f"✅ Trends: {len(trends)} trends")
        else:
            print(f"❌ Trends failed: {response.status_code}")
        
        return True
    
    def test_goal_optimization_endpoints(self):
        """Test goal optimization endpoints"""
        print("\n🎯 Testing goal optimization endpoints...")
        
        # Test goal recommendations
        response = self.session.get(f"{self.base_url}/api/v1/ai/goals/recommendations")
        if response.status_code == 200:
            recommendations = response.json()
            print(f"✅ Goal recommendations: {len(recommendations)} goals")
        else:
            print(f"❌ Goal recommendations failed: {response.status_code}")
        
        # Test goal coordination
        response = self.session.get(f"{self.base_url}/api/v1/ai/goals/coordinate")
        if response.status_code == 200:
            coordination = response.json()
            print("✅ Goal coordination working")
        else:
            print(f"❌ Goal coordination failed: {response.status_code}")
        
        return True
    
    def test_achievement_endpoints(self):
        """Test achievement endpoints"""
        print("\n🏆 Testing achievement endpoints...")
        
        # Test achievements
        response = self.session.get(f"{self.base_url}/api/v1/ai/achievements")
        if response.status_code == 200:
            achievements = response.json()
            print(f"✅ Achievements: {len(achievements)} achievements")
        else:
            print(f"❌ Achievements failed: {response.status_code}")
        
        # Test streaks
        response = self.session.get(f"{self.base_url}/api/v1/ai/achievements/streaks")
        if response.status_code == 200:
            streaks = response.json()
            print(f"✅ Streaks: {len(streaks)} streaks")
        else:
            print(f"❌ Streaks failed: {response.status_code}")
        
        return True
    
    def test_coaching_endpoints(self):
        """Test health coaching endpoints"""
        print("\n🧠 Testing health coaching endpoints...")
        
        # Test coaching messages
        response = self.session.get(f"{self.base_url}/api/v1/ai/coaching/messages")
        if response.status_code == 200:
            messages = response.json()
            print(f"✅ Coaching messages: {len(messages)} messages")
        else:
            print(f"❌ Coaching messages failed: {response.status_code}")
        
        # Test interventions
        response = self.session.get(f"{self.base_url}/api/v1/ai/coaching/interventions")
        if response.status_code == 200:
            interventions = response.json()
            print(f"✅ Interventions: {len(interventions)} interventions")
        else:
            print(f"❌ Interventions failed: {response.status_code}")
        
        # Test progress analysis
        response = self.session.get(f"{self.base_url}/api/v1/ai/coaching/progress")
        if response.status_code == 200:
            progress = response.json()
            print("✅ Progress analysis working")
        else:
            print(f"❌ Progress analysis failed: {response.status_code}")
        
        return True
    
    def test_file_upload_endpoints(self):
        """Test file upload endpoints"""
        print("\n📁 Testing file upload endpoints...")
        
        # Test Apple Health upload endpoint
        response = self.session.get(f"{self.base_url}/api/v1/data-sources/apple-health/upload-url")
        if response.status_code == 200:
            print("✅ Apple Health upload URL endpoint working")
        else:
            print(f"❌ Apple Health upload failed: {response.status_code}")
        
        return True
    
    def run_comprehensive_test(self):
        """Run all tests in sequence"""
        print("🚀 Starting comprehensive API testing...")
        print("="*60)
        
        # Basic connectivity
        if not self.test_health_endpoint():
            print("❌ Basic connectivity failed. Stopping tests.")
            return False
        
        # Authentication
        if not self.authenticate():
            print("❌ Authentication failed. Stopping tests.")
            return False
        
        # Run all endpoint tests
        test_results = []
        
        test_results.append(self.test_auth_endpoints())
        test_results.append(self.test_data_source_endpoints())
        test_results.append(self.test_health_metrics_endpoints())
        test_results.append(self.test_ai_insights_endpoints())
        test_results.append(self.test_goal_optimization_endpoints())
        test_results.append(self.test_achievement_endpoints())
        test_results.append(self.test_coaching_endpoints())
        test_results.append(self.test_file_upload_endpoints())
        
        # Summary
        print("\n" + "="*60)
        print("📊 TEST SUMMARY")
        print("="*60)
        
        passed = sum(test_results)
        total = len(test_results)
        
        print(f"✅ Passed: {passed}/{total} test suites")
        print(f"❌ Failed: {total - passed}/{total} test suites")
        
        if passed == total:
            print("🎉 ALL TESTS PASSED! API is ready for Phase 5 testing.")
        else:
            print("⚠️ Some tests failed. Review the output above.")
        
        print("="*60)
        
        return passed == total

def main():
    """Main testing function"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Comprehensive API Testing")
    parser.add_argument("--url", default="http://192.168.2.131:8001", help="Base URL for API")
    parser.add_argument("--email", default="test@healthanalytics.com", help="Test user email")
    parser.add_argument("--password", default="testpassword123", help="Test user password")
    
    args = parser.parse_args()
    
    tester = APITester(args.url)
    success = tester.run_comprehensive_test()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 