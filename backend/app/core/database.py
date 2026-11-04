from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.core.config import DATABASE_URL, SQLALCHEMY_ECHO, DB_POOL_SIZE, DB_MAX_OVERFLOW

_engine_options = {
    "echo": SQLALCHEMY_ECHO,
    "pool_pre_ping": True,
}
if not DATABASE_URL.startswith("sqlite"):
    _engine_options.update({"pool_recycle": 300, "pool_size": DB_POOL_SIZE, "max_overflow": DB_MAX_OVERFLOW})
else:
    _engine_options.update({"connect_args": {"check_same_thread": False}})

engine = create_engine(DATABASE_URL, **_engine_options)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
