from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    false,
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
    from src.models.focus_sessions import FocusSession
    from src.models.users import User


class Task(Base):
    __tablename__ = "tasks"

    __table_args__ = (
        CheckConstraint(
            "length(btrim(title)) > 0",
            name="ck_tasks_title_not_blank",
        ),
        CheckConstraint(
            "estimated_pomodoros >= 0",
            name=(
                "ck_tasks_estimated_pomodoros_"
                "non_negative"
            ),
        ),
        CheckConstraint(
            "completed_pomodoros >= 0",
            name=(
                "ck_tasks_completed_pomodoros_"
                "non_negative"
            ),
        ),
        CheckConstraint(
            """
            (
                is_completed = false
                AND completed_at IS NULL
            )
            OR
            (
                is_completed = true
                AND completed_at IS NOT NULL
            )
            """,
            name="ck_tasks_completion_state",
        ),
        Index(
            "ix_tasks_user_id_is_completed",
            "user_id",
            "is_completed",
        ),
        Index(
            "ix_tasks_user_id_created_at",
            "user_id",
            "created_at",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey(
            "users.id",
            name="fk_tasks_user_id_users",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    title: Mapped[str] = mapped_column(
        String(160),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    estimated_pomodoros: Mapped[int] = mapped_column(
        Integer,
        default=1,
        server_default=text("1"),
        nullable=False,
    )

    completed_pomodoros: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default=text("0"),
        nullable=False,
    )

    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=false(),
        nullable=False,
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="tasks",
    )

    focus_sessions: Mapped[list["FocusSession"]] = (
        relationship(
            back_populates="task",
            passive_deletes=True,
        )
    )

