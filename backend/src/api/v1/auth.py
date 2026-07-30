from typing import Annotated

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    Request,
    Response,
    status,
)
from starlette.concurrency import run_in_threadpool

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.api.dependencies.rate_limit import (
    RateLimiterDependency,
    clear_successful_login_limit,
    enforce_google_login_rate_limit,
    enforce_login_rate_limit,
    enforce_refresh_rate_limit,
    enforce_register_rate_limit,
)
from src.core.client_ip import get_client_ip
from src.api.dependencies.google_auth import (
    GoogleIdTokenVerifierDependency,
)
from src.repositories.auth_identities import (
    AuthIdentityRepository,
)
from src.repositories.auth_sessions import (
    AuthSessionRepository,
)
from src.repositories.users import UserRepository
from src.schemas.auth import (
    GoogleLoginRequest,
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    TokenPairResponse,
)
from src.services.auth import AuthService


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


# Her request için mevcut DB session'ını kullanan auth service oluşturur.
def get_auth_service(
    db: DbSession,
) -> AuthService:
    return AuthService(
        user_repository=UserRepository(db),
        password_credential_repository=(
            PasswordCredentialRepository(db)
        ),
        auth_identity_repository=(
            AuthIdentityRepository(db)
        ),
        auth_session_repository=(
            AuthSessionRepository(db)
        ),
    )


AuthServiceDependency = Annotated[
    AuthService,
    Depends(get_auth_service),
]


# Güvenli IP ve kısaltılmış user-agent bilgisini döndürür.
def get_client_metadata(
    request: Request,
) -> tuple[str | None, str]:
    user_agent = request.headers.get(
        "user-agent",
    )

    if user_agent is not None:
        user_agent = user_agent[:512]

    return user_agent, get_client_ip(request)[:45]


# Register limitini kontrol edip kullanıcıyı threadpool içinde oluşturur.
@router.post(
    "/register",
    response_model=TokenPairResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
async def register(
    payload: RegisterRequest,
    request: Request,
    response: Response,
    auth_service: AuthServiceDependency,
    limiter: RateLimiterDependency,
) -> TokenPairResponse:
    await enforce_register_rate_limit(
        request=request,
        response=response,
        limiter=limiter,
    )

    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return await run_in_threadpool(
        auth_service.register,
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )


# Login limitlerini kontrol edip parola doğrulamasını threadpool'da çalıştırır.
@router.post(
    "/login",
    response_model=TokenPairResponse,
    summary="Log in",
)
async def login(
    payload: LoginRequest,
    request: Request,
    response: Response,
    background_tasks: BackgroundTasks,
    auth_service: AuthServiceDependency,
    limiter: RateLimiterDependency,
) -> TokenPairResponse:
    rate_limit_context = (
        await enforce_login_rate_limit(
            payload=payload,
            request=request,
            response=response,
            limiter=limiter,
        )
    )

    user_agent, ip_address = (
        get_client_metadata(request)
    )

    token_pair = await run_in_threadpool(
        auth_service.login,
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )

    # Yalnız başarılı response sonrasında hesap sayacı temizlenir.
    background_tasks.add_task(
        clear_successful_login_limit,
        limiter=limiter,
        context=rate_limit_context,
    )

    return token_pair

# Google giriş
@router.post(
    "/google",
    response_model=TokenPairResponse,
    summary="Authenticate with Google",
)
async def google_login(
    payload: GoogleLoginRequest,
    request: Request,
    response: Response,
    auth_service: AuthServiceDependency,
    verifier: GoogleIdTokenVerifierDependency,
    limiter: RateLimiterDependency,
) -> TokenPairResponse:
    await enforce_google_login_rate_limit(
        payload=payload,
        request=request,
        response=response,
        limiter=limiter,
    )

    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return await run_in_threadpool(
        auth_service.login_with_google,
        payload,
        verifier=verifier,
        user_agent=user_agent,
        ip_address=ip_address,
    )


# Refresh limitlerini kontrol edip token rotation işlemini threadpool'da çalıştırır.
@router.post(
    "/refresh",
    response_model=TokenPairResponse,
    summary="Refresh authentication tokens",
)
async def refresh(
    payload: RefreshTokenRequest,
    request: Request,
    response: Response,
    auth_service: AuthServiceDependency,
    limiter: RateLimiterDependency,
) -> TokenPairResponse:
    await enforce_refresh_rate_limit(
        payload=payload,
        request=request,
        response=response,
        limiter=limiter,
    )

    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return await run_in_threadpool(
        auth_service.refresh,
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )


# Verilen refresh token'a ait session'ı kapatır.
@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    summary="Log out from the current session",
)
def logout(
    payload: LogoutRequest,
    auth_service: AuthServiceDependency,
) -> Response:
    auth_service.logout(payload)

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )


# Kullanıcının bütün aktif session'larını kapatır.
@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    summary="Log out from all sessions",
)
def logout_all(
    current_user: CurrentUser,
    auth_service: AuthServiceDependency,
) -> Response:
    auth_service.logout_all(current_user)

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )