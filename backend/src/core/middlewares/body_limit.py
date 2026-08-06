from __future__ import annotations

from starlette.datastructures import Headers
from starlette.requests import Request
from starlette.types import (
    ASGIApp,
    Message,
    Receive,
    Scope,
    Send,
)

from src.core.exception_handlers import (
    app_exception_handler,
)
from src.core.exceptions import (
    RequestBodyTooLargeException,
)


class RequestBodyLimitMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        *,
        max_body_bytes: int,
    ) -> None:
        self.app = app
        self.max_body_bytes = max_body_bytes

    async def _reject(
        self,
        *,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        request = Request(scope, receive=receive)
        exception = RequestBodyTooLargeException(
            self.max_body_bytes
        )
        response = app_exception_handler(
            request,
            exception,
        )

        await response(scope, receive, send)

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = Headers(scope=scope)
        content_length = headers.get("content-length")

        if content_length is not None:
            try:
                declared_size = int(content_length)
            except ValueError:
                declared_size = None

            if (
                declared_size is not None
                and declared_size > self.max_body_bytes
            ):
                await self._reject(
                    scope=scope,
                    receive=receive,
                    send=send,
                )
                return

        received_bytes = 0

        async def receive_with_limit() -> Message:
            nonlocal received_bytes

            message = await receive()

            if message["type"] == "http.request":
                received_bytes += len(
                    message.get("body", b"")
                )

                if received_bytes > self.max_body_bytes:
                    raise RequestBodyTooLargeException(
                        self.max_body_bytes
                    )

            return message

        try:
            await self.app(
                scope,
                receive_with_limit,
                send,
            )
        except RequestBodyTooLargeException:
            await self._reject(
                scope=scope,
                receive=receive,
                send=send,
            )

# Content-Length = isteği gönderen istemcinin otomatik eklediği HTTP başlığıdır. Body’nin kaç byte olduğunu söyler.
