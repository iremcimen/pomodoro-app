from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.tasks import Task
    from src.models.users import User


class SessionType(StrEnum):
    FOCUS = "focus"
    SHORT_BREAK = "short_break"
    LONG_BREAK = "long_break"


class SessionStatus(StrEnum):
    STARTED = "started"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    INTERRUPTED = "interrupted"


class FocusSession(Base):
    __tablename__ = "focus_sessions"

    __table_args__ = (
        CheckConstraint(
            """
            session_type IN (
                'focus',
                'short_break',
                'long_break'
            )
            """,
            name="ck_focus_sessions_session_type",
        ),
        CheckConstraint(
            """
            status IN (
                'started',
                'completed',
                'cancelled',
                'interrupted'
            )
            """,
            name="ck_focus_sessions_status",
        ),
        CheckConstraint(
            "planned_duration_seconds > 0",
            name=(
                "ck_focus_sessions_"
                "planned_duration_positive"
            ),
        ),
        CheckConstraint(
            """
            actual_duration_seconds IS NULL
            OR actual_duration_seconds >= 0
            """,
            name=(
                "ck_focus_sessions_"
                "actual_duration_non_negative"
            ),
        ),
        CheckConstraint(
            """
            task_id IS NULL
            OR session_type = 'focus'
            """,
            name=(
                "ck_focus_sessions_"
                "task_only_for_focus"
            ),
        ),
        CheckConstraint(
            """
            (
                status = 'started'
                AND ended_at IS NULL
                AND actual_duration_seconds IS NULL
            )
            OR
            (
                status IN (
                    'completed',
                    'cancelled',
                    'interrupted'
                )
                AND ended_at IS NOT NULL
                AND actual_duration_seconds IS NOT NULL
            )
            """,
            name=(
                "ck_focus_sessions_"
                "lifecycle_fields"
            ),
        ),
        CheckConstraint(
            """
            ended_at IS NULL
            OR ended_at >= started_at
            """,
            name=(
                "ck_focus_sessions_"
                "end_after_start"
            ),
        ),
        Index(
            "ix_focus_sessions_user_id_started_at",
            "user_id",
            "started_at",
        ),
        Index(
            "ix_focus_sessions_user_id_status",
            "user_id",
            "status",
        ),
        Index(
            "ix_focus_sessions_task_id_started_at",
            "task_id",
            "started_at",
        ),
    )

    # Bu ID backend tarafından üretilmeyecek.
    # Mobil uygulama session başlamadan UUID üretip gönderecek
    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey(
            "users.id",
            name=(
                "fk_focus_sessions_"
                "user_id_users"
            ),
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    task_id: Mapped[int | None] = mapped_column(
        ForeignKey(
            "tasks.id",
            name=(
                "fk_focus_sessions_"
                "task_id_tasks"
            ),
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    session_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default=SessionStatus.STARTED.value,
        server_default=text("'started'"),
        nullable=False,
    )

    planned_duration_seconds: Mapped[int] = (
        mapped_column(
            Integer,
            nullable=False,
        )
    )

    actual_duration_seconds: Mapped[int | None] = (
        mapped_column(
            Integer,
            nullable=True,
        )
    )

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="focus_sessions",
    )

    task: Mapped["Task | None"] = relationship(
        back_populates="focus_sessions",
    )
