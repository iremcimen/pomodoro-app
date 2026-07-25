from datetime import UTC, datetime
from typing import Annotated, Self
from uuid import UUID

from pydantic import (
    AfterValidator,
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)

from src.models.focus_sessions import (
    SessionStatus,
    SessionType,
)


# Timezone bilgisi bulunan tarih değerini UTC saat dilimine dönüştürür.
def normalize_to_utc(
    value: datetime,
) -> datetime:
    return value.astimezone(UTC)


# Session başlangıç tarihinin timezone bilgisi taşımasını ve UTC olmasını sağlar.
UtcDateTime = Annotated[
    AwareDatetime,
    AfterValidator(normalize_to_utc),
]


# Task kimliğinin pozitif bir sayı olmasını sağlar.
TaskId = Annotated[
    int,
    Field(
        gt=0,
    ),
]


# Planlanan session süresinin 1 saniye ile 12 saat arasında olmasını sağlar.
PlannedDurationSeconds = Annotated[
    int,
    Field(
        gt=0,
        le=43_200,
        description=(
            "Planned session duration in seconds."
        ),
    ),
]


# Gerçek session süresinin negatif olmasını engeller.
ActualDurationSeconds = Annotated[
    int,
    Field(
        ge=0,
        description=(
            "Actual session duration in seconds."
        ),
    ),
]


# Client'ın yeni bir FocusSession başlatırken gönderebileceği alanları tanımlar.
class StartFocusSessionRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    id: UUID

    task_id: TaskId | None = None

    session_type: SessionType

    planned_duration_seconds: (
        PlannedDurationSeconds
    )

    started_at: UtcDateTime

    # Bir Task'ın yalnızca focus türündeki session'a bağlanmasını sağlar.
    @model_validator(mode="after")
    def validate_task_assignment(
        self,
    ) -> Self:
        if (
            self.task_id is not None
            and self.session_type
            != SessionType.FOCUS
        ):
            raise ValueError(
                "A task can only be assigned "
                "to a focus session."
            )

        return self


# Client'ın session tamamlanırken gönderebileceği gerçek süre alanını tanımlar.
class EndFocusSessionRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    actual_duration_seconds: (
        ActualDurationSeconds
    )


# Veritabanındaki FocusSession kaydının API cevabında nasıl gösterileceğini tanımlar.
class FocusSessionResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        frozen=True,
    )

    id: UUID

    task_id: int | None

    session_type: SessionType

    status: SessionStatus

    planned_duration_seconds: int

    actual_duration_seconds: int | None

    started_at: datetime

    ended_at: datetime | None

    created_at: datetime
