# Database Architecture

## Database Engine & Configuration

- **Database:** MongoDB 8.0
- **Database Name:** `taskflow`
- **Driver:** Motor (`AsyncIOMotorClient`) / PyMongo

---

## Collections & Schemas

### 1. `users`
Stores authentication credentials and account authorization details.

```json
{
  "_id": "ObjectId",
  "name": "string",
  "email": "string",
  "password": "string (bcrypt hash)",
  "role": "string (admin | manager | employee)",
  "status": "string (active | inactive)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `email`: Unique Index (`{ "email": 1 }, unique=True`)

---

### 2. `employees`
Stores employee profiles and organizational data.

```json
{
  "_id": "ObjectId",
  "user_id": "string (ForeignKey -> users._id)",
  "name": "string",
  "email": "string",
  "phone": "string",
  "department": "string",
  "role": "string (admin | manager | employee)",
  "joining_date": "ISODate (datetime)",
  "status": "string (active | inactive)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `email`: Unique Index (`{ "email": 1 }, unique=True`)
- `user_id`: Standard Index (`{ "user_id": 1 }`)

---

### 3. `teams`
Stores team definitions, manager assignments, and member references. The `teams` collection serves as the single source of truth for team membership.

```json
{
  "_id": "ObjectId",
  "name": "string",
  "description": "string (optional)",
  "manager_id": "string (ForeignKey -> employees._id, optional)",
  "member_ids": ["string (ForeignKey -> employees._id)"]
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `manager_id`: Standard Index (`{ "manager_id": 1 }`)

**Relationship Rules:**
- `manager_id` references an active `employees._id` with role `manager` or `admin`.
- `member_ids` contains an array of active `employees._id` references.
- `manager_id` and `member_ids` are kept strictly separated; a manager is not listed in `member_ids`.
- `employees` collection does not store a redundant `team_id`, eliminating dual-write synchronization risks.

---

### 4. `projects`
Stores project records, timeline boundaries, status, team association, and audit metadata. The `projects` collection serves as the single source of truth for project definitions.

```json
{
  "_id": "ObjectId",
  "name": "string (1-120 chars)",
  "description": "string (optional, max 2000 chars)",
  "team_id": "string (ForeignKey -> teams._id)",
  "start_date": "ISODate (datetime)",
  "end_date": "ISODate (datetime)",
  "status": "string (planned | active | completed | cancelled)",
  "created_by": "string (ForeignKey -> users._id)",
  "created_at": "ISODate (datetime)",
  "updated_at": "ISODate (datetime)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `team_id`: Standard Index (`{ "team_id": 1 }`)
- `created_by`: Standard Index (`{ "created_by": 1 }`)
- `status`: Standard Index (`{ "status": 1 }`)

**Relationship Rules:**
- `team_id` references an existing `teams._id`. This is the **only** relationship linking projects and teams.
- Neither `employees.team_id`, `teams.project_ids`, nor `project.member_ids` are used.
- `created_by` references `users._id` (JWT `sub`) and is immutable.
- `start_date` and `end_date` enforce `end_date >= start_date`.

---

### 5. `tasks`
Stores task records, project association, assignee, priority, status lifecycle, due date, and audit timestamps. The `tasks` collection serves as the single source of truth for task records.

```json
{
  "_id": "ObjectId",
  "title": "string (1-200 chars)",
  "description": "string (optional, max 5000 chars)",
  "project_id": "string (ForeignKey -> projects._id)",
  "assigned_to": "string (ForeignKey -> employees._id)",
  "priority": "string (low | medium | high | urgent)",
  "status": "string (todo | in_progress | completed | cancelled)",
  "due_date": "ISODate (datetime)",
  "created_by": "string (ForeignKey -> users._id)",
  "created_at": "ISODate (datetime)",
  "updated_at": "ISODate (datetime)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `project_id`: Standard Index (`{ "project_id": 1 }`)
- `assigned_to`: Standard Index (`{ "assigned_to": 1 }`)
- `status`: Standard Index (`{ "status": 1 }`)
- `priority`: Standard Index (`{ "priority": 1 }`)
- `due_date`: Standard Index (`{ "due_date": 1 }`)
- `created_by`: Standard Index (`{ "created_by": 1 }`)

**Relationship & Eligibility Rules:**
- `Task.project_id -> Project._id` and `Task.assigned_to -> Employee._id`.
- No `project.task_ids`, `employee.task_ids`, or `team.task_ids`.
- Assignee eligibility: To be assigned a task, an employee must be active and either in the project's `Team.member_ids` OR match `Team.manager_id`.
- `created_by` references `users._id` (JWT `sub`) and is immutable.

---

### 6. `comments`
Stores discussion comments on tasks. Comments reference tasks by `task_id` and authors by `user_id`.

```json
{
  "_id": "ObjectId",
  "task_id": "string (ForeignKey -> tasks._id)",
  "user_id": "string (ForeignKey -> users._id, JWT sub)",
  "content": "string (1-2000 chars)",
  "created_at": "ISODate (datetime)",
  "updated_at": "ISODate (datetime)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `task_id`: Standard Index (`{ "task_id": 1 }`)
- `user_id`: Standard Index (`{ "user_id": 1 }`)
- `created_at`: Standard Index (`{ "created_at": 1 }`)

**Relationship Rules:**
- `task_id` references `tasks._id`. Comments are cascade-deleted when a task is deleted.
- `user_id` stores the JWT `sub` of the author (immutable).
- Comments are queried by `task_id`. No `task.comment_ids` array is stored.

---

### 7. `activities`
Stores system activity and audit trail records. Activities capture state-modifying actions across tasks, comments, projects, teams, and employee roles.

```json
{
  "_id": "ObjectId",
  "actor_user_id": "string (ForeignKey -> users._id, JWT sub)",
  "action": "string (task_created | task_updated | task_deleted | task_assigned_changed | task_status_changed | task_priority_changed | task_project_changed | comment_created | comment_updated | comment_deleted | user_role_changed)",
  "entity_type": "string (task | comment | project | team | employee)",
  "entity_id": "string (ObjectId string of affected entity)",
  "task_id": "string (optional, ObjectId string)",
  "project_id": "string (optional, ObjectId string)",
  "team_id": "string (optional, ObjectId string)",
  "metadata": "object (optional flat dict, max 5 key-value pairs, allowed keys: old_value, new_value, title, name, assigned_to, content_preview)",
  "created_at": "ISODate (datetime)"
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `actor_user_id`: Standard Index (`{ "actor_user_id": 1 }`)
- `entity_type, entity_id`: Compound Index (`{ "entity_type": 1, "entity_id": 1 }`)
- `task_id`: Standard Index (`{ "task_id": 1 }`)
- `project_id`: Standard Index (`{ "project_id": 1 }`)
- `team_id`: Standard Index (`{ "team_id": 1 }`)
- `created_at`: Standard Index (`{ "created_at": 1 }`)

**Audit Trail Integrity Rules:**
- Historical activity records are preserved permanently and are NOT deleted when entities (e.g. tasks) are deleted.
- Metadata never contains sensitive data (passwords, JWTs, API keys, or full comment content). Comment previews are capped at 100 characters.

---

### 8. Planned Collections
- `notifications`

---

## Redis In-Memory Storage & Cache Design

Redis functions exclusively as an ephemeral supporting layer for response caching and authentication rate limiting. MongoDB remains the authoritative source of truth.

### Cache Keys & Lifecycles
- `team:{team_id}`: Detail view of a team (TTL: 300 seconds). Invalidated on team update/deletion and member additions/removals.
- `project:{project_id}`: Detail view of a project (TTL: 300 seconds). Invalidated on project update/deletion.
- `task:{task_id}`: Detail view of a task (TTL: 300 seconds). Invalidated on task update/deletion.
- `ratelimit:{endpoint}:{client_ip}`: Fixed-window rate limit counter (TTL: 60 seconds). Max 5 requests per window.

### Cache Rules
- Cached records use JSON serialization and contain a `_cached_at` ISO 8601 timestamp.
- No sensitive credentials, passwords, or JWTs are stored in Redis.
- Authorization checks are performed prior to returning cached records.

---

## Index Initialization

Database indexes are automatically created/verified at application startup during the FastAPI `lifespan` handler (`db.init_indexes()`).