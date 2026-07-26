from fastapi import FastAPI
from starlette.middleware.trustedhost import (
    TrustedHostMiddleware,
)

from src.core.config import settings


def register_trusted_host_middleware(
    app: FastAPI,
) -> None:
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.TRUSTED_HOSTS,
    )
