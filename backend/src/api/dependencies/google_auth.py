# Google verifier dependency
from typing import Annotated

from fastapi import Depends, Request

from src.core.config import settings
from src.core.exceptions import (
    GoogleAuthenticationDisabledException,
)
from src.core.security.google_tokens import (
    GoogleIdTokenVerifier,
)


def get_google_id_token_verifier(
    request: Request,
) -> GoogleIdTokenVerifier:
    if not settings.GOOGLE_AUTH_ENABLED:
        raise GoogleAuthenticationDisabledException()

    verifier = getattr(
        request.app.state,
        "google_id_token_verifier",
        None,
    )

    if not isinstance(
        verifier,
        GoogleIdTokenVerifier,
    ):
        raise RuntimeError(
            "Google ID token verifier is not initialized."
        )

    return verifier


GoogleIdTokenVerifierDependency = Annotated[
    GoogleIdTokenVerifier,
    Depends(get_google_id_token_verifier),
]
