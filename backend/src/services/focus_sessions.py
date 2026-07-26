from datetime import UTC, datetime
from uuid import UUID

from src.core.exceptions import (
    ActiveSessionExistsException,
    BadRequestException,
    ConflictException,
    InvalidSessionTransitionException,
    ResourceNotFoundException,
)
from src.models.focus_sessions import (
    FocusSession,
    SessionStatus,
    SessionType,
)
from src.models.users import User
from src.repositories.focus_sessions import (
    FocusSessionRepository,
)
from src.repositories.tasks import TaskRepository
from src.schemas.focus_sessions import (
    EndFocusSessionRequest,
    StartFocusSessionRequest,
)


# FocusSession işlemlerindeki bütün iş kurallarını yönetir.
class FocusSessionService:
    # Service'in kullanacağı FocusSession ve Task repository'lerini kaydeder.
    def __init__(
        self,
        focus_session_repository: (
            FocusSessionRepository
        ),
        task_repository: TaskRepository,
    ) -> None:
        self._focus_sessions = (
            focus_session_repository
        )
        self._tasks = task_repository

    # Session'ı yalnızca kullanıcıya aitse bulur, bulamazsa güvenli 404 hatası verir.
    def _get_session_for_user(
        self,
        *,
        session_id: UUID,
        user_id: int,
    ) -> FocusSession:
        focus_session = (
            self._focus_sessions.get_by_id_for_user(
                session_id=session_id,
                user_id=user_id,
            )
        )

        if focus_session is None:
            raise ResourceNotFoundException(
                "Focus session"
            )

        return focus_session

    # Session'ı kullanıcıya aitse bulur ve bitirme işlemi tamamlanana kadar kilitler.
    def _get_session_for_user_for_update(
        self,
        *,
        session_id: UUID,
        user_id: int,
    ) -> FocusSession:
        focus_session = (
            self._focus_sessions
            .get_by_id_for_user_for_update(
                session_id=session_id,
                user_id=user_id,
            )
        )

        if focus_session is None:
            raise ResourceNotFoundException(
                "Focus session"
            )

        return focus_session

    # Giriş yapmış kullanıcı için yeni ve aktif bir FocusSession başlatır.
    def start_session(
        self,
        current_user: User,
        request: StartFocusSessionRequest,
    ) -> FocusSession:
        active_session = (
            self._focus_sessions
            .get_active_for_user(
                user_id=current_user.id,
            )
        )

        if active_session is not None:
            raise ActiveSessionExistsException()

        if request.task_id is not None:
            task = self._tasks.get_by_id_for_user(
                task_id=request.task_id,
                user_id=current_user.id,
            )

            if task is None:
                raise ResourceNotFoundException(
                    "Task"
                )

            if (
                request.session_type
                != SessionType.FOCUS
            ):
                raise BadRequestException(
                    "A task can only be assigned "
                    "to a focus session."
                )

            if task.is_completed:
                raise ConflictException(
                    "A completed task cannot be "
                    "assigned to a new session."
                )

        return self._focus_sessions.create(
            session_id=request.id,
            user_id=current_user.id,
            task_id=request.task_id,
            session_type=request.session_type,
            planned_duration_seconds=(
                request.planned_duration_seconds
            ),
            started_at=request.started_at,
        )

    # Kullanıcının halen devam eden FocusSession kaydını getirir.
    def get_active_session(
        self,
        current_user: User,
    ) -> FocusSession:
        focus_session = (
            self._focus_sessions
            .get_active_for_user(
                user_id=current_user.id,
            )
        )

        if focus_session is None:
            raise ResourceNotFoundException(
                "Focus session"
            )

        return focus_session

    # Kullanıcıya ait tek bir FocusSession kaydını getirir.
    def get_session(
        self,
        current_user: User,
        session_id: UUID,
    ) -> FocusSession:
        return self._get_session_for_user(
            session_id=session_id,
            user_id=current_user.id,
        )

    # Aktif session'ı istenen bitiş durumuna geçirip gerekli Task işlemlerini yapar.
    def _finish_session(
        self,
        *,
        current_user: User,
        session_id: UUID,
        request: EndFocusSessionRequest,
        target_status: SessionStatus,
    ) -> FocusSession:
        focus_session = (
            self._get_session_for_user_for_update(
                session_id=session_id,
                user_id=current_user.id,
            )
        )

        if (
            focus_session.status
            != SessionStatus.STARTED.value
        ):
            raise (
                InvalidSessionTransitionException()
            )

        ended_at = datetime.now(UTC)

        finished_session = (
            self._focus_sessions.finish(
                focus_session,
                {
                    "status": target_status.value,
                    "actual_duration_seconds": (
                        request.actual_duration_seconds
                    ),
                    "ended_at": ended_at,
                },
            )
        )

        should_increment_task = (
            target_status
            == SessionStatus.COMPLETED
            and focus_session.session_type
            == SessionType.FOCUS.value
            and focus_session.task_id is not None
        )

        if should_increment_task:
            updated_task = (
                self._tasks
                .increment_completed_pomodoros(
                    task_id=focus_session.task_id,
                    user_id=current_user.id,
                )
            )

            if updated_task is None:
                raise ResourceNotFoundException(
                    "Task"
                )

        return finished_session

    # Aktif session'ı tamamlar ve bağlı Task varsa Pomodoro sayısını artırır.
    def complete_session(
        self,
        current_user: User,
        session_id: UUID,
        request: EndFocusSessionRequest,
    ) -> FocusSession:
        return self._finish_session(
            current_user=current_user,
            session_id=session_id,
            request=request,
            target_status=(
                SessionStatus.COMPLETED
            ),
        )

    # Aktif session'ı kullanıcı tarafından iptal edilmiş duruma geçirir.
    def cancel_session(
        self,
        current_user: User,
        session_id: UUID,
        request: EndFocusSessionRequest,
    ) -> FocusSession:
        return self._finish_session(
            current_user=current_user,
            session_id=session_id,
            request=request,
            target_status=(
                SessionStatus.CANCELLED
            ),
        )

    # Aktif session'ı yarıda kesilmiş duruma geçirir.
    def interrupt_session(
        self,
        current_user: User,
        session_id: UUID,
        request: EndFocusSessionRequest,
    ) -> FocusSession:
        return self._finish_session(
            current_user=current_user,
            session_id=session_id,
            request=request,
            target_status=(
                SessionStatus.INTERRUPTED
            ),
        )
