from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    DateTime,
    ForeignKey,
    String,
    func,
)
from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from src.core.database import Base

if TYPE_CHECKING:
    from src.models.users import User


class PasswordCredential(Base):
    __tablename__ = "password_credentials"

    user_id: Mapped[int] = mapped_column(
        ForeignKey(
            "users.id",
            name=(
                "fk_password_credentials_"
                "user_id_users"
            ),
            ondelete="CASCADE",
        ),
        primary_key=True,
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    password_changed_at: Mapped[datetime] = (
        mapped_column(
            DateTime(timezone=True),
            server_default=func.now(),
            nullable=False,
        )
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="password_credential",
    )
