"""API tests (ported from UserControllerTest.java)."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import User

# Isolated in-memory test database.
engine = create_engine(
    "sqlite+pysqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def seed_test_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    db.add_all(
        [
            User(name="John Doe", email="john.doe@test.com", role="Engineer", department="Backend"),
            User(name="Jane Smith", email="jane.s@test.com", role="Designer", department="Frontend"),
            User(name="Alice Jones", email="alice.j@test.com", role="Manager", department="Product"),
            User(name="Bob Lee", email="bob.l@test.com", role="Engineer", department="DevOps"),
        ]
    )
    db.commit()
    db.close()
    yield


# TestClient without lifespan so the app's own seed does not touch the test DB.
client = TestClient(app)


def test_get_all_users_returns_all_users():
    resp = client.get("/api/users")
    assert resp.status_code == 200
    assert len(resp.json()) == 4


def test_search_users_by_name_returns_match():
    resp = client.get("/api/users/search", params={"q": "john"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["name"] == "John Doe"


def test_search_users_by_department_returns_match():
    resp = client.get("/api/users/search", params={"q": "backend"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["department"] == "Backend"


def test_search_users_by_email_returns_matches():
    resp = client.get("/api/users/search", params={"q": "test.com"})
    assert resp.status_code == 200
    assert len(resp.json()) == 4


def test_search_users_empty_query_returns_all():
    resp = client.get("/api/users/search", params={"q": ""})
    assert resp.status_code == 200
    assert len(resp.json()) == 4


def test_search_users_no_match_returns_empty():
    resp = client.get("/api/users/search", params={"q": "notexist"})
    assert resp.status_code == 200
    assert len(resp.json()) == 0


def test_get_user_by_id_valid_id_returns_user():
    first_id = client.get("/api/users").json()[0]["id"]
    resp = client.get(f"/api/users/{first_id}")
    assert resp.status_code == 200
    assert resp.json()["id"] == first_id


def test_get_user_by_id_invalid_id_returns_404():
    resp = client.get("/api/users/9999")
    assert resp.status_code == 404


def test_get_users_by_role_returns_matches():
    resp = client.get("/api/users/role/Engineer")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    assert all(u["role"] == "Engineer" for u in data)


def test_get_users_by_role_case_insensitive():
    resp = client.get("/api/users/role/engineer")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_get_users_by_role_no_match_returns_empty():
    resp = client.get("/api/users/role/Unknown")
    assert resp.status_code == 200
    assert len(resp.json()) == 0


def test_create_user_returns_201_and_user():
    payload = {"name": "New Guy", "email": "new.guy@test.com", "role": "Intern", "department": "QA"}
    resp = client.post("/api/users", json=payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["id"] > 0
    assert data["name"] == "New Guy"
    # It should now be retrievable and increase the total count.
    assert len(client.get("/api/users").json()) == 5


def test_create_user_duplicate_email_returns_409():
    payload = {"name": "Dup", "email": "john.doe@test.com", "role": "Engineer", "department": "Backend"}
    resp = client.post("/api/users", json=payload)
    assert resp.status_code == 409


def test_create_user_invalid_email_returns_422():
    payload = {"name": "Bad", "email": "not-an-email", "role": "X", "department": "Y"}
    resp = client.post("/api/users", json=payload)
    assert resp.status_code == 422


def test_update_user_changes_fields():
    user_id = client.get("/api/users").json()[0]["id"]
    resp = client.put(f"/api/users/{user_id}", json={"role": "Lead Engineer"})
    assert resp.status_code == 200
    assert resp.json()["role"] == "Lead Engineer"


def test_update_user_unknown_id_returns_404():
    resp = client.put("/api/users/9999", json={"role": "Ghost"})
    assert resp.status_code == 404


def test_delete_user_returns_204_and_removes_it():
    user_id = client.get("/api/users").json()[0]["id"]
    resp = client.delete(f"/api/users/{user_id}")
    assert resp.status_code == 204
    assert client.get(f"/api/users/{user_id}").status_code == 404
    assert len(client.get("/api/users").json()) == 3


def test_delete_user_unknown_id_returns_404():
    resp = client.delete("/api/users/9999")
    assert resp.status_code == 404
