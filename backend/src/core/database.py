from sqlalchemy import create_engine
from sqlalchemy.orm import (
    DeclarativeBase,
    Session,
    sessionmaker,
)

from src.core.config import settings


connect_args: dict[str, str] = {}

if settings.DATABASE_URL.startswith("postgresql"):
    connect_args["options"] = (
        "-c statement_timeout="
        f"{settings.DATABASE_STATEMENT_TIMEOUT_MS}"
    )


engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    pool_timeout=settings.DATABASE_POOL_TIMEOUT,
    connect_args=connect_args,
)


SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass




# SQLAlchemy’nin genel altyapısını oluşturur.