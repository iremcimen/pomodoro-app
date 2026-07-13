from __future__ import annotations

from http import HTTPStatus
from typing import Any


# Bütün uygulamaya özel hataların ortak HTTP ve log bilgilerini taşıyan temel sınıftır.
class AppException(Exception):
    status_code: int = HTTPStatus.INTERNAL_SERVER_ERROR.value
    code: str = "INTERNAL_SERVER_ERROR"
    message: str = "Internal server error."
    log_level: str = "ERROR"

    def __init__(
        self,
        message: str | None = None,
        *,
        details: Any | None = None,
        headers: dict[str, str] | None = None,
        safe_context: dict[str, object] | None = None,
    ) -> None:
        self.message = message or self.message
        self.details = details
        self.headers = headers
        self.safe_context = safe_context or {}

        super().__init__(self.message)


# İstemcinin geçersiz veya hatalı bir istek gönderdiği durumlarda 400 cevabı üretir.
class BadRequestException(AppException):
    status_code = HTTPStatus.BAD_REQUEST.value
    code = "BAD_REQUEST"
    message = "Invalid request."
    log_level = "WARNING"


# İstenen kullanıcı, timer veya task gibi bir kaynak bulunamadığında 404 cevabı üretir.
class ResourceNotFoundException(AppException):
    status_code = HTTPStatus.NOT_FOUND.value
    code = "RESOURCE_NOT_FOUND"
    message = "Resource not found."
    log_level = "INFO"

    def __init__(
        self,
        resource_name: str = "Resource",
    ) -> None:
        super().__init__(
            message=f"{resource_name} not found.",
            safe_context={
                "resource_name": resource_name,
            },
        )


# İstenen işlem mevcut kaynak durumu veya başka bir kayıtla çakıştığında 409 cevabı üretir.
class ConflictException(AppException):
    status_code = HTTPStatus.CONFLICT.value
    code = "RESOURCE_CONFLICT"
    message = "Resource conflict."
    log_level = "WARNING"


# Endpoint'e erişmek için geçerli bir kullanıcı oturumu gerektiğinde 401 cevabı üretir.
class AuthenticationRequiredException(AppException):
    status_code = HTTPStatus.UNAUTHORIZED.value
    code = "AUTHENTICATION_REQUIRED"
    message = "Authentication required."
    log_level = "WARNING"

    def __init__(self) -> None:
        super().__init__(
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )


# Kullanıcının giriş bilgileri geçersiz olduğunda güvenli bir 401 cevabı üretir.
class InvalidCredentialsException(
    AuthenticationRequiredException
):
    code = "INVALID_CREDENTIALS"
    message = "Invalid credentials."


# Kimliği doğrulanmış kullanıcının ilgili işlemi yapma yetkisi olmadığında 403 cevabı üretir.
class ForbiddenException(AppException):
    status_code = HTTPStatus.FORBIDDEN.value
    code = "FORBIDDEN"
    message = "You do not have permission to perform this action."
    log_level = "WARNING"


# Veritabanına geçici olarak erişilemediğinde güvenli bir 503 cevabı üretir.
class DatabaseUnavailableException(AppException):
    status_code = HTTPStatus.SERVICE_UNAVAILABLE.value
    code = "DATABASE_UNAVAILABLE"
    message = "Database service is temporarily unavailable."
    log_level = "ERROR"

# Hata türlerini tanımlar.
