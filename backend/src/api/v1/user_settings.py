from typing import Annotated

from fastapi import APIRouter, Depends

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.models.user_settings import UserSettings
from src.repositories.user_settings import (
    UserSettingsRepository,
)
from src.schemas.user_settings import (
    UpdateUserSettingsRequest,
    UserSettingsResponse,
)
from src.services.user_settings import (
    UserSettingsService,
)


router = APIRouter(
    prefix="/settings",
    tags=["User Settings"],
)


def get_user_settings_service(
    db: DbSession,
) -> UserSettingsService:
    return UserSettingsService(
        user_settings_repository=(
            UserSettingsRepository(db)
        ),
    )


UserSettingsServiceDependency = Annotated[
    UserSettingsService,
    Depends(get_user_settings_service),
]


# Giriş yapmış kullanıcının ayarlarını getirir
@router.get(
    "/me",
    response_model=UserSettingsResponse,
    summary="Get the current user's settings",
)
def get_current_user_settings(
    current_user: CurrentUser,
    user_settings_service: UserSettingsServiceDependency,
) -> UserSettings:
    return (
        user_settings_service.get_current_user_settings(
            current_user,
        )
    )

# Giriş yapmış kullanıcının ayarlarını günceller:
@router.patch(
    "/me",
    response_model=UserSettingsResponse,
    summary="Update the current user's settings",
)
def update_current_user_settings(
    payload: UpdateUserSettingsRequest,
    current_user: CurrentUser,
    user_settings_service: UserSettingsServiceDependency,
) -> UserSettings:
    return (
        user_settings_service.update_current_user_settings(
            current_user,
            payload,
        )
    )


"""
Router’ın görevi HTTP katmanını yönetmektir:
Request verisini almak
Giriş yapmış kullanıcıyı dependency’den almak
Servisi dependency olarak oluşturmak
Servis metodunu çağırmak
Dönen modeli response schema ile API cevabına çevirmek
"""