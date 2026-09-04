import pytest
from datetime import datetime, timezone
from httpx import AsyncClient
import json

from app.database.redis import (
    RedisManager,
    redis_manager,
    cache_get,
    cache_set,
    cache_delete,
    cache_delete_pattern,
)
from app.config.settings import Settings
from app.core.security import hash_password
from app.core.jwt import create_access_token


class TestRedisConnectionAndLifecycle:
    @pytest.mark.asyncio
    async def test_redis_ping_succeeds_when_available(self, mock_redis):
        assert await redis_manager.ping() is True

    @pytest.mark.asyncio
    async def test_redis_ping_fails_gracefully_when_none(self):
        original_client = redis_manager.client
        redis_manager.client = None
        try:
            assert await redis_manager.ping() is False
        finally:
            redis_manager.client = original_client

    @pytest.mark.asyncio
    async def test_fastapi_starts_when_redis_unavailable(self, monkeypatch):
        mgr = RedisManager()
        # Mock connect to throw exception
        def mock_from_url(*args, **kwargs):
            raise ConnectionError("Redis server unreachable")

        monkeypatch.setattr("redis.asyncio.from_url", mock_from_url)
        await mgr.connect()
        assert mgr.client is None
        assert await mgr.ping() is False

    @pytest.mark.asyncio
    async def test_redis_config_fallback_settings(self):
        s = Settings(
            redis_url="redis://custom-host:6380/2",
            redis_host="custom-host",
            redis_port=6380,
            redis_db=2,
        )
        assert s.redis_url == "redis://custom-host:6380/2"
        assert s.redis_host == "custom-host"
        assert s.redis_port == 6380
        assert s.redis_db == 2

    @pytest.mark.asyncio
    async def test_graceful_redis_shutdown(self):
        mgr = RedisManager()
        class DummyClient:
            closed = False
            async def close(self):
                self.closed = True
        dummy = DummyClient()
        mgr.client = dummy
        await mgr.disconnect()
        assert dummy.closed is True
        assert mgr.client is None


class TestDetailEndpointsCaching:
    @pytest.fixture
    async def setup_test_data(
        self,
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
        mock_tasks_collection,
    ):
        # 1. Admin
        admin_res = await mock_users_collection.insert_one({
            "name": "Admin User",
            "email": "admin@example.com",
            "password": hash_password("AdminPass123!"),
            "role": "admin",
            "status": "active",
        })
        admin_id = str(admin_res.inserted_id)
        await mock_employees_collection.insert_one({
            "user_id": admin_id,
            "department": "Executive",
            "position": "Administrator",
            "status": "active",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })

        # 2. Manager
        mgr_user_res = await mock_users_collection.insert_one({
            "name": "Manager User",
            "email": "manager@example.com",
            "password": hash_password("ManagerPass123!"),
            "role": "manager",
            "status": "active",
        })
        mgr_user_id = str(mgr_user_res.inserted_id)
        mgr_emp_res = await mock_employees_collection.insert_one({
            "user_id": mgr_user_id,
            "department": "Engineering",
            "position": "Team Lead",
            "status": "active",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        mgr_emp_id = str(mgr_emp_res.inserted_id)

        # 3. Employee 1 (Team member)
        emp1_user_res = await mock_users_collection.insert_one({
            "name": "Member User",
            "email": "member@example.com",
            "password": hash_password("MemberPass123!"),
            "role": "employee",
            "status": "active",
        })
        emp1_user_id = str(emp1_user_res.inserted_id)
        emp1_emp_res = await mock_employees_collection.insert_one({
            "user_id": emp1_user_id,
            "department": "Engineering",
            "position": "Software Engineer",
            "status": "active",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        emp1_emp_id = str(emp1_emp_res.inserted_id)

        # 4. Employee 2 (Outsider)
        emp2_user_res = await mock_users_collection.insert_one({
            "name": "Outsider User",
            "email": "outsider@example.com",
            "password": hash_password("OutsiderPass123!"),
            "role": "employee",
            "status": "active",
        })
        emp2_user_id = str(emp2_user_res.inserted_id)
        emp2_emp_res = await mock_employees_collection.insert_one({
            "user_id": emp2_user_id,
            "department": "Sales",
            "position": "Sales Rep",
            "status": "active",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        emp2_emp_id = str(emp2_emp_res.inserted_id)

        # Team
        team_res = await mock_teams_collection.insert_one({
            "name": "Core Dev",
            "description": "Core development team",
            "manager_id": mgr_emp_id,
            "member_ids": [emp1_emp_id],
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        team_id = str(team_res.inserted_id)

        # Project
        proj_res = await mock_projects_collection.insert_one({
            "name": "Platform Modernization",
            "description": "Platform project",
            "team_id": team_id,
            "start_date": "2026-01-01",
            "end_date": "2026-12-31",
            "status": "planned",
            "created_by": admin_id,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        proj_id = str(proj_res.inserted_id)

        # Task
        task_res = await mock_tasks_collection.insert_one({
            "title": "Setup Caching Layer",
            "description": "Integrate Redis caching for detail endpoints",
            "status": "in_progress",
            "priority": "high",
            "due_date": "2026-06-30",
            "project_id": proj_id,
            "assigned_to": emp1_emp_id,
            "created_by": mgr_user_id,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        task_id = str(task_res.inserted_id)

        return {
            "admin_token": create_access_token({"user_id": admin_id, "role": "admin"}),
            "mgr_token": create_access_token({"user_id": mgr_user_id, "role": "manager"}),
            "member_token": create_access_token({"user_id": emp1_user_id, "role": "employee"}),
            "outsider_token": create_access_token({"user_id": emp2_user_id, "role": "employee"}),
            "team_id": team_id,
            "proj_id": proj_id,
            "task_id": task_id,
            "emp2_emp_id": emp2_emp_id,
        }

    @pytest.mark.asyncio
    async def test_team_detail_cache_miss_and_hit(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        headers = {"Authorization": f"Bearer {data['admin_token']}"}
        team_id = data["team_id"]
        key = f"team:{team_id}"

        assert await mock_redis.get(key) is None

        # Cache Miss
        r1 = await client.get(f"/teams/{team_id}", headers=headers)
        assert r1.status_code == 200
        assert r1.json()["id"] == team_id

        # Check that Redis is populated with 300s TTL and _cached_at
        cached_raw = await mock_redis.get(key)
        assert cached_raw is not None
        cached_obj = json.loads(cached_raw)
        assert cached_obj["id"] == team_id
        assert "_cached_at" in cached_obj
        ttl = await mock_redis.ttl(key)
        assert 0 < ttl <= 300

        # Cache Hit: modify cached name directly to verify response comes from cache
        cached_obj["name"] = "Cached Team Name"
        await mock_redis.set(key, json.dumps(cached_obj), ex=300)

        r2 = await client.get(f"/teams/{team_id}", headers=headers)
        assert r2.status_code == 200
        assert r2.json()["name"] == "Cached Team Name"

    @pytest.mark.asyncio
    async def test_project_detail_cache_miss_and_hit(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        headers = {"Authorization": f"Bearer {data['admin_token']}"}
        proj_id = data["proj_id"]
        key = f"project:{proj_id}"

        assert await mock_redis.get(key) is None

        # Cache miss
        r1 = await client.get(f"/projects/{proj_id}", headers=headers)
        assert r1.status_code == 200
        assert r1.json()["id"] == proj_id

        # Cache populated
        cached_raw = await mock_redis.get(key)
        assert cached_raw is not None
        cached_obj = json.loads(cached_raw)
        assert "_cached_at" in cached_obj

        # Cache hit with edited cached representation
        cached_obj["name"] = "Cached Project Name"
        await mock_redis.set(key, json.dumps(cached_obj), ex=300)

        r2 = await client.get(f"/projects/{proj_id}", headers=headers)
        assert r2.status_code == 200
        assert r2.json()["name"] == "Cached Project Name"

    @pytest.mark.asyncio
    async def test_task_detail_cache_miss_and_hit(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        headers = {"Authorization": f"Bearer {data['admin_token']}"}
        task_id = data["task_id"]
        key = f"task:{task_id}"

        assert await mock_redis.get(key) is None

        # Cache miss
        r1 = await client.get(f"/tasks/{task_id}", headers=headers)
        assert r1.status_code == 200
        assert r1.json()["id"] == task_id

        # Cache populated
        cached_raw = await mock_redis.get(key)
        assert cached_raw is not None
        cached_obj = json.loads(cached_raw)
        assert "_cached_at" in cached_obj

        # Cache hit
        cached_obj["title"] = "Cached Task Title"
        await mock_redis.set(key, json.dumps(cached_obj), ex=300)

        r2 = await client.get(f"/tasks/{task_id}", headers=headers)
        assert r2.status_code == 200
        assert r2.json()["title"] == "Cached Task Title"

    @pytest.mark.asyncio
    async def test_team_cache_invalidation_on_update_and_members(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        headers = {"Authorization": f"Bearer {data['admin_token']}"}
        team_id = data["team_id"]
        key = f"team:{team_id}"

        # Populate cache
        await client.get(f"/teams/{team_id}", headers=headers)
        assert await mock_redis.get(key) is not None

        # 1. Update team -> Invalidate cache
        u_res = await client.put(f"/teams/{team_id}", json={"name": "New Team Name"}, headers=headers)
        assert u_res.status_code == 200
        assert await mock_redis.get(key) is None

        # Repopulate
        await client.get(f"/teams/{team_id}", headers=headers)
        assert await mock_redis.get(key) is not None

        # 2. Add member -> Invalidate cache
        m_res = await client.post(f"/teams/{team_id}/members", json={"employee_id": data["emp2_emp_id"]}, headers=headers)
        assert m_res.status_code == 200
        assert await mock_redis.get(key) is None

        # Repopulate
        await client.get(f"/teams/{team_id}", headers=headers)
        assert await mock_redis.get(key) is not None

        # 3. Remove member -> Invalidate cache
        rem_res = await client.delete(f"/teams/{team_id}/members/{data['emp2_emp_id']}", headers=headers)
        assert rem_res.status_code == 204
        assert await mock_redis.get(key) is None

        # Repopulate
        await client.get(f"/teams/{team_id}", headers=headers)
        assert await mock_redis.get(key) is not None

        # 4. Delete team -> Invalidate cache
        del_res = await client.delete(f"/teams/{team_id}", headers=headers)
        assert del_res.status_code == 204
        assert await mock_redis.get(key) is None

    @pytest.mark.asyncio
    async def test_project_and_task_cache_invalidation_on_mutation(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        headers = {"Authorization": f"Bearer {data['admin_token']}"}
        proj_id = data["proj_id"]
        task_id = data["task_id"]

        # Populate project & task cache
        await client.get(f"/projects/{proj_id}", headers=headers)
        await client.get(f"/tasks/{task_id}", headers=headers)
        assert await mock_redis.get(f"project:{proj_id}") is not None
        assert await mock_redis.get(f"task:{task_id}") is not None

        # 1. Update task -> Invalidate task
        t_res = await client.put(f"/tasks/{task_id}", json={"title": "Updated Task Title"}, headers=headers)
        assert t_res.status_code == 200
        assert await mock_redis.get(f"task:{task_id}") is None

        # Repopulate task
        await client.get(f"/tasks/{task_id}", headers=headers)
        assert await mock_redis.get(f"task:{task_id}") is not None

        # 2. Update project -> Invalidate project
        p_res = await client.put(f"/projects/{proj_id}", json={"name": "Updated Proj Name"}, headers=headers)
        assert p_res.status_code == 200
        assert await mock_redis.get(f"project:{proj_id}") is None

        # 3. Delete task -> Invalidate task
        dt_res = await client.delete(f"/tasks/{task_id}", headers=headers)
        assert dt_res.status_code == 204
        assert await mock_redis.get(f"task:{task_id}") is None

        # 4. Delete project -> Invalidate project
        dp_res = await client.delete(f"/projects/{proj_id}", headers=headers)
        assert dp_res.status_code == 204
        assert await mock_redis.get(f"project:{proj_id}") is None

    @pytest.mark.asyncio
    async def test_authorization_enforced_even_if_entity_is_cached(self, client: AsyncClient, setup_test_data, mock_redis):
        data = setup_test_data
        admin_headers = {"Authorization": f"Bearer {data['admin_token']}"}
        outsider_headers = {"Authorization": f"Bearer {data['outsider_token']}"}
        task_id = data["task_id"]
        team_id = data["team_id"]
        proj_id = data["proj_id"]

        # Populate caches via Admin
        await client.get(f"/teams/{team_id}", headers=admin_headers)
        await client.get(f"/projects/{proj_id}", headers=admin_headers)
        await client.get(f"/tasks/{task_id}", headers=admin_headers)

        assert await mock_redis.get(f"team:{team_id}") is not None
        assert await mock_redis.get(f"project:{proj_id}") is not None
        assert await mock_redis.get(f"task:{task_id}") is not None

        # Outsider employee attempting access MUST receive 403 despite cached entity
        r_team = await client.get(f"/teams/{team_id}", headers=outsider_headers)
        assert r_team.status_code == 403

        r_proj = await client.get(f"/projects/{proj_id}", headers=outsider_headers)
        assert r_proj.status_code == 403

        r_task = await client.get(f"/tasks/{task_id}", headers=outsider_headers)
        assert r_task.status_code == 403


class TestRedisFailureAndFailOpen:
    @pytest.mark.asyncio
    async def test_redis_operations_fail_open_without_crashing(self):
        original_client = redis_manager.client
        redis_manager.client = None

        try:
            assert await cache_get("some:key") is None
            await cache_set("some:key", {"id": "123"})
            await cache_delete("some:key")
            await cache_delete_pattern("some:*")
        finally:
            redis_manager.client = original_client

    @pytest.mark.asyncio
    async def test_api_reads_succeed_when_redis_raises_exceptions(
        self,
        client: AsyncClient,
        mock_teams_collection,
        mock_users_collection,
    ):
        admin_res = await mock_users_collection.insert_one({
            "name": "Admin User",
            "email": "admin2@example.com",
            "password": hash_password("AdminPass123!"),
            "role": "admin",
            "status": "active",
        })
        admin_id = str(admin_res.inserted_id)
        token = create_access_token({"user_id": admin_id, "role": "admin"})
        headers = {"Authorization": f"Bearer {token}"}

        team_res = await mock_teams_collection.insert_one({
            "name": "Fail Open Team",
            "description": "Testing fail open",
            "manager_id": None,
            "member_ids": [],
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        })
        team_id = str(team_res.inserted_id)

        # Simulate Redis client throwing on every operation
        class BrokenRedis:
            async def get(self, *args, **kwargs):
                raise ConnectionError("Redis down")
            async def set(self, *args, **kwargs):
                raise ConnectionError("Redis down")
            async def delete(self, *args, **kwargs):
                raise ConnectionError("Redis down")

        original_client = redis_manager.client
        redis_manager.client = BrokenRedis()

        try:
            # Read should still succeed via MongoDB
            res = await client.get(f"/teams/{team_id}", headers=headers)
            assert res.status_code == 200
            assert res.json()["name"] == "Fail Open Team"

            # Update should still succeed via MongoDB despite cache_delete failure
            u_res = await client.put(f"/teams/{team_id}", json={"name": "Updated Fail Open Team"}, headers=headers)
            assert u_res.status_code == 200
            assert u_res.json()["name"] == "Updated Fail Open Team"
        finally:
            redis_manager.client = original_client


class TestRateLimiter:
    @pytest.mark.asyncio
    async def test_rate_limiter_allows_up_to_5_and_blocks_6th(self, client: AsyncClient):
        # 5 requests should pass validation or return 400 (not 429)
        for _ in range(5):
            res = await client.post("/auth/login", json={"email": "nonexistent@example.com", "password": "wrong"})
            assert res.status_code == 400

        # 6th request must trigger 429 Too Many Requests with Retry-After header
        res6 = await client.post("/auth/login", json={"email": "nonexistent@example.com", "password": "wrong"})
        assert res6.status_code == 429
        assert "Retry-After" in res6.headers
        assert int(res6.headers["Retry-After"]) > 0
        assert res6.json()["detail"] == "Too many requests"

    @pytest.mark.asyncio
    async def test_rate_limiter_password_endpoint(self, client: AsyncClient, mock_users_collection):
        u_res = await mock_users_collection.insert_one({
            "name": "Test User",
            "email": "ratelimit@example.com",
            "password": hash_password("ValidPassword123!"),
            "role": "employee",
            "status": "active",
        })
        user_id = str(u_res.inserted_id)
        token = create_access_token({"user_id": user_id, "role": "employee"})
        headers = {"Authorization": f"Bearer {token}"}

        for _ in range(5):
            res = await client.put("/auth/password", json={"current_password": "WrongPassword1!", "new_password": "NewValidPassword1!"}, headers=headers)
            assert res.status_code == 401

        res6 = await client.put("/auth/password", json={"current_password": "WrongPassword1!", "new_password": "NewValidPassword1!"}, headers=headers)
        assert res6.status_code == 429
        assert "Retry-After" in res6.headers

    @pytest.mark.asyncio
    async def test_rate_limiter_fails_open_when_redis_none(self, client: AsyncClient):
        original_client = redis_manager.client
        redis_manager.client = None

        try:
            # When Redis is None, rate limiter allows all requests
            for _ in range(7):
                res = await client.post("/auth/login", json={"email": "nonexistent@example.com", "password": "wrong"})
                assert res.status_code == 400
        finally:
            redis_manager.client = original_client


class TestRedisDataSafety:
    @pytest.mark.asyncio
    async def test_no_passwords_or_jwt_in_cached_values(self, mock_redis):
        # Verify cached entity structure
        test_team = {
            "id": "64f8a2b1c3d4e5f6a7b8c9d0",
            "name": "Backend Team",
            "description": "Backend services",
            "manager_id": "64f8a2b1c3d4e5f6a7b8c9d1",
            "member_ids": ["64f8a2b1c3d4e5f6a7b8c9d2"],
            "created_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        await cache_set("team:64f8a2b1c3d4e5f6a7b8c9d0", test_team)
        raw = await mock_redis.get("team:64f8a2b1c3d4e5f6a7b8c9d0")
        assert "password" not in raw
        assert "access_token" not in raw
        assert "jwt" not in raw
        assert "secret" not in raw
