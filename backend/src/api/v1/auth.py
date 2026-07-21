from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Request,
    Response,
    status,
)

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.repositories.auth_sessions import (
    AuthSessionRepository,
)
from src.repositories.users import UserRepository
from src.schemas.auth import (
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


def get_auth_service(
    db: DbSession,
) -> AuthService:
    return AuthService(
        user_repository=UserRepository(db),
        auth_session_repository=(
            AuthSessionRepository(db)
        ),
    )


AuthServiceDependency = Annotated[
    AuthService,
    Depends(get_auth_service),
]


def get_client_metadata(
    request: Request,
) -> tuple[str | None, str | None]:
    user_agent = request.headers.get(
        "user-agent",
    )

    if user_agent is not None:
        user_agent = user_agent[:512]

    ip_address = (
        request.client.host
        if request.client is not None
        else None
    )

    if ip_address is not None:
        ip_address = ip_address[:45]

    return user_agent, ip_address


@router.post(
    "/register",
    response_model=TokenPairResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
def register(
    payload: RegisterRequest,
    request: Request,
    auth_service: AuthServiceDependency,
) -> TokenPairResponse:
    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return auth_service.register(
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post(
    "/login",
    response_model=TokenPairResponse,
    summary="Log in",
)
def login(
    payload: LoginRequest,
    request: Request,
    auth_service: AuthServiceDependency,
) -> TokenPairResponse:
    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return auth_service.login(
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )


@router.post(
    "/refresh",
    response_model=TokenPairResponse,
    summary="Refresh authentication tokens",
)
def refresh(
    payload: RefreshTokenRequest,
    request: Request,
    auth_service: AuthServiceDependency,
) -> TokenPairResponse:
    user_agent, ip_address = (
        get_client_metadata(request)
    )

    return auth_service.refresh(
        payload,
        user_agent=user_agent,
        ip_address=ip_address,
    )


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
