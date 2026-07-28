from fastapi import FastAPI

from src.core.middlewares.cors import (
    register_cors_middleware,
)
from src.core.middlewares.rate_limit import (
    GlobalRateLimitMiddleware,
)
from src.core.middlewares.request_id import (
    RequestIdMiddleware,
)
from src.core.middlewares.trusted_hosts import (
    register_trusted_host_middleware,
)


# Middleware'leri response ve güvenlik sırasına göre kaydeder.
def register_middlewares(
    app: FastAPI,
) -> None:
    # İlk eklenen middleware en içte çalışır.
    app.add_middleware(
        GlobalRateLimitMiddleware,
    )

    register_trusted_host_middleware(app)
    register_cors_middleware(app)

    # En son eklendiği için en dışta çalışır ve 429'a da request ID ekler.
    app.add_middleware(
        RequestIdMiddleware,
    )

# Bu dosya middleware’leri doğru sırayla birleştirmekten sorumlu