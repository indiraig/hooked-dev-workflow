"""Pydantic schemas for request/response serialization."""
from pydantic import BaseModel, ConfigDict, EmailStr


class UserBase(BaseModel):
    name: str
    email: EmailStr
    role: str | None = None
    department: str | None = None


class UserCreate(UserBase):
    """Payload for creating a user (all core fields required except role/department)."""
    pass


class UserUpdate(BaseModel):
    """Payload for updating a user — every field is optional (partial update)."""
    name: str | None = None
    email: EmailStr | None = None
    role: str | None = None
    department: str | None = None


class UserOut(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
