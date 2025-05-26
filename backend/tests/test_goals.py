import pytest

def test_goals_crud(client):
    # Register and login
    client.post("/api/v1/auth/register", json={
        "email": "goaluser@example.com",
        "password": "testpassword123"
    })
    login = client.post("/api/v1/auth/login", data={
        "username": "goaluser@example.com",
        "password": "testpassword123"
    })
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create a goal
    goal = {
        "goal_type": "steps",
        "target_value": 12000,
        "start_date": "2024-01-01T00:00:00Z",
        "end_date": "2024-01-31T23:59:59Z"
    }
    response = client.post("/api/v1/goals/", json=goal, headers=headers)
    if response.status_code not in (200, 201):
        print(f"Goal creation failed: {response.status_code} - {response.json()}")
    assert response.status_code in (200, 201)
    data = response.json()
    assert data["goal_type"] == "steps"
    goal_id = data["id"]

    # Read goals
    response = client.get("/api/v1/goals/", headers=headers)
    assert response.status_code == 200
    assert any(g["id"] == goal_id for g in response.json())

    # Update goal (if supported)
    # response = client.put(f"/api/v1/goals/{goal_id}", json={"target_value": 15000}, headers=headers)
    # assert response.status_code == 200

    # Delete goal (if supported)
    # response = client.delete(f"/api/v1/goals/{goal_id}", headers=headers)
    # assert response.status_code == 204 