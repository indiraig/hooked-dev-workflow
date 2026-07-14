"""Data-access helpers (equivalent to the Spring Data JpaRepository)."""
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from .models import User
from .schemas import UserCreate, UserUpdate


def find_all(db: Session) -> list[User]:
    return db.query(User).all()


def find_by_id(db: Session, user_id: int) -> User | None:
    return db.query(User).filter(User.id == user_id).first()


def find_by_email(db: Session, email: str) -> User | None:
    return db.query(User).filter(func.lower(User.email) == email.lower()).first()


def search_users(db: Session, query: str) -> list[User]:
    """Case-insensitive search by name, email, or department."""
    like = f"%{query.lower()}%"
    return (
        db.query(User)
        .filter(
            or_(
                func.lower(User.name).like(like),
                func.lower(User.email).like(like),
                func.lower(User.department).like(like),
            )
        )
        .all()
    )


def find_by_role_ignore_case(db: Session, role: str) -> list[User]:
    return db.query(User).filter(func.lower(User.role) == role.lower()).all()


def create_user(db: Session, data: UserCreate) -> User:
    user = User(
        name=data.name,
        email=data.email,
        role=data.role,
        department=data.department,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user(db: Session, user: User, data: UserUpdate) -> User:
    # Only overwrite fields that were actually provided (partial update).
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user: User) -> None:
    db.delete(user)
    db.commit()
