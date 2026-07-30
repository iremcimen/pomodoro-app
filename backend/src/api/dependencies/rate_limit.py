from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Request, Response

from src.api.dependencies.auth import CurrentUser
from src.core.client_ip import get_client_ip
from src.core.rate_limit_policies import (
    AUTHENTICATED_IP,
    AUTHENTICATED_USER,
    GOOGLE_LOGIN_IP_HOUR,
    GOOGLE_LOGIN_IP_MINUTE,
    GOOGLE_LOGIN_TOKEN,
    LOGIN_ACCOUNT,
    LOGIN_IP_ACCOUNT,
    LOGIN_IP_HOUR,
    LOGIN_IP_MINUTE,
    MUTATION_USER,
    REFRESH_FINGERPRINT,
    REFRESH_IP,
    REGISTER_IP_DAY,
    REGISTER_IP_HOUR,
    STATISTICS_USER,
)
from src.core.rate_limiting import (
    FailureMode,
    RateLimiter,
    RateLimitTarget,
    apply_rate_limit_headers,
)
from src.schemas.auth import (
    GoogleLoginRequest,
    LoginRequest,
    RefreshTokenRequest,
)


# Başarılı login sonrasında temizlenecek hesap öznesini taşır.
@dataclass(frozen=True, slots=True)
class LoginRateLimitContext:
    account_subject: str


async def enforce_google_login_rate_limit(
    *,
    payload: GoogleLoginRequest,
    request: Request,
    response: Response,
    limiter: RateLimiter,
) -> None:
    client_ip = get_client_ip(request)

    decision = await limiter.enforce(
        [
            RateLimitTarget(
                GOOGLE_LOGIN_IP_MINUTE,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                GOOGLE_LOGIN_IP_HOUR,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                GOOGLE_LOGIN_TOKEN,
                (
                    "google-id-token:"
                    f"{payload.id_token}"
                ),
            ),
        ],
        failure_mode=FailureMode.LOCAL,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )

# App lifespan sırasında oluşturulan ortak limiter nesnesini döndürür.
def get_rate_limiter(
    request: Request,
) -> RateLimiter:
    rate_limiter = getattr(
        request.app.state,
        "rate_limiter",
        None,
    )

    if not isinstance(rate_limiter, RateLimiter):
        raise RuntimeError(
            "Rate limiter is not initialized."
        )

    return rate_limiter


RateLimiterDependency = Annotated[
    RateLimiter,
    Depends(get_rate_limiter),
]


# Login payload'ından normalize hesap kimliği oluşturur.
def get_login_account_subject(
    payload: LoginRequest,
) -> str:
    if payload.email is not None:
        return f"login-email:{payload.email}"

    if payload.username is not None:
        return f"login-username:{payload.username}"

    # Normalde Pydantic bu noktaya ulaşılmasına izin vermez.
    return "login-identifier:invalid"


# Login endpoint'inin dört eşzamanlı kuralını atomik uygular.
async def enforce_login_rate_limit(
    *,
    payload: LoginRequest,
    request: Request,
    response: Response,
    limiter: RateLimiter,
) -> LoginRateLimitContext:
    client_ip = get_client_ip(request)
    account_subject = get_login_account_subject(
        payload
    )

    decision = await limiter.enforce(
        [
            RateLimitTarget(
                LOGIN_IP_MINUTE,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                LOGIN_IP_HOUR,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                LOGIN_ACCOUNT,
                account_subject,
            ),
            RateLimitTarget(
                LOGIN_IP_ACCOUNT,
                (
                    f"ip-account:{client_ip}:"
                    f"{account_subject}"
                ),
            ),
        ],
        failure_mode=FailureMode.LOCAL,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )

    return LoginRateLimitContext(
        account_subject=account_subject,
    )


# Başarılı login sonrasında yalnız hesap kuralını temizler.
async def clear_successful_login_limit(
    *,
    limiter: RateLimiter,
    context: LoginRateLimitContext,
) -> None:
    await limiter.clear(
        [
            RateLimitTarget(
                LOGIN_ACCOUNT,
                context.account_subject,
            )
        ]
    )


# Register endpoint'inin saatlik ve günlük IP kurallarını uygular.
async def enforce_register_rate_limit(
    *,
    request: Request,
    response: Response,
    limiter: RateLimiter,
) -> None:
    client_ip = get_client_ip(request)

    decision = await limiter.enforce(
        [
            RateLimitTarget(
                REGISTER_IP_HOUR,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                REGISTER_IP_DAY,
                f"ip:{client_ip}",
            ),
        ],
        failure_mode=FailureMode.LOCAL,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )


# Refresh endpoint'inde IP ve token fingerprint kurallarını uygular.
async def enforce_refresh_rate_limit(
    *,
    payload: RefreshTokenRequest,
    request: Request,
    response: Response,
    limiter: RateLimiter,
) -> None:
    client_ip = get_client_ip(request)

    decision = await limiter.enforce(
        [
            RateLimitTarget(
                REFRESH_IP,
                f"ip:{client_ip}",
            ),
            RateLimitTarget(
                REFRESH_FINGERPRINT,
                (
                    "refresh-token:"
                    f"{payload.refresh_token}"
                ),
            ),
        ],
        failure_mode=FailureMode.OPEN,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )


# Bütün authenticated endpoint'lerde user, IP ve mutation kurallarını uygular.
async def enforce_authenticated_rate_limit(
    request: Request,
    response: Response,
    current_user: CurrentUser,
    limiter: RateLimiterDependency,
) -> None:
    client_ip = get_client_ip(request)

    targets = [
        RateLimitTarget(
            AUTHENTICATED_USER,
            f"user:{current_user.id}",
        ),
        RateLimitTarget(
            AUTHENTICATED_IP,
            f"ip:{client_ip}",
        ),
    ]

    if request.method in {
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
    }:
        targets.append(
            RateLimitTarget(
                MUTATION_USER,
                f"user:{current_user.id}",
            )
        )

    decision = await limiter.enforce(
        targets,
        failure_mode=FailureMode.OPEN,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )


# Statistics endpoint'inde daha sıkı ve fail-closed kural uygular.
async def enforce_statistics_rate_limit(
    response: Response,
    current_user: CurrentUser,
    limiter: RateLimiterDependency,
) -> None:
    decision = await limiter.enforce(
        [
            RateLimitTarget(
                STATISTICS_USER,
                f"user:{current_user.id}",
            )
        ],
        failure_mode=FailureMode.CLOSED,
    )

    apply_rate_limit_headers(
        response.headers,
        decision,
    )
