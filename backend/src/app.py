from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from loguru import logger

from src.api import api_router
from src.core.config import settings
from src.core.logging import configure_logging
from src.core.middlewares import register_middlewares
from src.core.exception_handlers import register_exception_handlers

@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    logger.info("application_started")

    try:
        yield
    finally:
        logger.info("application_stopped")


def create_app() -> FastAPI:
    configure_logging()

    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        debug=settings.DEBUG,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url="/openapi.json" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    register_exception_handlers(app)
    register_middlewares(app)

    app.include_router(
        api_router,
        prefix=settings.API_V1_PREFIX,
    )

    return app