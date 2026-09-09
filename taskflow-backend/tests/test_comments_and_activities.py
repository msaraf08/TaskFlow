import pytest
from httpx import AsyncClient
from tests.test_tasks import setup_task_test_data


@pytest.mark.asyncio
async def test_comment_lifecycle_and_validation(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}
    e2_h = {"Authorization": f"Bearer {data['e2_token']}"}
    inact_h = {"Authorization": f"Bearer {data['inact_token']}"}

    # Create a task in Team 1 (Core API V1), assigned to Employee 1
    task_resp = await client.post(
        "/tasks/",
        headers=m1_h,
        json={
            "title": "API Auth Module",
            "description": "Implement OAuth2/JWT",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "high",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert task_resp.status_code == 201
    task_id = task_resp.json()["id"]

    # 1. Create comment on existing task with valid content by employee 1 (assignee)
    c1_resp = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e1_h,
        json={"content": "Alice's first progress update on task"},
    )
    assert c1_resp.status_code == 201
    c1 = c1_resp.json()
    assert c1["task_id"] == task_id
    assert c1["user_id"] == data["e1_user_id"]
    assert c1["content"] == "Alice's first progress update on task"
    assert "created_at" in c1
    assert "updated_at" in c1
    c1_id = c1["id"]

    # 2. Empty or whitespace-only content -> 422
    err_empty = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e1_h,
        json={"content": "    "},
    )
    assert err_empty.status_code == 422

    # 3. Oversized content (>2000 chars) -> 422
    err_oversized = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e1_h,
        json={"content": "a" * 2001},
    )
    assert err_oversized.status_code == 422

    # 4. Nonexistent task -> 404
    err_notfound = await client.post(
        "/tasks/650000000000000000000099/comments",
        headers=e1_h,
        json={"content": "Valid comment"},
    )
    assert err_notfound.status_code == 404

    # 5. Malformed task_id -> 400
    err_malformed = await client.post(
        "/tasks/not-a-valid-id/comments",
        headers=e1_h,
        json={"content": "Valid comment"},
    )
    assert err_malformed.status_code == 400

    # 6. Inactive user cannot create comment -> 403
    err_inactive = await client.post(
        f"/tasks/{task_id}/comments",
        headers=inact_h,
        json={"content": "Inactive user comment"},
    )
    assert err_inactive.status_code == 403

    # 7. Outsider employee (e2) cannot comment on Team 1 task -> 403
    err_unauth = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e2_h,
        json={"content": "Intruder comment"},
    )
    assert err_unauth.status_code == 403

    # 8. List comments for a task
    list_resp = await client.get(f"/tasks/{task_id}/comments", headers=e1_h)
    assert list_resp.status_code == 200
    comments = list_resp.json()
    assert len(comments) == 1
    assert comments[0]["id"] == c1_id

    # 9. List comments for task with no comments -> 200 with []
    # Create a second task in project 1
    t2_resp = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Clean Task No Comments",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "due_date": "2026-10-01",
        },
    )
    assert t2_resp.status_code == 201
    t2_id = t2_resp.json()["id"]

    empty_list_resp = await client.get(f"/tasks/{t2_id}/comments", headers=e1_h)
    assert empty_list_resp.status_code == 200
    assert empty_list_resp.json() == []

    # 10. List comments with pagination (skip/limit)
    # Add 2 more comments to task 1
    await client.post(f"/tasks/{task_id}/comments", headers=m1_h, json={"content": "Manager comment 2"})
    await client.post(f"/tasks/{task_id}/comments", headers=admin_h, json={"content": "Admin comment 3"})

    pag_resp = await client.get(f"/tasks/{task_id}/comments?skip=0&limit=2", headers=admin_h)
    assert pag_resp.status_code == 200
    assert len(pag_resp.json()) == 2


@pytest.mark.asyncio
async def test_comment_editing_and_deletion_rbac(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    m2_h = {"Authorization": f"Bearer {data['m2_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}
    e2_h = {"Authorization": f"Bearer {data['e2_token']}"}

    # Task on Team 1 (Manager 1, Employee 1)
    task_resp = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Task for Edit/Delete",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "due_date": "2026-10-01",
        },
    )
    task_id = task_resp.json()["id"]

    # Employee 1 posts comment
    c_resp = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e1_h,
        json={"content": "Initial employee comment"},
    )
    assert c_resp.status_code == 201
    c_data = c_resp.json()
    comment_id = c_data["id"]

    # 1. Employee 2 attempts to edit Employee 1's comment -> 403
    edit_e2 = await client.put(
        f"/comments/{comment_id}",
        headers=e2_h,
        json={"content": "Hacked content"},
    )
    assert edit_e2.status_code == 403

    # 2. Employee 1 edits own comment -> 200
    edit_e1 = await client.put(
        f"/comments/{comment_id}",
        headers=e1_h,
        json={"content": "Updated by author"},
    )
    assert edit_e1.status_code == 200
    assert edit_e1.json()["content"] == "Updated by author"

    # 3. Manager 2 (from other team) attempts to edit comment -> 403
    edit_m2 = await client.put(
        f"/comments/{comment_id}",
        headers=m2_h,
        json={"content": "M2 unauthorized edit"},
    )
    assert edit_m2.status_code == 403

    # 4. Manager 1 (team manager) edits comment on managed team's task -> 200
    edit_m1 = await client.put(
        f"/comments/{comment_id}",
        headers=m1_h,
        json={"content": "Manager 1 reviewed and updated"},
    )
    assert edit_m1.status_code == 200
    assert edit_m1.json()["content"] == "Manager 1 reviewed and updated"

    # 5. Admin edits comment -> 200
    edit_admin = await client.put(
        f"/comments/{comment_id}",
        headers=admin_h,
        json={"content": "Admin official remark"},
    )
    assert edit_admin.status_code == 200
    assert edit_admin.json()["content"] == "Admin official remark"

    # 6. Employee 2 attempts to delete comment -> 403
    del_e2 = await client.delete(f"/comments/{comment_id}", headers=e2_h)
    assert del_e2.status_code == 403

    # 7. Manager 1 deletes comment -> 204
    del_m1 = await client.delete(f"/comments/{comment_id}", headers=m1_h)
    assert del_m1.status_code == 204

    # 8. Verify comment is deleted -> 404
    del_again = await client.delete(f"/comments/{comment_id}", headers=admin_h)
    assert del_again.status_code == 404


@pytest.mark.asyncio
async def test_task_deletion_cascade_comments_and_preserves_activities(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
    mock_tasks_collection,
    mock_comments_collection,
    mock_activities_collection,
):
    data = await setup_task_test_data(
        mock_users_collection,
        mock_employees_collection,
        mock_teams_collection,
        mock_projects_collection,
    )

    admin_h = {"Authorization": f"Bearer {data['admin_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}

    # Create task
    t_resp = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Cascade Delete Test Task",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "due_date": "2026-10-01",
        },
    )
    assert t_resp.status_code == 201
    task_id = t_resp.json()["id"]

    # Add comments
    c1 = await client.post(f"/tasks/{task_id}/comments", headers=e1_h, json={"content": "Comment 1"})
    c2 = await client.post(f"/tasks/{task_id}/comments", headers=e1_h, json={"content": "Comment 2"})
    assert c1.status_code == 201
    assert c2.status_code == 201

    # Delete task as admin
    del_resp = await client.delete(f"/tasks/{task_id}", headers=admin_h)
    assert del_resp.status_code == 204

    # Verify task is deleted -> 404
    get_task = await client.get(f"/tasks/{task_id}", headers=admin_h)
    assert get_task.status_code == 404

    # Verify comments are cascade deleted from mock_comments_collection
    comments_in_db = await mock_comments_collection.count_documents({"task_id": task_id})
    assert comments_in_db == 0

    # Verify activities are preserved for this task
    act_resp = await client.get(f"/activities/?task_id={task_id}", headers=admin_h)
    assert act_resp.status_code == 200
    activities = act_resp.json()
    actions = [a["action"] for a in activities]
    assert "task_created" in actions
    assert "comment_created" in actions
    assert "task_deleted" in actions


@pytest.mark.asyncio
async def test_activity_logging_and_filtering(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}
    e2_h = {"Authorization": f"Bearer {data['e2_token']}"}

    # 1. Create task -> logs task_created
    t_resp = await client.post(
        "/tasks/",
        headers=m1_h,
        json={
            "title": "Audit Trail Task",
            "description": "Task for auditing changes",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "low",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert t_resp.status_code == 201
    task_id = t_resp.json()["id"]

    # 2. Priority change -> task_priority_changed
    p_resp = await client.put(f"/tasks/{task_id}", headers=e1_h, json={"priority": "urgent"})
    assert p_resp.status_code == 200

    # 3. Status change -> task_status_changed
    s_resp = await client.put(f"/tasks/{task_id}", headers=e1_h, json={"status": "in_progress"})
    assert s_resp.status_code == 200

    # 4. Project change -> task_project_changed (Manager 1 moves task from Project 1 to Project 3 on Team 3)
    proj_resp = await client.put(f"/tasks/{task_id}", headers=m1_h, json={"project_id": data["p3_id"]})
    assert proj_resp.status_code == 200

    # 5. Comment creation, update, and deletion
    c_resp = await client.post(f"/tasks/{task_id}/comments", headers=e1_h, json={"content": "Initial comment content"})
    assert c_resp.status_code == 201
    c_id = c_resp.json()["id"]

    up_c = await client.put(f"/comments/{c_id}", headers=e1_h, json={"content": "Updated comment content"})
    assert up_c.status_code == 200

    del_c = await client.delete(f"/comments/{c_id}", headers=e1_h)
    assert del_c.status_code == 204

    # 6. Admin lists all activities
    admin_acts = await client.get("/activities/", headers=admin_h)
    assert admin_acts.status_code == 200
    all_acts = admin_acts.json()
    assert len(all_acts) >= 7

    actions = [a["action"] for a in all_acts]
    assert "task_created" in actions
    assert "task_priority_changed" in actions
    assert "task_status_changed" in actions
    assert "task_project_changed" in actions
    assert "comment_created" in actions
    assert "comment_updated" in actions
    assert "comment_deleted" in actions

    # 7. Action filter
    f_prio = await client.get("/activities/?action=task_priority_changed", headers=admin_h)
    assert f_prio.status_code == 200
    assert len(f_prio.json()) == 1
    assert f_prio.json()[0]["metadata"]["new_value"] == "urgent"

    # 8. Actor user filter
    f_actor = await client.get(f"/activities/?actor_user_id={data['e1_user_id']}", headers=admin_h)
    assert f_actor.status_code == 200
    assert all(a["actor_user_id"] == data["e1_user_id"] for a in f_actor.json())

    # 9. Manager scoping: Manager 1 sees activities for Team 1 / Team 3
    m1_acts = await client.get("/activities/", headers=m1_h)
    assert m1_acts.status_code == 200
    assert len(m1_acts.json()) > 0

    # 10. Employee scoping: Employee 1 sees activities for visible tasks; Employee 2 sees 0
    e1_acts = await client.get("/activities/", headers=e1_h)
    assert e1_acts.status_code == 200
    assert len(e1_acts.json()) > 0

    e2_acts = await client.get("/activities/", headers=e2_h)
    assert e2_acts.status_code == 200
    assert len(e2_acts.json()) == 0

    # 11. Malformed ObjectId in filter -> 400
    bad_id = await client.get("/activities/?task_id=invalid-id", headers=admin_h)
    assert bad_id.status_code == 400

    # 12. Invalid action / entity_type -> 422
    bad_action = await client.get("/activities/?action=invalid_act", headers=admin_h)
    assert bad_action.status_code == 422

    bad_entity = await client.get("/activities/?entity_type=invalid_ent", headers=admin_h)
    assert bad_entity.status_code == 422

    # Count existing task_updated activities before single-field priority change
    pre_up_acts = await client.get(f"/activities/?task_id={task_id}&action=task_updated", headers=admin_h)
    assert pre_up_acts.status_code == 200
    pre_up_count = len(pre_up_acts.json())

    # 13. Full-payload form update (including identical due_date) changes only priority (from urgent to low)
    full_update_resp = await client.put(
        f"/tasks/{task_id}",
        headers=m1_h,
        json={
            "title": "Audit Trail Task",
            "description": "Task for auditing changes",
            "project_id": data["p3_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "low",
            "status": "in_progress",
            "due_date": "2026-10-01",
        },
    )
    assert full_update_resp.status_code == 200

    prio_acts = await client.get(f"/activities/?task_id={task_id}&action=task_priority_changed", headers=admin_h)
    assert prio_acts.status_code == 200
    prio_list = prio_acts.json()
    assert len(prio_list) == 2  # first urgent, now low
    latest_prio = prio_list[0]
    assert latest_prio["actor_user_id"] == data["m1_user_id"]
    assert latest_prio["metadata"]["old_value"] == "urgent"
    assert latest_prio["metadata"]["new_value"] == "low"
    assert latest_prio["metadata"]["title"] == "Audit Trail Task"

    # Verify task_updated was NOT logged for single-field priority change
    post_up_acts = await client.get(f"/activities/?task_id={task_id}&action=task_updated", headers=admin_h)
    assert post_up_acts.status_code == 200
    assert len(post_up_acts.json()) == pre_up_count

    # 14. Zero-field change submission produces no new activity
    all_acts_pre_noop = await client.get(f"/activities/?task_id={task_id}", headers=admin_h)
    noop_resp = await client.put(
        f"/tasks/{task_id}",
        headers=m1_h,
        json={
            "title": "Audit Trail Task",
            "description": "Task for auditing changes",
            "project_id": data["p3_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "low",
            "status": "in_progress",
            "due_date": "2026-10-01",
        },
    )
    assert noop_resp.status_code == 200
    all_acts_post_noop = await client.get(f"/activities/?task_id={task_id}", headers=admin_h)
    assert len(all_acts_post_noop.json()) == len(all_acts_pre_noop.json())

    # 15. Multi-field update in one call logs task_updated
    multi_resp = await client.put(
        f"/tasks/{task_id}",
        headers=m1_h,
        json={
            "title": "Multi Field Updated Title",
            "priority": "urgent",
        },
    )
    assert multi_resp.status_code == 200
    multi_acts = await client.get(f"/activities/?task_id={task_id}&action=task_updated", headers=admin_h)
    assert multi_acts.status_code == 200
    assert len(multi_acts.json()) == pre_up_count + 1
    assert multi_acts.json()[0]["metadata"]["title"] == "Multi Field Updated Title"


@pytest.mark.asyncio
async def test_employee_activity_visibility_scoping(
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
    m1_h = {"Authorization": f"Bearer {data['m1_token']}"}
    e1_h = {"Authorization": f"Bearer {data['e1_token']}"}
    e2_h = {"Authorization": f"Bearer {data['e2_token']}"}

    # 1. Manager creates Task A in Team 1 project (P1) assigned to Employee 1 (E1)
    t1_resp = await client.post(
        "/tasks/",
        headers=m1_h,
        json={
            "title": "Task Assigned to E1",
            "description": "E1 Task",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "medium",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert t1_resp.status_code == 201
    t1_id = t1_resp.json()["id"]

    # 2. Manager creates Task B in Team 1 project (P1) assigned to Manager 1 (M1)
    t2_resp = await client.post(
        "/tasks/",
        headers=m1_h,
        json={
            "title": "Task Assigned to Manager",
            "description": "Manager Task",
            "project_id": data["p1_id"],
            "assigned_to": data["m1_emp_id"],
            "priority": "high",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert t2_resp.status_code == 201
    t2_id = t2_resp.json()["id"]

    # 3. Manager 2 creates Task C in Team 2 project (P2) assigned to Employee 2 (E2)
    t3_resp = await client.post(
        "/tasks/",
        headers=admin_h,
        json={
            "title": "Task Assigned to E2",
            "description": "E2 Task",
            "project_id": data["p2_id"],
            "assigned_to": data["e2_emp_id"],
            "priority": "low",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert t3_resp.status_code == 201
    t3_id = t3_resp.json()["id"]

    # Status changes on all 3 tasks
    await client.put(f"/tasks/{t1_id}", headers=e1_h, json={"status": "in_progress"})
    await client.put(f"/tasks/{t2_id}", headers=m1_h, json={"status": "in_progress"})
    await client.put(f"/tasks/{t3_id}", headers=e2_h, json={"status": "in_progress"})

    # Comments on all 3 tasks
    await client.post(f"/tasks/{t1_id}/comments", headers=e1_h, json={"content": "E1 comment on Task 1"})
    await client.post(f"/tasks/{t2_id}/comments", headers=m1_h, json={"content": "Manager comment on Task 2"})
    await client.post(f"/tasks/{t3_id}/comments", headers=e2_h, json={"content": "E2 comment on Task 3"})

    # Verify Admin sees all activities
    admin_acts = await client.get("/activities/", headers=admin_h)
    assert admin_acts.status_code == 200
    admin_task_ids = {a.get("task_id") for a in admin_acts.json() if a.get("task_id")}
    assert t1_id in admin_task_ids
    assert t2_id in admin_task_ids
    assert t3_id in admin_task_ids

    # Verify Manager 1 sees all activities for managed Team 1 (Tasks 1 & 2), but not Team 2 (Task 3)
    m1_acts = await client.get("/activities/", headers=m1_h)
    assert m1_acts.status_code == 200
    m1_task_ids = {a.get("task_id") for a in m1_acts.json() if a.get("task_id")}
    assert t1_id in m1_task_ids
    assert t2_id in m1_task_ids
    assert t3_id not in m1_task_ids

    # Verify Employee 1 (member of Team 1) sees activities for visible Team 1 tasks (Tasks 1 and 2), but NOT Team 2 (Task 3)
    e1_acts = await client.get("/activities/", headers=e1_h)
    assert e1_acts.status_code == 200
    e1_list = e1_acts.json()
    assert len(e1_list) > 0
    e1_task_ids = {a.get("task_id") for a in e1_list if a.get("task_id")}
    assert t1_id in e1_task_ids
    assert t2_id in e1_task_ids
    assert t3_id not in e1_task_ids

    # Verify Employee 2 (member of Team 2) sees activities for Task 3, but NOT Team 1 tasks (Tasks 1 and 2)
    e2_acts = await client.get("/activities/", headers=e2_h)
    assert e2_acts.status_code == 200
    e2_list = e2_acts.json()
    assert len(e2_list) > 0
    e2_task_ids = {a.get("task_id") for a in e2_list if a.get("task_id")}
    assert t3_id in e2_task_ids
    assert t1_id not in e2_task_ids
    assert t2_id not in e2_task_ids

    # Specific task_id query by E1 for inaccessible Task 3 -> empty list
    e1_unassigned_query = await client.get(f"/activities/?task_id={t3_id}", headers=e1_h)
    assert e1_unassigned_query.status_code == 200
    assert len(e1_unassigned_query.json()) == 0


@pytest.mark.asyncio
async def test_name_enrichment_across_apis(
    client: AsyncClient,
    mock_users_collection,
    mock_employees_collection,
    mock_teams_collection,
    mock_projects_collection,
    mock_tasks_collection,
    mock_comments_collection,
    mock_activities_collection,
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

    # 1. Create task - verify assignee_name is enriched with employee's name
    task_resp = await client.post(
        "/tasks/",
        headers=m1_h,
        json={
            "title": "Task with enriched assignee",
            "description": "Checking name enrichment",
            "project_id": data["p1_id"],
            "assigned_to": data["e1_emp_id"],
            "priority": "medium",
            "status": "todo",
            "due_date": "2026-10-01",
        },
    )
    assert task_resp.status_code == 201
    task_data = task_resp.json()
    assert task_data["assignee_name"] == "Employee One"
    task_id = task_data["id"]

    # 2. Get task by ID - verify assignee_name
    get_task_resp = await client.get(f"/tasks/{task_id}", headers=admin_h)
    assert get_task_resp.status_code == 200
    assert get_task_resp.json()["assignee_name"] == "Employee One"

    # 3. List tasks - verify assignee_name
    list_tasks_resp = await client.get("/tasks/", headers=admin_h)
    assert list_tasks_resp.status_code == 200
    matched = [t for t in list_tasks_resp.json() if t["id"] == task_id]
    assert len(matched) == 1
    assert matched[0]["assignee_name"] == "Employee One"

    # 4. Update task - verify assignee_name on updated task
    update_task_resp = await client.put(
        f"/tasks/{task_id}",
        headers=m1_h,
        json={"assigned_to": data["m1_emp_id"]},
    )
    assert update_task_resp.status_code == 200
    assert update_task_resp.json()["assignee_name"] == "Manager One"

    # 5. Create comment - verify author_name is enriched with user's name
    c_resp = await client.post(
        f"/tasks/{task_id}/comments",
        headers=e1_h,
        json={"content": "Enriched comment author"},
    )
    assert c_resp.status_code == 201
    c_data = c_resp.json()
    assert c_data["author_name"] == "Employee One"
    comment_id = c_data["id"]

    # 6. List comments - verify author_name
    list_c_resp = await client.get(f"/tasks/{task_id}/comments", headers=admin_h)
    assert list_c_resp.status_code == 200
    c_list = list_c_resp.json()
    assert len(c_list) >= 1
    assert c_list[0]["author_name"] == "Employee One"

    # 7. Update comment - verify author_name
    up_c_resp = await client.put(
        f"/comments/{comment_id}",
        headers=e1_h,
        json={"content": "Updated content author test"},
    )
    assert up_c_resp.status_code == 200
    assert up_c_resp.json()["author_name"] == "Employee One"

    # 8. List activities - verify actor_name is enriched across activity records
    act_resp = await client.get(f"/activities/?task_id={task_id}", headers=admin_h)
    assert act_resp.status_code == 200
    activities = act_resp.json()
    assert len(activities) >= 1
    for act in activities:
        assert act["actor_name"] in ("Manager One", "Employee One", "Admin User")

