import asyncio

import anyio
from fastapi import APIRouter, status
from redis.exceptions import RedisError
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from src.api.dependencies.redis import RedisDependency
from src.core.config import settings
from src.core.database import engine
from src.core.exceptions import (
    DatabaseUnavailableException,
    RedisUnavailableException,
)
from src.schemas.health import HealthResponse


router = APIRouter(
    prefix="/health",
    tags=["Health"],
)


def build_health_response() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service=settings.SERVICE_NAME,
        version=settings.APP_VERSION,
        environment=settings.ENVIRONMENT,
    )


def check_database() -> int | None:
    with engine.connect() as connection:
        return connection.scalar(
            text("SELECT 1"),
        )


@router.get(
    "/live",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check application liveness",
)
def get_liveness() -> HealthResponse:
    """Yalnızca uygulama process'ini kontrol eder."""
    return build_health_response()


@router.get(
    "/ready",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check application readiness",
)
async def get_readiness(
    redis_manager: RedisDependency,
) -> HealthResponse:
    """Zorunlu dış bağımlılıkları kontrol eder."""
    try:
        async with asyncio.timeout(1.0):
            database_result = await anyio.to_thread.run_sync(
                check_database,
                abandon_on_cancel=True,
            )
    except (SQLAlchemyError, TimeoutError) as exc:
        raise DatabaseUnavailableException() from exc

    if database_result != 1:
        raise DatabaseUnavailableException()

    if settings.REDIS_REQUIRED:
        try:
            await redis_manager.ping(
                operation="readiness",
            )
        except (RedisError, TimeoutError) as exc:
            raise RedisUnavailableException() from exc

    return build_health_response()
