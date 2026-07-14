from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.users import User


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    __table_args__ = (
        UniqueConstraint(
            "refresh_token_hash",
            name="uq_auth_sessions_refresh_token_hash",
        ),
        CheckConstraint(
            "expires_at > created_at",
            name="ck_auth_sessions_expires_after_creation",
        ),
        CheckConstraint(
            "revoked_at IS NULL OR revoked_at >= created_at",
            name="ck_auth_sessions_revoked_after_creation",
        ),
        CheckConstraint(
            "replaced_by_session_id IS NULL OR revoked_at IS NOT NULL",
            name="ck_auth_sessions_replacement_requires_revocation",
        ),
        Index(
            "ix_auth_sessions_user_id_revoked_at",
            "user_id",
            "revoked_at",
        ),
        Index(
            "ix_auth_sessions_token_family_id_revoked_at",
            "token_family_id",
            "revoked_at",
        ),
        Index(
            "ix_auth_sessions_expires_at",
            "expires_at",
        ),
        Index(
            "ix_auth_sessions_replaced_by_session_id",
            "replaced_by_session_id",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey(
            "users.id",
            name="fk_auth_sessions_user_id_users",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    refresh_token_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )

    token_family_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        default=uuid4,
        nullable=False,
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    replaced_by_session_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "auth_sessions.id",
            name="fk_auth_sessions_replaced_by_auth_sessions",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    last_used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user_agent: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
    )

    ip_address: Mapped[str | None] = mapped_column(
        String(45),
        nullable=True,
    )

    user: Mapped["User"] = relationship(
        back_populates="auth_sessions",
    )