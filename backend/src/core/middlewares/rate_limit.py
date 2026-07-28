from __future__ import annotations

from starlette.datastructures import MutableHeaders
from starlette.requests import Request
from starlette.types import (
    ASGIApp,
    Message,
    Receive,
    Scope,
    Send,
)

from src.core.client_ip import (
    build_trusted_proxy_networks,
    resolve_client_ip,
)
from src.core.config import settings
from src.core.exception_handlers import (
    app_exception_handler,
)
from src.core.rate_limit_policies import (
    GLOBAL_IP,
    GLOBAL_SYSTEM,
)
from src.core.rate_limiting import (
    FailureMode,
    RateLimiter,
    RateLimitDecision,
    RateLimitExceededException,
    RateLimitTarget,
    apply_rate_limit_headers,
)


# İstemci IP'sini belirler ve global trafik sınırlarını uygular.
class GlobalRateLimitMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        self._trusted_proxy_networks = (
            build_trusted_proxy_networks(
                settings.TRUSTED_PROXY_IPS
            )
        )

    # Health ve CORS preflight isteklerinin limit dışında kalmasını sağlar.
    def _should_skip(
        self,
        scope: Scope,
    ) -> bool:
        method = scope.get("method", "")
        path = scope.get("path", "")

        return (
            method == "OPTIONS"
            or not path.startswith(
                settings.API_V1_PREFIX
            )
        )

    # İzinli response'a global header'ları yalnız mevcut değilse ekler.
    def _send_with_headers(
        self,
        *,
        send: Send,
        decision: RateLimitDecision | None,
    ) -> Send:
        async def send_with_headers(
            message: Message,
        ) -> None:
            if message["type"] == "http.response.start":
                headers = MutableHeaders(
                    scope=message
                )

                temporary_headers: dict[str, str] = {}

                apply_rate_limit_headers(
                    temporary_headers,
                    decision,
                )

                for name, value in (
                    temporary_headers.items()
                ):
                    if name not in headers:
                        headers[name] = value

            await send(message)

        return send_with_headers

    # Her HTTP request'inde metadata oluşturur ve global limiti çalıştırır.
    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request = Request(scope)

        peer_host = (
            request.client.host
            if request.client is not None
            else None
        )

        client_ip = resolve_client_ip(
            peer_host=peer_host,
            x_forwarded_for=request.headers.get(
                "x-forwarded-for"
            ),
            trusted_proxy_networks=(
                self._trusted_proxy_networks
            ),
        )

        request.state.client_ip = client_ip

        if self._should_skip(scope):
            await self.app(scope, receive, send)
            return

        limiter = getattr(
            request.app.state,
            "rate_limiter",
            None,
        )

        if not isinstance(limiter, RateLimiter):
            await self.app(scope, receive, send)
            return

        try:
            decision = await limiter.enforce(
                [
                    RateLimitTarget(
                        GLOBAL_IP,
                        f"ip:{client_ip}",
                    ),
                    RateLimitTarget(
                        GLOBAL_SYSTEM,
                        "system:all",
                    ),
                ],
                failure_mode=FailureMode.OPEN,
            )
        except RateLimitExceededException as exc:
            response = app_exception_handler(
                request,
                exc,
            )
            await response(scope, receive, send)
            return

        await self.app(
            scope,
            receive,
            self._send_with_headers(
                send=send,
                decision=decision,
            ),
        )
