import pytest

def test_register_and_login(client):
    # Register a new user
    response = client.post("/api/v1/auth/register", json={
        "email": "testuser@example.com",
        "password": "testpassword123"
    })
    assert response.status_code in (200, 201, 400)  # 400 if already exists

    # Login with the new user
    response = client.post("/api/v1/auth/login", data={
        "username": "testuser@example.com",
        "password": "testpassword123"
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    token = data["access_token"]

    # Access a protected route (e.g., /api/v1/users/me)
    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "testuser@example.com" 