from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import Depends
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
)
from jwt.exceptions import (
    ExpiredSignatureError,
    InvalidTokenError,
)

from src.api.dependencies.database import DbSession
from src.core.exceptions import (
    AuthenticationRequiredException,
    ExpiredTokenException,
    InactiveUserException,
    InvalidTokenException,
)
from src.core.security.tokens import decode_access_token
from src.models.users import User
from src.repositories.auth_sessions import (
    AuthSessionRepository,
)
from src.repositories.users import UserRepository


bearer_scheme = HTTPBearer(
    auto_error=False,
)


BearerCredentials = Annotated[
    HTTPAuthorizationCredentials | None,
    Depends(bearer_scheme),
]


def get_current_user(
    credentials: BearerCredentials,
    db: DbSession,
) -> User:
    if credentials is None:
        raise AuthenticationRequiredException()

    if credentials.scheme.lower() != "bearer":
        raise AuthenticationRequiredException()

    try:
        payload = decode_access_token(
            credentials.credentials,
        )
    except ExpiredSignatureError as exc:
        raise ExpiredTokenException() from exc
    except InvalidTokenError as exc:
        raise InvalidTokenException() from exc

    try:
        user_id = int(payload["sub"])
        session_id = UUID(payload["sid"])
    except (KeyError, TypeError, ValueError) as exc:
        raise InvalidTokenException(
            reason="invalid_claims",
        ) from exc

    auth_sessions = AuthSessionRepository(db)

    auth_session = auth_sessions.get_by_id(
        session_id,
    )

    if auth_session is None:
        raise InvalidTokenException(
            reason="session_not_found",
        )

    if auth_session.user_id != user_id:
        raise InvalidTokenException(
            reason="invalid_claims",
        )

    if auth_session.revoked_at is not None:
        raise InvalidTokenException(
            reason="revoked",
        )

    if auth_session.expires_at <= datetime.now(UTC):
        raise ExpiredTokenException()

    users = UserRepository(db)

    user = users.get_by_id(user_id)

    if user is None:
        raise InvalidTokenException(
            reason="invalid_claims",
        )

    if not user.is_active:
        raise InactiveUserException()

    return user


CurrentUser = Annotated[
    User,
    Depends(get_current_user),
]

"""
Buradaki kontrol sırası bilinçli:
Authorization header var mı?
Bearer şeması doğru mu?
JWT imzası, issuer, audience ve süre geçerli mi?
sub ve sid doğru tipte mi?
Session gerçekten var mı?
Session bu kullanıcıya mı ait?
Session revoke edilmiş mi?
Kullanıcı var ve aktif mi?
"""