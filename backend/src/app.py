from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from loguru import logger

from src.api import api_router, health_router
from src.core.config import settings
from src.core.exception_handlers import (
    register_exception_handlers,
)
from src.core.logging import configure_logging
from src.core.middlewares import register_middlewares
from src.core.rate_limiting import RateLimiter
from src.core.redis import RedisManager
from src.core.security.google_tokens import (
    GoogleIdTokenVerifier,
)

# Redis ve rate limiter'ın uygulama ömrü boyunca tek instance olmasını sağlar.
@asynccontextmanager
async def lifespan(
    app: FastAPI,
) -> AsyncGenerator[None, None]:

    google_id_token_verifier = (
        GoogleIdTokenVerifier(
            client_ids=settings.GOOGLE_OAUTH_CLIENT_IDS,
            clock_skew_seconds=(
                settings.GOOGLE_TOKEN_CLOCK_SKEW_SECONDS
            ),
        )
        if settings.GOOGLE_AUTH_ENABLED
        else None
    )

    app.state.google_id_token_verifier = (
        google_id_token_verifier
    )
    redis_manager = RedisManager.from_settings(
        settings
    )
    app.state.redis_manager = redis_manager

    try:
        await redis_manager.open()

        app.state.rate_limiter = RateLimiter(
            redis_manager=redis_manager,
            enabled=settings.RATE_LIMIT_ENABLED,
            key_salt=(
                settings
                .RATE_LIMIT_KEY_SALT
                .get_secret_value()
            ),
            local_max_buckets=(
                settings
                .RATE_LIMIT_LOCAL_MAX_BUCKETS
            ),
        )

        logger.info("application_started")
        yield
    finally:
        app.state.rate_limiter = None
        app.state.google_id_token_verifier = None

        if google_id_token_verifier is not None:
            google_id_token_verifier.close()

        await redis_manager.close()
        logger.info("application_stopped")


# FastAPI uygulamasını handler, middleware ve router'larla oluşturur.
def create_app() -> FastAPI:
    configure_logging()

    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        debug=settings.DEBUG,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url=(
            "/openapi.json"
            if settings.DEBUG
            else None
        ),
        lifespan=lifespan,
    )

    register_exception_handlers(app)
    register_middlewares(app)

    app.include_router(health_router)

    app.include_router(
        api_router,
        prefix=settings.API_V1_PREFIX,
    )

    return app