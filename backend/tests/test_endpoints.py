import asyncio
import json
import httpx

async def test_endpoints():
    # First login to get a token
    async with httpx.AsyncClient(timeout=30) as client:
        login_response = await client.post(
            'http://localhost:8001/api/v1/auth/login',
            data={'username': 'test@healthanalytics.com', 'password': 'testpassword123', 'grant_type': 'password'}
        )
        token = login_response.json()['access_token']
        headers = {'Authorization': f'Bearer {token}'}
        
        # Test each endpoint
        endpoints = [
            '/api/v1/ai/health-score',
            '/api/v1/ai/goals/recommendations', 
            '/api/v1/ai/coaching/messages',
            '/api/v1/ai/achievements'
        ]
        
        for endpoint in endpoints:
            try:
                response = await client.get(f'http://localhost:8001{endpoint}', headers=headers)
                print(f'=== {endpoint} ===')
                print(f'Status: {response.status_code}')
                if response.status_code == 200:
                    data = response.json()
                    print(f'Response keys: {list(data.keys())}')
                    print(json.dumps(data, indent=2)[:800] + '...')
                else:
                    print(f'Error: {response.text}')
                print()
            except Exception as e:
                print(f'Error testing {endpoint}: {e}')
                print()

asyncio.run(test_endpoints()) 