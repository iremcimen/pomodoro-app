from fastapi import FastAPI

from src.core.middlewares.cors import (
    register_cors_middleware,
)
from src.core.middlewares.request_id import (
    RequestIdMiddleware,
)


def register_middlewares(
    app: FastAPI,
) -> None:
    app.add_middleware(
        RequestIdMiddleware,
    )

    register_cors_middleware(app)


# Bu dosya middleware’leri doğru sırayla birleştirmekten sorumlu