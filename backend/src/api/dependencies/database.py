from collections.abc import Generator
from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from src.core.database import SessionLocal
from src.core.exceptions import AppException

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()

    try:
        yield db
        db.commit()
    except AppException as exc:
        if exc.commit_transaction:
            try:
                db.commit()
            except Exception:
                db.rollback()
                raise
        else:
            db.rollback()

        raise
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


DbSession = Annotated[
    Session,
    Depends(get_db, scope="function"),
]


# Her HTTP isteği için session açma, commit/rollback ve kapatma.