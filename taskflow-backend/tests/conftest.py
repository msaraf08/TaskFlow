import copy
from typing import Any, Dict, List, Optional
from bson import ObjectId
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.database.dependencies import (
    get_user_collection,
    get_employee_collection,
    get_team_collection
)


class InMemoryAsyncCursor:
    def __init__(self, documents: List[Dict[str, Any]]):
        self.documents = copy.deepcopy(documents)
        self.index = 0

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self.index < len(self.documents):
            doc = self.documents[self.index]
            self.index += 1
            return doc
        raise StopAsyncIteration


class InsertResult:
    def __init__(self, inserted_id: ObjectId):
        self.inserted_id = inserted_id


class UpdateResult:
    def __init__(self, matched_count: int, modified_count: int):
        self.matched_count = matched_count
        self.modified_count = modified_count


class DeleteResult:
    def __init__(self, deleted_count: int):
        self.deleted_count = deleted_count


class InMemoryAsyncCollection:
    def __init__(self):
        self.docs: List[Dict[str, Any]] = []

    def _matches(self, doc: Dict[str, Any], query: Dict[str, Any]) -> bool:
        for k, v in query.items():
            if k == "_id":
                if doc.get("_id") != v:
                    return False
            elif isinstance(doc.get(k), list) and not isinstance(v, list):
                if v not in doc[k]:
                    return False
            elif doc.get(k) != v:
                return False
        return True

    async def find_one(self, query: Dict[str, Any], projection: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        for d in self.docs:
            if self._matches(d, query):
                res = copy.deepcopy(d)
                if projection:
                    for pk, pv in projection.items():
                        if pv == 0 and pk in res:
                            del res[pk]
                return res
        return None

    def find(self, query: Optional[Dict[str, Any]] = None, projection: Optional[Dict[str, Any]] = None) -> InMemoryAsyncCursor:
        if query is None:
            query = {}
        matched = []
        for d in self.docs:
            if self._matches(d, query):
                res = copy.deepcopy(d)
                if projection:
                    for pk, pv in projection.items():
                        if pv == 0 and pk in res:
                            del res[pk]
                matched.append(res)
        return InMemoryAsyncCursor(matched)

    async def insert_one(self, doc: Dict[str, Any]) -> InsertResult:
        doc_copy = copy.deepcopy(doc)
        if "_id" not in doc_copy:
            doc_copy["_id"] = ObjectId()
        self.docs.append(doc_copy)
        return InsertResult(doc_copy["_id"])

    async def update_one(self, query: Dict[str, Any], update: Dict[str, Any]) -> UpdateResult:
        matched = 0
        modified = 0
        set_fields = update.get("$set", {})
        add_fields = update.get("$addToSet", {})
        pull_fields = update.get("$pull", {})

        for d in self.docs:
            if self._matches(d, query):
                matched += 1
                for k, v in set_fields.items():
                    d[k] = copy.deepcopy(v)
                for k, v in add_fields.items():
                    if k not in d or not isinstance(d[k], list):
                        d[k] = []
                    if v not in d[k]:
                        d[k].append(copy.deepcopy(v))
                for k, v in pull_fields.items():
                    if k in d and isinstance(d[k], list):
                        d[k] = [item for item in d[k] if item != v]
                modified += 1
                break
        return UpdateResult(matched, modified)

    async def delete_one(self, query: Dict[str, Any]) -> DeleteResult:
        for i, d in enumerate(self.docs):
            if self._matches(d, query):
                del self.docs[i]
                return DeleteResult(1)
        return DeleteResult(0)

    async def count_documents(self, query: Dict[str, Any]) -> int:
        return sum(1 for d in self.docs if self._matches(d, query))

    async def create_index(self, *args, **kwargs):
        pass


@pytest.fixture
def mock_users_collection():
    return InMemoryAsyncCollection()


@pytest.fixture
def mock_employees_collection():
    return InMemoryAsyncCollection()


@pytest.fixture
def mock_teams_collection():
    return InMemoryAsyncCollection()


@pytest.fixture
async def client(mock_users_collection, mock_employees_collection, mock_teams_collection):
    app.dependency_overrides[get_user_collection] = lambda: mock_users_collection
    app.dependency_overrides[get_employee_collection] = lambda: mock_employees_collection
    app.dependency_overrides[get_team_collection] = lambda: mock_teams_collection

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()
