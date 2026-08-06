from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from src.models.auth_identities import (
    AuthIdentity,
)


class AuthIdentityRepository:
    def __init__(
        self,
        db: Session,
    ) -> None:
        self._db = db

    def get_by_provider_subject(
        self,
        *,
        provider: str,
        provider_subject: str,
    ) -> AuthIdentity | None:
        statement = select(AuthIdentity).where(
            AuthIdentity.provider == provider,
            AuthIdentity.provider_subject
            == provider_subject,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def get_by_user_and_provider(
        self,
        *,
        user_id: int,
        provider: str,
    ) -> AuthIdentity | None:
        statement = select(AuthIdentity).where(
            AuthIdentity.user_id == user_id,
            AuthIdentity.provider == provider,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def create(
        self,
        *,
        user_id: int,
        provider: str,
        provider_subject: str,
        email_snapshot: str,
        email_verified: bool,
        display_name: str | None,
        avatar_url: str | None,
    ) -> AuthIdentity:
        identity = AuthIdentity(
            user_id=user_id,
            provider=provider,
            provider_subject=provider_subject,
            email_snapshot=email_snapshot,
            email_verified=email_verified,
            display_name=display_name,
            avatar_url=avatar_url,
            last_login_at=datetime.now(UTC),
        )

        self._db.add(identity)
        self._db.flush()
        self._db.refresh(identity)

        return identity

    def record_login(
        self,
        identity: AuthIdentity,
        *,
        email_snapshot: str,
        email_verified: bool,
        display_name: str | None,
        avatar_url: str | None,
    ) -> AuthIdentity:
        identity.email_snapshot = email_snapshot
        identity.email_verified = email_verified
        identity.display_name = display_name
        identity.avatar_url = avatar_url
        identity.last_login_at = datetime.now(UTC)

        self._db.flush()
        self._db.refresh(identity)

        return identity
