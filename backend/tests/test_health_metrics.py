import pytest

def test_health_metrics_crud(client):
    # Register and login
    client.post("/api/v1/auth/register", json={
        "email": "metricsuser@example.com",
        "password": "testpassword123"
    })
    login = client.post("/api/v1/auth/login", data={
        "username": "metricsuser@example.com",
        "password": "testpassword123"
    })
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create a health metric
    metric = {
        "metric_type": "steps",
        "value": 10000,
        "source": "test_device",
        "timestamp": "2024-01-01T12:00:00Z"
    }
    response = client.post("/api/v1/health-metrics/", json=metric, headers=headers)
    assert response.status_code in (200, 201)
    data = response.json()
    assert data["metric_type"] == "steps"
    metric_id = data["id"]

    # Read health metrics
    response = client.get("/api/v1/health-metrics/", headers=headers)
    assert response.status_code == 200
    assert any(m["id"] == metric_id for m in response.json())

    # Update health metric (if supported)
    # response = client.put(f"/api/v1/health-metrics/{metric_id}", json={"value": 12000}, headers=headers)
    # assert response.status_code == 200

    # Delete health metric (if supported)
    # response = client.delete(f"/api/v1/health-metrics/{metric_id}", headers=headers)
    # assert response.status_code == 204 