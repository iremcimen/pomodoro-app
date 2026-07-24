from src.models.user_settings import UserSettings
from src.models.users import User
from src.repositories.user_settings import (
    UserSettingsRepository,
)
from src.schemas.user_settings import (
    UpdateUserSettingsRequest,
)


class UserSettingsService:
    def __init__(
        self,
        user_settings_repository: UserSettingsRepository,
    ) -> None:
        self._settings = user_settings_repository

    # Kullanıcının ayarını getirir veya oluşturur.
    def _get_or_create_for_user(
        self,
        user_id: int,
    ) -> UserSettings:
        settings = self._settings.get_by_user_id(
            user_id,
        )

        if settings is not None:
            return settings

        return self._settings.create_defaults(
            user_id,
        )
    # Giriş yapmış kullanıcının kendi ayarlarını getirir
    def get_current_user_settings(
        self,
        current_user: User,
    ) -> UserSettings:
        return self._get_or_create_for_user(
            current_user.id,
        )

    # Giriş yapmış kullanıcının gönderdiği ayarları günceller
    def update_current_user_settings(
        self,
        current_user: User,
        request: UpdateUserSettingsRequest,
    ) -> UserSettings:
        values = request.model_dump(
            exclude_unset=True,
        )

        settings = self._get_or_create_for_user(
            current_user.id,
        )

        return self._settings.update(
            settings,
            values,
        )
