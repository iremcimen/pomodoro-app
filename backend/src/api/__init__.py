from fastapi import APIRouter

from src.api.v1.auth import router as auth_router
from src.api.v1.health import router as health_router
from src.api.v1.users import router as users_router
from src.api.v1.user_settings import router as user_settings_router


api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(user_settings_router)


__all__ = [
    "api_router",
    "health_router",
]