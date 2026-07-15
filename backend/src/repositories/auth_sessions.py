from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from src.models.auth import AuthSession


class AuthSessionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_refresh_token_hash(
        self,
        refresh_token_hash: str,
    ) -> AuthSession | None:
        statement = select(AuthSession).where(
            AuthSession.refresh_token_hash
            == refresh_token_hash,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def get_by_refresh_token_hash_for_update(
        self,
        refresh_token_hash: str,
    ) -> AuthSession | None:
        statement = (
            select(AuthSession)
            .where(
                AuthSession.refresh_token_hash
                == refresh_token_hash,
            )
            .with_for_update()
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def create(
        self,
        *,
        user_id: int,
        refresh_token_hash: str,
        expires_at: datetime,
        token_family_id: UUID | None = None,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> AuthSession:
        auth_session = AuthSession(
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            expires_at=expires_at,
            token_family_id=(
                token_family_id
                if token_family_id is not None
                else uuid4()
            ),
            user_agent=user_agent,
            ip_address=ip_address,
        )

        self._db.add(auth_session)
        self._db.flush()
        self._db.refresh(auth_session)

        return auth_session

    def revoke(
        self,
        auth_session: AuthSession,
        *,
        revoked_at: datetime,
        replaced_by_session_id: UUID | None = None,
    ) -> AuthSession:
        auth_session.revoked_at = revoked_at
        auth_session.replaced_by_session_id = (
            replaced_by_session_id
        )
        auth_session.last_used_at = revoked_at

        self._db.flush()

        return auth_session
    # Aynı refresh-token ailesindeki bütün session’ları iptal eder
    def revoke_family(
        self,
        token_family_id: UUID,
        *,
        revoked_at: datetime,
    ) -> int:
        statement = (
            update(AuthSession)
            .where(
                AuthSession.token_family_id
                == token_family_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=revoked_at)
            .returning(AuthSession.id)
        )

        revoked_session_ids = self._db.scalars(
            statement,
        ).all()

        return len(revoked_session_ids)

    # Tüm cihazlardan çıkış yap
    def revoke_all_for_user(
        self,
        user_id: int,
        *,
        revoked_at: datetime,
    ) -> int:
        statement = (
            update(AuthSession)
            .where(
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=revoked_at)
            .returning(AuthSession.id)
        )

        revoked_session_ids = self._db.scalars(
            statement,
        ).all()

        return len(revoked_session_ids)

    def list_active_for_user(
        self,
        user_id: int,
    ) -> list[AuthSession]:
        statement = (
            select(AuthSession)
            .where(
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > func.now(),
            )
            .order_by(AuthSession.created_at.desc())
        )

        return list(
            self._db.scalars(statement).all()
        )