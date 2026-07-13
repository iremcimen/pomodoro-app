from fastapi import APIRouter, status

from src.core.config import settings
from src.schemas.health import HealthResponse


router = APIRouter(
    prefix="/health",
    tags=["Health"],
)

# uygulama process’inin çalıştığını gösterir.
@router.get(
    "/live",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check application liveness",
)
def get_liveness() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service=settings.SERVICE_NAME,
        version=settings.APP_VERSION,
        environment=settings.ENVIRONMENT,
    )