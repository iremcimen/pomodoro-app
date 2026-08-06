from fastapi import FastAPI

from src.core.middlewares.cors import (
    register_cors_middleware,
)
from src.core.middlewares.rate_limit import (
    GlobalRateLimitMiddleware,
)
from src.core.config import settings
from src.core.middlewares.body_limit import (
    RequestBodyLimitMiddleware,
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
    app.add_middleware(
        RequestBodyLimitMiddleware,
        max_body_bytes=settings.MAX_REQUEST_BODY_BYTES,
    )

    register_trusted_host_middleware(app)
    register_cors_middleware(app)

    # En son eklendiği için en dışta çalışır ve 429'a da request ID ekler.
    app.add_middleware(
        RequestIdMiddleware,
    )

# Bu dosya middleware’leri doğru sırayla birleştirmekten sorumlu
# Request ID → CORS → Trusted Host → Body Limit → Rate Limit → Endpoint




