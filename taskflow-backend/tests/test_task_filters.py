from datetime import date, datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from tests.test_tasks import setup_task_test_data


@pytest.mark.asyncio
async def test_task_search_and_filters(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
    mock_tasks_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}

    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=2)
    tomorrow = today + timedelta(days=2)

    # Task 1: "Implement Authentication Flow", high priority, todo, due yesterday (overdue)
    t1 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Implement Authentication Flow",
            "description": "Create JWT login and password hashing for backend",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "high",
            "status": "todo",
            "due_date": yesterday.isoformat(),
        },
    )
    assert t1.status_code == 201

    # Task 2: "Setup MongoDB Database [Core]", medium priority, in_progress, due tomorrow
    t2 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Setup MongoDB Database [Core]",
            "description": "Configure indexes and connection pooling",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "medium",
            "status": "in_progress",
            "due_date": tomorrow.isoformat(),
        },
    )
    assert t2.status_code == 201

    # Task 3: "Design Landing Page UI", low priority, completed, due yesterday (not overdue because completed)
    t3 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Design Landing Page UI",
            "description": "Create modern Flutter components",
            "project_id": data["p2_id"],
            "assigned_to": data["e2_emp_id"],
            "priority": "low",
            "status": "completed",
            "due_date": yesterday.isoformat(),
        },
    )
    assert t3.status_code == 201

    # Task 4: "Bugfix: regex (special? +chars*)", urgent priority, todo, due today
    t4 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Bugfix: regex (special? +chars*)",
            "description": "Handle regex escaping safely without crash",
            "project_id": data["p2_id"],
            "assigned_to": data["e2_emp_id"],
            "priority": "urgent",
            "status": "todo",
            "due_date": today.isoformat(),
        },
    )
    assert t4.status_code == 201

    # Task 5: "Backlog Item with No Due Date", medium priority, todo, due_date omitted
    t5 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Backlog Item with No Due Date",
            "description": "Exploratory research without deadline",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "medium",
            "status": "todo",
        },
    )
    assert t5.status_code == 201
    assert t5.json()["due_date"] is None

    # 1. Search by title substring ("Authentication")
    res = await client.get("/tasks/", params={"search": "authentication"}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Implement Authentication Flow"

    # 2. Search by description substring ("Flutter")
    res = await client.get("/tasks/", params={"search": "Flutter"}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Design Landing Page UI"

    # 3. Search with special regex characters ("(special? +chars*)")
    res = await client.get("/tasks/", params={"search": "(special? +chars*)"}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert "regex (special?" in items[0]["title"]

    # 4. Filter by status ("in_progress")
    res = await client.get("/tasks/", params={"status": "in_progress"}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Setup MongoDB Database [Core]"

    # 5. Filter by priority ("urgent")
    res = await client.get("/tasks/", params={"priority": "urgent"}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["priority"] == "urgent"

    # 6. Filter by overdue=true
    # Task 1 is todo and due yesterday -> overdue
    # Task 3 is completed and due yesterday -> not overdue
    # Task 5 has no due date -> not overdue
    res = await client.get("/tasks/", params={"overdue": True}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Implement Authentication Flow"

    # 7. Filter by due_date
    res = await client.get("/tasks/", params={"due_date": today.isoformat()}, headers=admin_h)
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Bugfix: regex (special? +chars*)"

    # 8. Combined filter: project_id + status (P1 has Task 1 and Task 5 with todo)
    res = await client.get(
        "/tasks/",
        params={"project_id": data["p1_id"], "status": "todo"},
        headers=admin_h,
    )
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 2
    titles = [it["title"] for it in items]
    assert "Implement Authentication Flow" in titles
    assert "Backlog Item with No Due Date" in titles


@pytest.mark.asyncio
async def test_rbac_boundary_with_filters_and_search(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )
    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}
    today = datetime.now(timezone.utc).date()

    # Project 1 is in Team 1 (managed by Manager 1, member Employee 1)
    # Project 2 is in Team 2 (managed by Manager 2, member Employee 2)

    # Create task in P1
    r1 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Confidential P1 Task",
            "description": "P1 secret details",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "high",
            "status": "todo",
            "due_date": today.isoformat(),
        },
    )
    assert r1.status_code == 201

    # Create task in P2
    r2 = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Confidential P2 Task",
            "description": "P2 secret details",
            "project_id": data["p2_id"],
            "assigned_to": data["e2_emp_id"],
            "priority": "high",
            "status": "todo",
            "due_date": today.isoformat(),
        },
    )
    assert r2.status_code == 201

    # Manager 1 searches "Confidential" -> only sees P1 task
    res_m1 = await client.get("/tasks/", params={"search": "Confidential"}, headers=m1_h)
    assert res_m1.status_code == 200
    items_m1 = res_m1.json()
    assert len(items_m1) == 1
    assert items_m1[0]["title"] == "Confidential P1 Task"

    # Employee 1 searches "Confidential" -> only sees P1 task
    res_e1 = await client.get("/tasks/", params={"search": "Confidential"}, headers=e1_h)
    assert res_e1.status_code == 200
    items_e1 = res_e1.json()
    assert len(items_e1) == 1
    assert items_e1[0]["title"] == "Confidential P1 Task"

    # Manager 1 searches for P2 directly -> blocked / empty
    res_m1_p2 = await client.get("/tasks/", params={"project_id": data["p2_id"]}, headers=m1_h)
    assert res_m1_p2.status_code == 200
    assert len(res_m1_p2.json()) == 0
