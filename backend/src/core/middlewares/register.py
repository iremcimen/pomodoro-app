from fastapi import FastAPI

from src.core.middlewares.cors import (
    register_cors_middleware,
)
from src.core.middlewares.request_id import (
    RequestIdMiddleware,
)
from src.core.middlewares.trusted_hosts import (
    register_trusted_host_middleware,
)


def register_middlewares(
    app: FastAPI,
) -> None:
    app.add_middleware(
        RequestIdMiddleware,
    )

    register_cors_middleware(app)
    register_trusted_host_middleware(app)

# Bu dosya middleware’leri doğru sırayla birleştirmekten sorumlu