"""Seed the in-memory database with demo users on startup."""
from sqlalchemy.orm import Session

from .models import User

DEMO_USERS = [
    ("John Doe", "john.doe@example.com", "Engineer", "Backend"),
    ("Jane Smith", "jane.smith@example.com", "Designer", "Frontend"),
    ("Alice Johnson", "alice.j@example.com", "Manager", "Product"),
    ("Bob Williams", "bob.w@example.com", "Engineer", "DevOps"),
    ("Carol Brown", "carol.b@example.com", "Analyst", "Data"),
    ("David Lee", "david.l@example.com", "Engineer", "Backend"),
    ("Eva Martinez", "eva.m@example.com", "Designer", "Frontend"),
    ("Frank Wilson", "frank.w@example.com", "Engineer", "Mobile"),
    ("Grace Taylor", "grace.t@example.com", "Manager", "Engineering"),
    ("Henry Anderson", "henry.a@example.com", "Analyst", "Security"),
]


def seed_database(db: Session) -> None:
    if db.query(User).count() > 0:
        return
    db.add_all(
        User(name=name, email=email, role=role, department=department)
        for name, email, role, department in DEMO_USERS
    )
    db.commit()
