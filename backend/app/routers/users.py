"""User API routes.

Full CRUD API for users:
  GET    /api/users               list all users
  GET    /api/users/search?q=...  search by name/email/department
  GET    /api/users/{id}          get one user
  GET    /api/users/role/{role}   list users by role
  POST   /api/users               create a user
  PUT    /api/users/{id}          update a user
  DELETE /api/users/{id}          delete a user
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from .. import repository
from ..database import get_db
from ..schemas import UserCreate, UserOut, UserUpdate

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/search", response_model=list[UserOut])
def search_users(
    q: str = Query(default="", description="search term"),
    db: Session = Depends(get_db),
):
    """Search users by name, email, or department."""
    if not q or not q.strip():
        return repository.find_all(db)
    return repository.search_users(db, q.strip())


@router.get("", response_model=list[UserOut])
def get_all_users(db: Session = Depends(get_db)):
    """Get all users."""
    return repository.find_all(db)


@router.get("/role/{role}", response_model=list[UserOut])
def get_users_by_role(role: str, db: Session = Depends(get_db)):
    """Get all users by role (case-insensitive)."""
    return repository.find_by_role_ignore_case(db, role)


@router.get("/{user_id}", response_model=UserOut)
def get_user_by_id(user_id: int, db: Session = Depends(get_db)):
    """Get user by ID."""
    user = repository.find_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    """Create a new user. Returns 409 if the email is already taken."""
    if repository.find_by_email(db, payload.email):
        raise HTTPException(status_code=409, detail="Email already exists")
    return repository.create_user(db, payload)


@router.put("/{user_id}", response_model=UserOut)
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db)):
    """Update an existing user (partial update supported)."""
    user = repository.find_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.email:
        existing = repository.find_by_email(db, payload.email)
        if existing and existing.id != user_id:
            raise HTTPException(status_code=409, detail="Email already exists")

    return repository.update_user(db, user, payload)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    """Delete a user by ID."""
    user = repository.find_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    repository.delete_user(db, user)
    return None
