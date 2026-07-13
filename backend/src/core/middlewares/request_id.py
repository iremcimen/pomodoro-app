from __future__ import annotations

from loguru import logger
from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from src.core.request_ids import (
    REQUEST_ID_HEADER,
    get_or_create_request_id,
)


class RequestIdMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_headers = Headers(scope=scope)

        request_id = get_or_create_request_id(
            request_headers.get(REQUEST_ID_HEADER)
        )

        state = scope.setdefault("state", {})
        state["request_id"] = request_id

        async def send_with_request_id(message: Message) -> None:
            if message["type"] == "http.response.start":
                response_headers = MutableHeaders(scope=message)
                response_headers[REQUEST_ID_HEADER] = request_id

            await send(message)

        with logger.contextualize(request_id=request_id):
            await self.app(
                scope,
                receive,
                send_with_request_id,
            )
# İstekten X-Request-ID header’ını okur, geçerliyse kullanır değilse UUID üretir
# Response’a X-Request-ID header’ı ekler.