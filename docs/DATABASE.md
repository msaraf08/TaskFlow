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
Stores team definitions, manager assignments, and member references.

```json
{
  "_id": "ObjectId",
  "name": "string",
  "description": "string (optional)",
  "manager_id": "string (ForeignKey -> users._id, optional)",
  "member_ids": ["string (ForeignKey -> employees._id)"]
}
```

**Indexes:**
- `_id`: Primary Key (Default)
- `manager_id`: Standard Index (`{ "manager_id": 1 }`)

---

### 4. Planned Collections
- `projects`
- `tasks`
- `comments`
- `notifications`

---

## Index Initialization

Database indexes are automatically created/verified at application startup during the FastAPI `lifespan` handler (`db.init_indexes()`).