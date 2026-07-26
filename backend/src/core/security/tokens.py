import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import jwt
from jwt.exceptions import InvalidTokenError

from src.core.config import settings


_JWT_LEEWAY_SECONDS = 5


def create_access_token(
    *,
    user_id: int,
    session_id: UUID,
) -> str:
    issued_at = datetime.now(UTC)
    expires_at = issued_at + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
    )

    payload: dict[str, Any] = {
        "sub": str(user_id),
        "sid": str(session_id),
        "type": "access",
        "jti": str(uuid4()),
        "iat": issued_at,
        "exp": expires_at,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
    }

    return jwt.encode(
        payload,
        settings.JWT_SECRET_KEY.get_secret_value(),
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(
    token: str,
) -> dict[str, Any]:
    payload: dict[str, Any] = jwt.decode(
        token,
        settings.JWT_SECRET_KEY.get_secret_value(),
        algorithms=[settings.JWT_ALGORITHM],
        audience=settings.JWT_AUDIENCE,
        issuer=settings.JWT_ISSUER,
        leeway=_JWT_LEEWAY_SECONDS,
        options={
            "require": [
                "sub",
                "sid",
                "type",
                "jti",
                "iat",
                "exp",
                "iss",
                "aud",
            ],
            "strict_aud": True,
            "enforce_minimum_key_length": True,
        },
    )

    try:
        if payload["type"] != "access":
            raise ValueError

        subject = payload["sub"]

        if (
            not isinstance(subject, str)
            or not subject.isdecimal()
            or int(subject) <= 0
        ):
            raise ValueError

        UUID(payload["sid"])
        UUID(payload["jti"])
    except (
        KeyError,
        TypeError,
        ValueError,
    ) as exc:
        raise InvalidTokenError(
            "Invalid access token claims."
        ) from exc

    return payload


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(
    refresh_token: str,
) -> str:
    if not refresh_token:
        raise ValueError(
            "Refresh token cannot be empty."
        )

    pepper = (
        settings
        .REFRESH_TOKEN_PEPPER
        .get_secret_value()
    )

    return hmac.new(
        key=pepper.encode("utf-8"),
        msg=refresh_token.encode("utf-8"),
        digestmod=hashlib.sha256,
    ).hexdigest()
