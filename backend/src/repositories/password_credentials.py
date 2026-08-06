from datetime import UTC, datetime

from sqlalchemy.orm import Session

from src.models.password_credentials import (
    PasswordCredential,
)


class PasswordCredentialRepository:
    def __init__(
        self,
        db: Session,
    ) -> None:
        self._db = db

    def get_by_user_id(
        self,
        user_id: int,
    ) -> PasswordCredential | None:
        return self._db.get(
            PasswordCredential,
            user_id,
        )

    def create(
        self,
        *,
        user_id: int,
        password_hash: str,
    ) -> PasswordCredential:
        credential = PasswordCredential(
            user_id=user_id,
            password_hash=password_hash,
        )

        self._db.add(credential)
        self._db.flush()
        self._db.refresh(credential)

        return credential

    def update_password(
        self,
        credential: PasswordCredential,
        *,
        password_hash: str,
    ) -> PasswordCredential:
        credential.password_hash = password_hash
        credential.password_changed_at = (
            datetime.now(UTC)
        )

        self._db.flush()
        self._db.refresh(credential)

        return credential
