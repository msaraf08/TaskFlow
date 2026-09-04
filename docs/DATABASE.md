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

### 4. Planned Collections
- `projects`
- `tasks`
- `comments`
- `notifications`

---

## Index Initialization

Database indexes are automatically created/verified at application startup during the FastAPI `lifespan` handler (`db.init_indexes()`).