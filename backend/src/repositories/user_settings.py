from collections.abc import Mapping

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from src.models.user_settings import UserSettings


class UserSettingsRepository:
    _UPDATABLE_FIELDS = frozenset(
        {
            "focus_duration_minutes",
            "short_break_minutes",
            "long_break_minutes",
            "long_break_interval",
            "auto_start_break",
            "auto_start_focus",
            "sound_enabled",
            "vibration_enabled",
        }
    )

    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(
        self,
        user_id: int,
    ) -> UserSettings | None:
        statement = select(UserSettings).where(
            UserSettings.user_id == user_id,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    def create_defaults(
        self,
        user_id: int,
    ) -> UserSettings:
        statement = (
            insert(UserSettings)
            .values(user_id=user_id)
            .on_conflict_do_nothing(
                index_elements=[UserSettings.user_id],
            )
        )

        self._db.execute(statement)

        settings = self.get_by_user_id(user_id)

        if settings is None:
            raise RuntimeError(
                "User settings could not be created or retrieved."
            )

        return settings

    def update(
        self,
        settings: UserSettings,
        values: Mapping[str, object],
    ) -> UserSettings:
        unsupported_fields = (
            values.keys() - self._UPDATABLE_FIELDS
        )

        if unsupported_fields:
            field_names = ", ".join(
                sorted(unsupported_fields)
            )
            raise ValueError(
                "Unsupported user settings fields: "
                f"{field_names}"
            )

        for field_name, value in values.items():
            setattr(settings, field_name, value)

        self._db.flush()
        self._db.refresh(settings)

        return settings