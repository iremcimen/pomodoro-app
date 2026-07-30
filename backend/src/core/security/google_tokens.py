# Google ID token doğrulayıcısı
from dataclasses import dataclass
from threading import Lock, local
from urllib.parse import urlparse

from cachecontrol import CacheControl
from email_validator import (
    EmailNotValidError,
    validate_email,
)
from google.auth.exceptions import TransportError
from google.auth.transport.requests import (
    Request as GoogleRequest,
)
from google.oauth2 import id_token as google_id_token
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from src.core.exceptions import (
    GoogleIdentityProviderUnavailableException,
    InvalidGoogleTokenException,
)


@dataclass(frozen=True, slots=True)
class VerifiedGoogleIdentity:
    subject: str
    email: str
    email_verified: bool
    display_name: str | None
    avatar_url: str | None
    hosted_domain: str | None
    audience: str


class GoogleIdTokenVerifier:
    def __init__(
        self,
        *,
        client_ids: list[str],
        clock_skew_seconds: int,
    ) -> None:
        normalized_client_ids = tuple(
            dict.fromkeys(
                client_id.strip()
                for client_id in client_ids
                if client_id.strip()
            )
        )

        if not normalized_client_ids:
            raise ValueError(
                "At least one Google OAuth client ID "
                "must be configured."
            )

        self._client_ids = normalized_client_ids
        self._clock_skew_seconds = clock_skew_seconds
        self._thread_local = local()
        self._sessions: list[requests.Session] = []
        self._sessions_lock = Lock()

    def _get_request(self) -> GoogleRequest:
        current_request = getattr(
            self._thread_local,
            "google_request",
            None,
        )

        if isinstance(current_request, GoogleRequest):
            return current_request

        session = requests.Session()

        retry = Retry(
            total=2,
            connect=2,
            read=1,
            status=2,
            backoff_factor=0.2,
            status_forcelist=(
                408,
                429,
                500,
                502,
                503,
                504,
            ),
            allowed_methods=frozenset({"GET"}),
            raise_on_status=False,
        )

        session.mount(
            "https://",
            HTTPAdapter(max_retries=retry),
        )

        cached_session = CacheControl(session)

        google_request = GoogleRequest(
            session=cached_session,
        )

        self._thread_local.google_request = (
            google_request
        )

        with self._sessions_lock:
            self._sessions.append(cached_session)

        return google_request

    def verify(
        self,
        raw_token: str,
    ) -> VerifiedGoogleIdentity:
        try:
            claims = (
                google_id_token.verify_oauth2_token(
                    raw_token,
                    self._get_request(),
                    audience=list(self._client_ids),
                    clock_skew_in_seconds=(
                        self._clock_skew_seconds
                    ),
                )
            )
        except TransportError as exc:
            raise (
                GoogleIdentityProviderUnavailableException()
            ) from exc
        except ValueError as exc:
            raise InvalidGoogleTokenException() from exc

        audience = claims.get("aud")

        if (
            not isinstance(audience, str)
            or audience not in self._client_ids
        ):
            raise InvalidGoogleTokenException(
                reason="wrong_audience",
            )

        subject = claims.get("sub")

        if (
            not isinstance(subject, str)
            or not subject.strip()
            or len(subject) > 255
        ):
            raise InvalidGoogleTokenException(
                reason="missing_subject",
            )

        raw_email = claims.get("email")

        if not isinstance(raw_email, str):
            raise InvalidGoogleTokenException(
                reason="missing_email",
            )

        try:
            email = validate_email(
                raw_email,
                check_deliverability=False,
            ).normalized
        except EmailNotValidError as exc:
            raise InvalidGoogleTokenException(
                reason="missing_email",
            ) from exc

        if claims.get("email_verified") is not True:
            raise InvalidGoogleTokenException(
                reason="email_not_verified",
            )

        display_name = self._optional_text(
            claims.get("name"),
            max_length=100,
        )

        avatar_url = self._validated_avatar_url(
            claims.get("picture")
        )

        hosted_domain = self._optional_text(
            claims.get("hd"),
            max_length=255,
        )

        return VerifiedGoogleIdentity(
            subject=subject.strip(),
            email=email.lower(),
            email_verified=True,
            display_name=display_name,
            avatar_url=avatar_url,
            hosted_domain=hosted_domain,
            audience=audience,
        )

    def close(self) -> None:
        with self._sessions_lock:
            sessions = list(self._sessions)
            self._sessions.clear()

        for session in sessions:
            session.close()

    @staticmethod
    def _optional_text(
        value: object,
        *,
        max_length: int,
    ) -> str | None:
        if not isinstance(value, str):
            return None

        normalized = value.strip()

        if not normalized:
            return None

        return normalized[:max_length]

    @staticmethod
    def _validated_avatar_url(
        value: object,
    ) -> str | None:
        if not isinstance(value, str):
            return None

        normalized = value.strip()

        if not normalized or len(normalized) > 2048:
            return None

        parsed = urlparse(normalized)

        if (
            parsed.scheme != "https"
            or not parsed.hostname
        ):
            return None

        return normalized

"""
Bu sınıf:
Google imzasını doğrular.
iss kontrolünü Google kütüphanesine yaptırır.
Token süresini kontrol eder.
İzin verilen iki audience’dan birini kabul eder.
sub değerini kalıcı Google kimliği olarak çıkarır.
E-postanın doğrulanmış olmasını ister.
Google public key’lerini cache’ler.
Token’ı veya claim’leri loglamaz.
"""