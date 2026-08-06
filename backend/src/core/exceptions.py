from __future__ import annotations

from http import HTTPStatus
from typing import Any, Literal


# Bütün uygulamaya özel hataların ortak HTTP ve log bilgilerini taşıyan temel sınıftır.
class AppException(Exception):
    status_code: int = HTTPStatus.INTERNAL_SERVER_ERROR.value
    code: str = "INTERNAL_SERVER_ERROR"
    message: str = "Internal server error."
    log_level: str = "ERROR"
    commit_transaction: bool = False

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


# Kayıt sırasında email adresi zaten kullanılıyorsa güvenli bir 409 cevabı üretir.
class EmailAlreadyExistsException(
    ConflictException
):
    code = "EMAIL_ALREADY_EXISTS"
    message = "Email is already registered."

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "field": "email",
                "reason": "already_exists",
            },
        )


# Kayıt sırasında username zaten kullanılıyorsa güvenli bir 409 cevabı üretir.
class UsernameAlreadyExistsException(
    ConflictException
):
    code = "USERNAME_ALREADY_EXISTS"
    message = "Username is already registered."

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "field": "username",
                "reason": "already_exists",
            },
        )

# Bir kullanıcının aynı anda yalnızca bir tane devam eden session’ı olabilir.
# Kullanıcının zaten aktif session’ı varsa
class ActiveSessionExistsException(
    ConflictException
):
    code = "ACTIVE_SESSION_EXISTS"
    message = (
        "The user already has an active session."
    )

# Bitmiş bir session tekrar değiştirilmeye çalışılırsa
class InvalidSessionTransitionException(
    ConflictException
):
    code = "INVALID_SESSION_TRANSITION"
    message = (
        "The session cannot be changed "
        "from its current state."
    )


# Endpoint'e erişmek için geçerli bir kullanıcı oturumu gerektiğinde 401 cevabı üretir.
class AuthenticationRequiredException(AppException):
    status_code = HTTPStatus.UNAUTHORIZED.value
    code = "AUTHENTICATION_REQUIRED"
    message = "Authentication required."
    log_level = "WARNING"

    def __init__(
        self,
        *,
        safe_context: dict[str, object] | None = None,
    ) -> None:
        super().__init__(
            headers={
                "WWW-Authenticate": "Bearer",
            },
            safe_context=safe_context,
        )


# Kullanıcının giriş bilgileri geçersiz olduğunda güvenli bir 401 cevabı üretir.
class InvalidCredentialsException(
    AuthenticationRequiredException
):
    code = "INVALID_CREDENTIALS"
    message = "Invalid credentials."


AccessTokenFailureReason = Literal[
    "invalid",
    "expired",
    "invalid_claims",
    "session_not_found",
    "revoked",
]


# Geçersiz access token durumlarını istemciye tek tip güvenli bir 401 cevabı olarak sunar.
class InvalidTokenException(
    AuthenticationRequiredException
):
    code = "INVALID_ACCESS_TOKEN"
    message = "Invalid access token."

    def __init__(
        self,
        *,
        reason: AccessTokenFailureReason = "invalid",
    ) -> None:
        super().__init__(
            safe_context={
                "token_kind": "access",
                "reason": reason,
            },
        )


# Süresi dolmuş access token'ı logda ayırt ederken istemciye genel token hatası döndürür.
class ExpiredTokenException(
    InvalidTokenException
):
    def __init__(self) -> None:
        super().__init__(
            reason="expired",
        )


RefreshTokenFailureReason = Literal[
    "invalid",
    "expired",
    "revoked",
    "reuse_detected",
    "session_not_found",
    "user_not_found",
]


# Refresh token hatalarını gerçek nedeni yalnızca güvenli log context'inde tutarak bildirir.
class InvalidRefreshTokenException(
    AuthenticationRequiredException
):
    code = "INVALID_REFRESH_TOKEN"
    message = "Invalid refresh token."

    def __init__(
        self,
        *,
        reason: RefreshTokenFailureReason = "invalid",
    ) -> None:
        super().__init__(
            safe_context={
                "token_kind": "refresh",
                "reason": reason,
            },
        )


# Daha önce döndürülmüş refresh token tekrar kullanıldığında token ailesinin iptalini kalıcılaştırır.
class TokenReuseDetectedException(
    InvalidRefreshTokenException
):
    commit_transaction = True

    def __init__(self) -> None:
        super().__init__(
            reason="reuse_detected",
        )


# Kimliği doğrulanmış kullanıcının ilgili işlemi yapma yetkisi olmadığında 403 cevabı üretir.
class ForbiddenException(AppException):
    status_code = HTTPStatus.FORBIDDEN.value
    code = "FORBIDDEN"
    message = "You do not have permission to perform this action."
    log_level = "WARNING"


# Kimliği doğrulansa bile hesabı aktif olmayan kullanıcı için güvenli bir 403 cevabı üretir.
class InactiveUserException(
    ForbiddenException
):
    code = "INACTIVE_USER"
    message = "User account is inactive."

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "reason": "inactive_user",
            },
        )

# Veritabanına geçici olarak erişilemediğinde güvenli bir 503 cevabı üretir.
class DatabaseUnavailableException(AppException):
    status_code = HTTPStatus.SERVICE_UNAVAILABLE.value
    code = "DATABASE_UNAVAILABLE"
    message = "Database service is temporarily unavailable."
    log_level = "ERROR"


class RedisUnavailableException(AppException):
    status_code = HTTPStatus.SERVICE_UNAVAILABLE.value
    code = "REDIS_UNAVAILABLE"
    message = "Redis service is temporarily unavailable."
    log_level = "ERROR"

class RequestBodyTooLargeException(AppException):
    status_code = 413
    code = "REQUEST_BODY_TOO_LARGE"
    message = "Request body is too large."
    log_level = "WARNING"

    def __init__(self, max_body_bytes: int) -> None:
        super().__init__(
            safe_context={
                "max_body_bytes": max_body_bytes,
            },
        )


GoogleTokenFailureReason = Literal[
    "invalid",
    "wrong_audience",
    "missing_subject",
    "missing_email",
    "email_not_verified",
]


class InvalidGoogleTokenException(
    AuthenticationRequiredException
):
    code = "INVALID_GOOGLE_TOKEN"
    message = "Invalid Google identity token."

    def __init__(
        self,
        *,
        reason: GoogleTokenFailureReason = "invalid",
    ) -> None:
        super().__init__(
            safe_context={
                "provider": "google",
                "reason": reason,
            },
        )


class GoogleIdentityProviderUnavailableException(
    AppException
):
    status_code = HTTPStatus.SERVICE_UNAVAILABLE.value
    code = "GOOGLE_IDENTITY_PROVIDER_UNAVAILABLE"
    message = (
        "Google authentication is temporarily unavailable."
    )
    log_level = "ERROR"

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "provider": "google",
                "reason": "transport_error",
            },
        )


class GoogleAuthenticationDisabledException(
    AppException
):
    status_code = HTTPStatus.SERVICE_UNAVAILABLE.value
    code = "GOOGLE_AUTHENTICATION_DISABLED"
    message = "Google authentication is unavailable."
    log_level = "WARNING"

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "provider": "google",
                "reason": "disabled",
            },
        )


class AccountLinkRequiredException(
    ConflictException
):
    code = "ACCOUNT_LINK_REQUIRED"
    message = (
        "An account with this email already exists. "
        "Sign in using the existing method to link Google."
    )

    def __init__(self) -> None:
        super().__init__(
            safe_context={
                "provider": "google",
                "reason": "email_collision",
            },
        )

# Bu dosya hata türlerini tanımlar.
