import pytest
import httpx

BASE = "http://localhost:8000"

@pytest.mark.asyncio
async def test_health():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BASE}/health")
        assert r.status_code == 200
        assert r.json()["status"] == "ok"

@pytest.mark.asyncio
async def test_register_and_login():
    async with httpx.AsyncClient() as client:
        # Register
        r = await client.post(f"{BASE}/api/auth/register", json={
            "name": "Test Tourist",
            "email": "pytest@test.com",
            "phone": "9000000099",
            "password": "Test@123",
            "aadhaar_number": "1234-5678-0099"
        })
        assert r.status_code in [200, 201, 400]  # 400 if already exists

        # Login
        r = await client.post(f"{BASE}/api/auth/login", json={
            "email": "pytest@test.com",
            "password": "Test@123"
        })
        assert r.status_code == 200
        assert "token" in r.json()

@pytest.mark.asyncio
async def test_active_tourists():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BASE}/api/tourists/active")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

@pytest.mark.asyncio
async def test_zones():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BASE}/api/zones/")
        assert r.status_code == 200

@pytest.mark.asyncio
async def test_agents_status():
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{BASE}/api/agents/status")
        assert r.status_code == 200
        data = r.json()
        assert "safety_agent" in data
        assert "chat_agent" in data
