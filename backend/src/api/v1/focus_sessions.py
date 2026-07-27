from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    status,
)

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.models.focus_sessions import FocusSession
from src.repositories.focus_sessions import (
    FocusSessionRepository,
)
from src.repositories.tasks import TaskRepository
from src.schemas.focus_sessions import (
    EndFocusSessionRequest,
    FocusSessionResponse,
    StartFocusSessionRequest,
)
from src.services.focus_sessions import (
    FocusSessionService,
)


# FocusSession endpointlerini /focus-sessions adresi altında toplar.
router = APIRouter(
    prefix="/focus-sessions",
    tags=["Focus Sessions"],
)


# Her HTTP isteği için gerekli repository ve FocusSession service nesnelerini oluşturur.
def get_focus_session_service(
    db: DbSession,
) -> FocusSessionService:
    return FocusSessionService(
        focus_session_repository=(
            FocusSessionRepository(db)
        ),
        task_repository=TaskRepository(db),
    )


# FocusSessionService nesnesinin FastAPI tarafından otomatik oluşturulmasını sağlar.
FocusSessionServiceDependency = Annotated[
    FocusSessionService,
    Depends(get_focus_session_service),
]


# Giriş yapmış kullanıcı için yeni bir FocusSession başlatır.
@router.post(
    "",
    response_model=FocusSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Start a focus session",
)
def start_focus_session(
    payload: StartFocusSessionRequest,
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return focus_session_service.start_session(
        current_user,
        payload,
    )


# Giriş yapmış kullanıcının halen devam eden FocusSession kaydını getirir.
@router.get(
    "/active",
    response_model=FocusSessionResponse,
    summary="Get the active focus session",
)
def get_active_focus_session(
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return (
        focus_session_service.get_active_session(
            current_user,
        )
    )


# Giriş yapmış kullanıcıya ait tek bir FocusSession kaydını getirir.
@router.get(
    "/{session_id}",
    response_model=FocusSessionResponse,
    summary="Get a focus session",
)
def get_focus_session(
    session_id: UUID,
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return focus_session_service.get_session(
        current_user,
        session_id,
    )


# Aktif FocusSession kaydını tamamlanmış duruma geçirir.
@router.post(
    "/{session_id}/complete",
    response_model=FocusSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Complete a focus session",
)
def complete_focus_session(
    session_id: UUID,
    payload: EndFocusSessionRequest,
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return (
        focus_session_service.complete_session(
            current_user,
            session_id,
            payload,
        )
    )


# Aktif FocusSession kaydını iptal edilmiş duruma geçirir.
@router.post(
    "/{session_id}/cancel",
    response_model=FocusSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Cancel a focus session",
)
def cancel_focus_session(
    session_id: UUID,
    payload: EndFocusSessionRequest,
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return (
        focus_session_service.cancel_session(
            current_user,
            session_id,
            payload,
        )
    )


# Aktif FocusSession kaydını yarıda kesilmiş duruma geçirir.
@router.post(
    "/{session_id}/interrupt",
    response_model=FocusSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Interrupt a focus session",
)
def interrupt_focus_session(
    session_id: UUID,
    payload: EndFocusSessionRequest,
    current_user: CurrentUser,
    focus_session_service: (
        FocusSessionServiceDependency
    ),
) -> FocusSession:
    return (
        focus_session_service.interrupt_session(
            current_user,
            session_id,
            payload,
        )
    )
