import pytest

def test_get_current_user(client):
    # Register and login
    client.post("/api/v1/auth/register", json={
        "email": "user2@example.com",
        "password": "testpassword123"
    })
    login = client.post("/api/v1/auth/login", data={
        "username": "user2@example.com",
        "password": "testpassword123"
    })
    token = login.json()["access_token"]

    # Get current user
    response = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "user2@example.com"

# Add more user CRUD tests as needed 