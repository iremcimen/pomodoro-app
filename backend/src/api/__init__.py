from fastapi import APIRouter, Depends

from src.api.dependencies.rate_limit import (
    enforce_authenticated_rate_limit,
    enforce_statistics_rate_limit,
)
from src.api.v1.auth import router as auth_router
from src.api.v1.focus_sessions import (
    router as focus_sessions_router,
)
from src.api.v1.health import router as health_router
from src.api.v1.statistics import (
    router as statistics_router,
)
from src.api.v1.tasks import router as tasks_router
from src.api.v1.user_settings import (
    router as user_settings_router,
)
from src.api.v1.users import router as users_router


api_router = APIRouter()

# Auth endpoint'leri kendi özel IP, hesap ve token kurallarını kullanır.
api_router.include_router(auth_router)


# Bütün korumalı router'lara ortak user ve IP limitini uygular.
authenticated_router = APIRouter(
    dependencies=[
        Depends(
            enforce_authenticated_rate_limit
        )
    ]
)

authenticated_router.include_router(users_router)
authenticated_router.include_router(
    user_settings_router
)
authenticated_router.include_router(tasks_router)
authenticated_router.include_router(
    focus_sessions_router
)

# Statistics'e genel limite ek olarak daha sıkı fail-closed limit uygular.
authenticated_router.include_router(
    statistics_router,
    dependencies=[
        Depends(
            enforce_statistics_rate_limit
        )
    ],
)

api_router.include_router(
    authenticated_router
)


__all__ = [
    "api_router",
    "health_router",
]
