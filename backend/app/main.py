"""FastAPI application entry point (replaces AiHooksDemoApplication)."""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, SessionLocal, engine
from .routers import users
from .seed import seed_database

ALLOWED_ORIGINS = [
    "http://localhost:5173",
    "http://localhost:3000",
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create schema and seed demo data on startup.
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title="User Search API - AI Hooks Demo",
    description="User Search API converted from Spring Boot to FastAPI",
    version="0.0.1",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router)


@app.get("/health", tags=["health"])
def health():
    return {"status": "UP"}
