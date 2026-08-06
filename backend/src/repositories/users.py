from sqlalchemy import select
from sqlalchemy.orm import Session

from src.models.users import User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(
        self,
        user_id: int,
    ) -> User | None:
        return self._db.get(User, user_id)

    def get_by_email(
        self,
        email: str,
    ) -> User | None:
        statement = select(User).where(
            User.email == email,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def get_by_username(
        self,
        username: str,
    ) -> User | None:
        statement = select(User).where(
            User.username == username,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def get_by_login(
        self,
        *,
        email: str | None = None,
        username: str | None = None,
    ) -> User | None:
        if (email is None) == (username is None):
            raise ValueError(
                "Exactly one of email or username must be provided."
            )

        if email is not None:
            return self.get_by_email(email)

        if username is not None:
            return self.get_by_username(username)

        raise ValueError(
            "A login identifier must be provided."
        )

    def exists_by_email(
        self,
        email: str,
    ) -> bool:
        statement = (
            select(User.id)
            .where(User.email == email)
            .limit(1)
        )

        return self._db.scalar(statement) is not None

    def exists_by_username(
        self,
        username: str,
    ) -> bool:
        statement = (
            select(User.id)
            .where(User.username == username)
            .limit(1)
        )

        return self._db.scalar(statement) is not None

    def create(
        self,
        *,
        email: str,
        username: str,
        full_name: str | None,
    ) -> User:
        user = User(
            email=email,
            username=username,
            full_name=full_name,
        )

        self._db.add(user)
        self._db.flush()
        self._db.refresh(user)

        return user

    def update_profile(
        self,
        user: User,
        *,
        username: str,
        full_name: str | None,
    ) -> User:
        user.username = username
        user.full_name = full_name

        self._db.flush()
        self._db.refresh(user)

        return user