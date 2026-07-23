from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    false,
    func,
    text,
    true,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.users import User


class UserSettings(Base):
    __tablename__ = "user_settings"

    __table_args__ = (
        CheckConstraint(
            """
            focus_duration_minutes
            BETWEEN 1 AND 180
            """,
            name=(
                "ck_user_settings_"
                "focus_duration_range"
            ),
        ),
        CheckConstraint(
            """
            short_break_minutes
            BETWEEN 1 AND 60
            """,
            name=(
                "ck_user_settings_"
                "short_break_range"
            ),
        ),
        CheckConstraint(
            """
            long_break_minutes
            BETWEEN 1 AND 120
            """,
            name=(
                "ck_user_settings_"
                "long_break_range"
            ),
        ),
        CheckConstraint(
            """
            long_break_interval
            BETWEEN 1 AND 12
            """,
            name=(
                "ck_user_settings_"
                "long_break_interval_range"
            ),
        ),
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey(
            "users.id",
            name=(
                "fk_user_settings_"
                "user_id_users"
            ),
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    focus_duration_minutes: Mapped[int] = (
        mapped_column(
            Integer,
            default=25,
            server_default=text("25"),
            nullable=False,
        )
    )

    short_break_minutes: Mapped[int] = mapped_column(
        Integer,
        default=5,
        server_default=text("5"),
        nullable=False,
    )

    long_break_minutes: Mapped[int] = mapped_column(
        Integer,
        default=15,
        server_default=text("15"),
        nullable=False,
    )

    long_break_interval: Mapped[int] = mapped_column(
        Integer,
        default=4,
        server_default=text("4"),
        nullable=False,
    )

    auto_start_break: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=false(),
        nullable=False,
    )

    auto_start_focus: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=false(),
        nullable=False,
    )

    sound_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default=true(),
        nullable=False,
    )

    vibration_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default=true(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="settings",
    )
