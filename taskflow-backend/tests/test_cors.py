import pytest


@pytest.mark.asyncio
async def test_cors_preflight_options_auth_register(client):
    headers = {
        "Origin": "http://localhost:54321",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization, content-type",
    }
    resp = await client.options("/auth/register", headers=headers)
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") == "http://localhost:54321"
    assert resp.headers.get("access-control-allow-credentials") == "true"
    allow_methods = resp.headers.get("access-control-allow-methods", "")
    assert "POST" in allow_methods
    assert "OPTIONS" in allow_methods


@pytest.mark.asyncio
async def test_cors_preflight_options_auth_login(client):
    headers = {
        "Origin": "http://127.0.0.1:3000",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization, content-type",
    }
    resp = await client.options("/auth/login", headers=headers)
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") == "http://127.0.0.1:3000"
    assert resp.headers.get("access-control-allow-credentials") == "true"


@pytest.mark.asyncio
async def test_cors_actual_request_headers(client):
    headers = {
        "Origin": "http://localhost:8080",
    }
    resp = await client.get("/health", headers=headers)
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") == "http://localhost:8080"
    assert resp.headers.get("access-control-allow-credentials") == "true"


@pytest.mark.asyncio
async def test_cors_disallowed_origin_rejected(client):
    headers = {
        "Origin": "http://unauthorized-domain.com",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization, content-type",
    }
    resp = await client.options("/auth/login", headers=headers)
    assert resp.headers.get("access-control-allow-origin") is None
