from fastapi import FastAPI

from src.core.middlewares.request_id import RequestIdMiddleware


def register_middlewares(app: FastAPI) -> None:
    app.add_middleware(RequestIdMiddleware)


# app.add_middleware(...) çağrılarını tek yerde toplar.