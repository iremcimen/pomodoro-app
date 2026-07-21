from fastapi import APIRouter, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from src.api.dependencies.database import DbSession
from src.core.config import settings
from src.core.exceptions import (
    DatabaseUnavailableException,
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


@router.get(
    "/live",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check application liveness",
)
def get_liveness() -> HealthResponse:
    """Uygulama process'inin çalıştığını kontrol eder."""
    return build_health_response()


@router.get(
    "/ready",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check application readiness",
)
def get_readiness(
    db: DbSession,
) -> HealthResponse:
    """PostgreSQL bağlantısını kontrol eder."""
    try:
        result = db.scalar(
            text("SELECT 1"),
        )
    except SQLAlchemyError as exc:
        raise DatabaseUnavailableException() from exc

    if result != 1:
        raise DatabaseUnavailableException()

    return build_health_response()