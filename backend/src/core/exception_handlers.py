from __future__ import annotations

from collections.abc import Awaitable, Callable, Mapping
from datetime import UTC, datetime
from typing import Any, cast

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from loguru import logger
from sqlalchemy.exc import (
    IntegrityError,
    OperationalError,
    SQLAlchemyError,
)
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.responses import Response

from src.core.exceptions import AppException
from src.core.request_ids import (
    REQUEST_ID_HEADER,
    get_or_create_request_id,
    is_valid_request_id,
)


ExceptionHandler = Callable[
    [Request, Exception],
    Response | Awaitable[Response],
]


# Hata cevabında kullanılmak üzere saniye hassasiyetinde UTC zaman damgası üretir.
def get_timestamp() -> str:
    return (
        datetime.now(UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


# İsteğin request ID'sini state veya header'dan alır, geçerli bir değer yoksa yenisini üretir.
def get_request_id(request: Request) -> str:
    request_id = getattr(
        request.state,
        "request_id",
        None,
    )

    if is_valid_request_id(request_id):
        return request_id

    request_id = get_or_create_request_id(
        request.headers.get(REQUEST_ID_HEADER)
    )

    request.state.request_id = request_id

    return request_id


# Bütün hatalar için ortak ve güvenli JSON response gövdesini oluşturur.
def build_error_response(
    *,
    request: Request,
    code: str,
    message: str,
    details: Any | None = None,
) -> dict[str, Any]:
    return {
        "success": False,
        "error": {
            "code": code,
            "message": message,
            "details": details,
        },
        "request_id": get_request_id(request),
        "timestamp": get_timestamp(),
    }


# Mevcut header'ları koruyarak response'a X-Request-ID header'ını ekler.
def build_response_headers(
    request: Request,
    headers: Mapping[str, str] | None = None,
) -> dict[str, str]:
    response_headers = dict(headers or {})
    response_headers[REQUEST_ID_HEADER] = get_request_id(request)

    return response_headers


# Request logging middleware'in kullanacağı hata bilgilerini request state'e kaydeder.
def set_error_state(
    *,
    request: Request,
    code: str,
    message: str,
    log_level: str,
    safe_context: dict[str, object] | None = None,
) -> None:
    request.state.error_code = code
    request.state.error_message = message
    request.state.error_log_level = log_level
    request.state.error_context = safe_context or {}


# Uygulamaya özel AppException hatalarını standart HTTP response'una dönüştürür.
def app_exception_handler(
    request: Request,
    exc: AppException,
) -> JSONResponse:
    set_error_state(
        request=request,
        code=exc.code,
        message=exc.message,
        log_level=exc.log_level,
        safe_context=exc.safe_context,
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=build_error_response(
            request=request,
            code=exc.code,
            message=exc.message,
            details=exc.details,
        ),
        headers=build_response_headers(
            request,
            exc.headers,
        ),
    )


# FastAPI ve Starlette HTTP hatalarını güvenli ve standart hata formatına çevirir.
def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException,
) -> JSONResponse:
    code = f"HTTP_{exc.status_code}"

    if exc.status_code >= status.HTTP_500_INTERNAL_SERVER_ERROR:
        message = "Internal server error."
        log_level = "ERROR"
    elif isinstance(exc.detail, str):
        message = exc.detail
        log_level = "WARNING"
    else:
        message = "HTTP request failed."
        log_level = "WARNING"

    if exc.status_code == status.HTTP_404_NOT_FOUND:
        log_level = "INFO"

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level=log_level,
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
        ),
        headers=build_response_headers(
            request,
            exc.headers,
        ),
    )


# Pydantic request doğrulama hatalarını alan bazlı 422 hata detaylarına dönüştürür.
def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    details: list[dict[str, object]] = []

    for error in exc.errors():
        location = error.get("loc", ())

        field = ".".join(
            str(part)
            for part in location
            if part != "body"
        )

        details.append(
            {
                "field": field,
                "message": str(
                    error.get("msg", "Invalid value.")
                ),
                "code": str(
                    error.get("type", "validation_error")
                ),
            }
        )

    code = "VALIDATION_ERROR"
    message = "Request validation failed."

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level="WARNING",
        safe_context={
            "error_count": len(details),
        },
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
            details=details,
        ),
        headers=build_response_headers(request),
    )


# Veritabanı constraint ihlallerini güvenli bir 409 Conflict response'una çevirir.
def integrity_error_handler(
    request: Request,
    exc: IntegrityError,
) -> JSONResponse:
    code = "DATABASE_CONSTRAINT_VIOLATION"
    message = (
        "The requested operation conflicts "
        "with existing data."
    )

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level="WARNING",
        safe_context={
            "exception_type": type(exc).__name__,
        },
    )

    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
        ),
        headers=build_response_headers(request),
    )


# Veritabanına erişilemediğinde hatayı loglayıp 503 Service Unavailable döndürür.
def operational_error_handler(
    request: Request,
    exc: OperationalError,
) -> JSONResponse:
    code = "DATABASE_UNAVAILABLE"
    message = "Database service is temporarily unavailable."

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level="ERROR",
        safe_context={
            "exception_type": type(exc).__name__,
        },
    )

    logger.bind(
        request_id=get_request_id(request),
        error_code=code,
        method=request.method,
        path=request.url.path,
        exception_type=type(exc).__name__,
    ).error(
        "database_unavailable",
    )

    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
        ),
        headers=build_response_headers(request),
    )


# Diğer SQLAlchemy hatalarını teknik ayrıntı sızdırmadan 500 response'una çevirir.
def sqlalchemy_error_handler(
    request: Request,
    exc: SQLAlchemyError,
) -> JSONResponse:
    code = "DATABASE_ERROR"
    message = "Database operation failed."

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level="ERROR",
        safe_context={
            "exception_type": type(exc).__name__,
        },
    )

    logger.bind(
        request_id=get_request_id(request),
        error_code=code,
        method=request.method,
        path=request.url.path,
        exception_type=type(exc).__name__,
    ).error(
        "database_operation_failed",
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
        ),
        headers=build_response_headers(request),
    )


# Beklenmeyen hataların stack trace'ini loglayıp kullanıcıya güvenli bir 500 cevabı döndürür.
def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    code = "INTERNAL_SERVER_ERROR"
    message = "Internal server error."

    set_error_state(
        request=request,
        code=code,
        message=message,
        log_level="ERROR",
        safe_context={
            "exception_type": type(exc).__name__,
        },
    )

    logger.bind(
        request_id=get_request_id(request),
        error_code=code,
        method=request.method,
        path=request.url.path,
        exception_type=type(exc).__name__,
    ).opt(
        exception=exc,
    ).error(
        "unhandled_exception",
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=build_error_response(
            request=request,
            code=code,
            message=message,
        ),
        headers=build_response_headers(request),
    )


# Bütün özel exception handler fonksiyonlarını FastAPI uygulamasına kaydeder.
def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(
        AppException,
        cast(ExceptionHandler, app_exception_handler),
    )

    app.add_exception_handler(
        StarletteHTTPException,
        cast(ExceptionHandler, http_exception_handler),
    )

    app.add_exception_handler(
        RequestValidationError,
        cast(
            ExceptionHandler,
            validation_exception_handler,
        ),
    )

    app.add_exception_handler(
        IntegrityError,
        cast(ExceptionHandler, integrity_error_handler),
    )

    app.add_exception_handler(
        OperationalError,
        cast(ExceptionHandler, operational_error_handler),
    )

    app.add_exception_handler(
        SQLAlchemyError,
        cast(ExceptionHandler, sqlalchemy_error_handler),
    )

    app.add_exception_handler(
        Exception,
        cast(ExceptionHandler, unhandled_exception_handler),
    )
