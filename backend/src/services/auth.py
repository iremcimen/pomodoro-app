from datetime import UTC, datetime, timedelta
from uuid import UUID
import secrets

from src.core.config import settings
from src.core.exceptions import (
    AccountLinkRequiredException,
    EmailAlreadyExistsException,
    InactiveUserException,
    InvalidCredentialsException,
    InvalidRefreshTokenException,
    TokenReuseDetectedException,
    UsernameAlreadyExistsException,
)
from src.core.security.passwords import (
    hash_password,
    verify_password,
)
from src.core.security.tokens import (
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from src.core.security.google_tokens import (
    GoogleIdTokenVerifier,
)
from src.models.auth import AuthSession
from src.models.users import User
from src.repositories.auth_identities import (
    AuthIdentityRepository,
)
from src.repositories.auth_sessions import (
    AuthSessionRepository,
)
from src.repositories.users import UserRepository
from src.repositories.password_credentials import (
    PasswordCredentialRepository,
)
from src.schemas.auth import (
    GoogleLoginRequest,
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    TokenPairResponse,
)


_DUMMY_PASSWORD_HASH = hash_password(
    "dummy-password-for-timing-protection"
)


class AuthService:
    def __init__(
        self,
        user_repository: UserRepository,
        password_credential_repository: (
            PasswordCredentialRepository
        ),
        auth_identity_repository: (
            AuthIdentityRepository
        ),
        auth_session_repository: AuthSessionRepository,
    ) -> None:
        self._users = user_repository
        self._password_credentials = (
            password_credential_repository
        )
        self._auth_identities = (
            auth_identity_repository
        )
        self._auth_sessions = auth_session_repository

    # Rastgele refresh token üretir. Hash’ini veritabanına kaydeder. Session ID içeren access token üretir. Token pair oluşturur.
    def _create_session_and_token_pair(
        self,
        *,
        user_id: int,
        now: datetime,
        token_family_id: UUID | None = None,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> tuple[AuthSession, TokenPairResponse]:
        refresh_token = generate_refresh_token()

        auth_session = self._auth_sessions.create(
            user_id=user_id,
            refresh_token_hash=hash_refresh_token(
                refresh_token,
            ),
            expires_at=now
            + timedelta(
                days=settings.REFRESH_TOKEN_EXPIRE_DAYS,
            ),
            token_family_id=token_family_id,
            user_agent=user_agent,
            ip_address=ip_address,
        )

        access_token = create_access_token(
            user_id=user_id,
            session_id=auth_session.id,
        )

        token_pair = TokenPairResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=(
                settings.ACCESS_TOKEN_EXPIRE_MINUTES
                * 60
            ),
        )

        return auth_session, token_pair

    # Rastgele username üretir
    def _generate_google_username(self) -> str:
        for _ in range(10):
            candidate = (
                f"user_{secrets.token_hex(6)}"
            )

            if not self._users.exists_by_username(
                candidate
            ):
                return candidate

        raise RuntimeError(
            "A unique generated username "
            "could not be allocated."
        )
    

    def register(
        self,
        request: RegisterRequest,
        *,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> TokenPairResponse:
        email = str(request.email).strip().lower()
        username = request.username.strip().lower()

        if self._users.exists_by_email(email):
            raise EmailAlreadyExistsException()

        if self._users.exists_by_username(username):
            raise UsernameAlreadyExistsException()

        password_hash = hash_password(
            request.password,
        )

        user = self._users.create(
            email=email,
            username=username,
            full_name=request.full_name,
        )

        self._password_credentials.create(
            user_id=user.id,
            password_hash=password_hash,
        )

        _, token_pair = (
            self._create_session_and_token_pair(
                user_id=user.id,
                now=datetime.now(UTC),
                user_agent=user_agent,
                ip_address=ip_address,
            )
        )

        return token_pair
    

    def login(
        self,
        request: LoginRequest,
        *,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> TokenPairResponse:
        email = (
            str(request.email).strip().lower()
            if request.email is not None
            else None
        )
        username = (
            request.username.strip().lower()
            if request.username is not None
            else None
        )

        user = self._users.get_by_login(
            email=email,
            username=username,
        )

        if user is None:
            verify_password(
                request.password,
                _DUMMY_PASSWORD_HASH,
            )
            raise InvalidCredentialsException()

        credential = (
            self._password_credentials
            .get_by_user_id(user.id)
        )

        password_hash = (
            credential.password_hash
            if credential is not None
            else _DUMMY_PASSWORD_HASH
        )

        if not verify_password(
            request.password,
            password_hash,
        ):
            raise InvalidCredentialsException()

        if not user.is_active:
            raise InactiveUserException()

        _, token_pair = (
            self._create_session_and_token_pair(
                user_id=user.id,
                now=datetime.now(UTC),
                user_agent=user_agent,
                ip_address=ip_address,
            )
        )

        return token_pair

    def login_with_google(
        self,
        request: GoogleLoginRequest,
        *,
        verifier: GoogleIdTokenVerifier,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> TokenPairResponse:
        verified_identity = verifier.verify(
            request.id_token
        )

        identity = (
            self._auth_identities
            .get_by_provider_subject(
                provider="google",
                provider_subject=(
                    verified_identity.subject
                ),
            )
        )

        now = datetime.now(UTC)

        if identity is not None:
            user = self._users.get_by_id(
                identity.user_id
            )

            if user is None:
                raise RuntimeError(
                    "Google identity references "
                    "a missing user."
                )

            if not user.is_active:
                raise InactiveUserException()

            self._auth_identities.record_login(
                identity,
                email_snapshot=(
                    verified_identity.email
                ),
                email_verified=(
                    verified_identity.email_verified
                ),
                display_name=(
                    verified_identity.display_name
                ),
                avatar_url=(
                    verified_identity.avatar_url
                ),
            )

            _, token_pair = (
                self._create_session_and_token_pair(
                    user_id=user.id,
                    now=now,
                    user_agent=user_agent,
                    ip_address=ip_address,
                )
            )

            return token_pair

        existing_user = self._users.get_by_email(
            verified_identity.email
        )

        if existing_user is not None:
            raise AccountLinkRequiredException()

        user = self._users.create(
            email=verified_identity.email,
            username=self._generate_google_username(),
            full_name=verified_identity.display_name,
        )

        self._auth_identities.create(
            user_id=user.id,
            provider="google",
            provider_subject=(
                verified_identity.subject
            ),
            email_snapshot=(
                verified_identity.email
            ),
            email_verified=(
                verified_identity.email_verified
            ),
            display_name=(
                verified_identity.display_name
            ),
            avatar_url=(
                verified_identity.avatar_url
            ),
        )

        _, token_pair = (
            self._create_session_and_token_pair(
                user_id=user.id,
                now=now,
                user_agent=user_agent,
                ip_address=ip_address,
            )
        )

        return token_pair
    

    def refresh(
        self,
        request: RefreshTokenRequest,
        *,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ) -> TokenPairResponse:
        refresh_token_hash = hash_refresh_token(
            request.refresh_token,
        )

        old_session = (
            self._auth_sessions
            .get_by_refresh_token_hash_for_update(
                refresh_token_hash,
            )
        )

        now = datetime.now(UTC)

        if old_session is None:
            raise InvalidRefreshTokenException(
                reason="session_not_found",
            )

        if old_session.revoked_at is not None:
            if (
                old_session.replaced_by_session_id
                is not None
            ):
                self._auth_sessions.revoke_family(
                    old_session.token_family_id,
                    revoked_at=now,
                )
                raise TokenReuseDetectedException()

            raise InvalidRefreshTokenException()

        if old_session.expires_at <= now:
            raise InvalidRefreshTokenException(
                reason="expired",
            )

        user = self._users.get_by_id(
            old_session.user_id,
        )

        if user is None:
            raise InvalidRefreshTokenException(
                reason="user_not_found",
            )

        if not user.is_active:
            raise InactiveUserException()

        new_session, token_pair = (
            self._create_session_and_token_pair(
                user_id=user.id,
                now=now,
                token_family_id=(
                    old_session.token_family_id
                ),
                user_agent=user_agent,
                ip_address=ip_address,
            )
        )

        self._auth_sessions.revoke(
            old_session,
            revoked_at=now,
            replaced_by_session_id=new_session.id,
        )

        return token_pair
    

    def logout(
        self,
        request: LogoutRequest,
    ) -> bool:
        refresh_token_hash = hash_refresh_token(
            request.refresh_token,
        )

        auth_session = (
            self._auth_sessions
            .get_by_refresh_token_hash_for_update(
                refresh_token_hash,
            )
        )

        if auth_session is None:
            return False

        if auth_session.revoked_at is not None:
            return False

        self._auth_sessions.revoke(
            auth_session,
            revoked_at=datetime.now(UTC),
        )

        return True
    

    def logout_all(
        self,
        current_user: User,
    ) -> int:
        return self._auth_sessions.revoke_all_for_user(
            current_user.id,
            revoked_at=datetime.now(UTC),
        )