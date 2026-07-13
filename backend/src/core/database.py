from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from src.core.config import settings

# Bağlantıları yöneten ana SQLAlchemy nesnesidir.
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
)

# Session oluşturur.
SessionLocal = sessionmaker(
    bind=engine,
    class_=Session,
    autoflush=False,
    expire_on_commit=False,
)

# Bütün SQLAlchemy ORM modellerinin temel sınıfı.
class Base(DeclarativeBase):
    pass




# SQLAlchemy’nin genel altyapısını oluşturur.