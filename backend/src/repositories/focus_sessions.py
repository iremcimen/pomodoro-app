from collections.abc import Mapping
from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from src.models.focus_sessions import (
    FocusSession,
    SessionStatus,
    SessionType,
)


# FocusSession kayıtlarıyla ilgili veritabanı işlemlerini yönetir.
class FocusSessionRepository:
    # Session biterken değiştirilebilecek alanları sınırlar.
    _FINISHABLE_FIELDS = frozenset(
        {
            "status",
            "actual_duration_seconds",
            "ended_at",
        }
    )

    # Repository'nin kullanacağı veritabanı oturumunu kaydeder.
    def __init__(
        self,
        db: Session,
    ) -> None:
        self._db = db

    # Verilen bilgilerle kullanıcıya ait yeni ve aktif bir session oluşturur.
    def create(
        self,
        *,
        session_id: UUID,
        user_id: int,
        task_id: int | None,
        session_type: SessionType,
        planned_duration_seconds: int,
        started_at: datetime,
    ) -> FocusSession:
        focus_session = FocusSession(
            id=session_id,
            user_id=user_id,
            task_id=task_id,
            session_type=session_type.value,
            status=SessionStatus.STARTED.value,
            planned_duration_seconds=(
                planned_duration_seconds
            ),
            started_at=started_at,
        )

        self._db.add(focus_session)
        self._db.flush()
        self._db.refresh(focus_session)

        return focus_session

    # Session'ı yalnızca belirtilen kullanıcıya aitse bulup döndürür.
    def get_by_id_for_user(
        self,
        *,
        session_id: UUID,
        user_id: int,
    ) -> FocusSession | None:
        statement = select(
            FocusSession
        ).where(
            FocusSession.id == session_id,
            FocusSession.user_id == user_id,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    # Kullanıcının halen devam eden session'ını bulup döndürür.
    def get_active_for_user(
        self,
        *,
        user_id: int,
    ) -> FocusSession | None:
        statement = select(
            FocusSession
        ).where(
            FocusSession.user_id == user_id,
            FocusSession.status
            == SessionStatus.STARTED.value,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    # Kullanıcıya ait session'ı işlem bitene kadar veritabanında kilitleyerek getirir.
    def get_by_id_for_user_for_update(
        self,
        *,
        session_id: UUID,
        user_id: int,
    ) -> FocusSession | None:
        statement = (
            select(FocusSession)
            .where(
                FocusSession.id == session_id,
                FocusSession.user_id == user_id,
            )
            .with_for_update()
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    # Session'ın durumunu, gerçek süresini ve bitiş zamanını birlikte günceller.
    def finish(
        self,
        focus_session: FocusSession,
        values: Mapping[str, object],
    ) -> FocusSession:
        provided_fields = set(
            values.keys()
        )

        unsupported_fields = (
            provided_fields
            - self._FINISHABLE_FIELDS
        )

        missing_fields = (
            self._FINISHABLE_FIELDS
            - provided_fields
        )

        if unsupported_fields:
            field_names = ", ".join(
                sorted(unsupported_fields),
            )

            raise ValueError(
                "Unsupported focus session fields: "
                f"{field_names}"
            )

        if missing_fields:
            field_names = ", ".join(
                sorted(missing_fields),
            )

            raise ValueError(
                "Missing focus session fields: "
                f"{field_names}"
            )

        for field_name, value in values.items():
            setattr(
                focus_session,
                field_name,
                value,
            )

        self._db.flush()
        self._db.refresh(focus_session)

        return focus_session

    def completed_focus_summary(
        self,
        *,
        user_id: int,
        since: datetime,
    ) -> tuple[int, int]:
        statement = select(
            func.coalesce(
                func.sum(
                    FocusSession.actual_duration_seconds,
                ),
                0,
            ),
            func.count(FocusSession.id),
        ).where(
            FocusSession.user_id == user_id,
            FocusSession.session_type
            == SessionType.FOCUS.value,
            FocusSession.status
            == SessionStatus.COMPLETED.value,
            FocusSession.ended_at >= since,
        )

        row = self._db.execute(statement).one()

        return int(row[0]), int(row[1])
