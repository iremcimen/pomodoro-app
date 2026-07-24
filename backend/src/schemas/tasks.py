from datetime import datetime
from typing import Annotated, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


# Task başlığının uzunluk kurallarını tanımlar.
TaskTitle = Annotated[
    str,
    Field(
        min_length=1,
        max_length=160,
        description="Task title.",
    ),
]


# Tahmini Pomodoro sayısının negatif olmasını engeller.
EstimatedPomodoros = Annotated[
    int,
    Field(
        ge=0,
        description=(
            "Estimated number of Pomodoro sessions."
        ),
    ),
]


# Tamamlanan Pomodoro sayısının negatif olmasını engeller.
CompletedPomodoros = Annotated[
    int,
    Field(
        ge=0,
        description=(
            "Number of completed Pomodoro sessions."
        ),
    ),
]


# Task oluşturma ve güncelleme isteklerinin ortak doğrulama kurallarını tutar.
class TaskRequestBase(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    # Başlığın başındaki ve sonundaki gereksiz boşlukları temizler.
    @field_validator(
        "title",
        mode="before",
        check_fields=False,
    )
    @classmethod
    def normalize_title(
        cls,
        value: object,
    ) -> object:
        if isinstance(value, str):
            return value.strip()

        return value

    # Boş açıklamaları temizleyerek None değerine dönüştürür.
    @field_validator(
        "description",
        mode="before",
        check_fields=False,
    )
    @classmethod
    def normalize_description(
        cls,
        value: object,
    ) -> object:
        if not isinstance(value, str):
            return value

        normalized = value.strip()

        return normalized or None


# Yeni bir Task oluşturulurken client'tan alınabilecek alanları tanımlar.
class CreateTaskRequest(TaskRequestBase):
    title: TaskTitle

    description: str | None = None

    estimated_pomodoros: EstimatedPomodoros = 1


# Mevcut bir Task güncellenirken client'ın değiştirebileceği alanları tanımlar.
class UpdateTaskRequest(TaskRequestBase):
    title: TaskTitle | None = None

    description: str | None = None

    estimated_pomodoros: (
        EstimatedPomodoros | None
    ) = None

    is_completed: bool | None = None

    # Boş PATCH isteklerini ve null olamayacak alanların null gönderilmesini engeller.
    @model_validator(mode="after")
    def validate_patch_request(
        self,
    ) -> Self:
        if not self.model_fields_set:
            raise ValueError(
                "At least one field must be provided."
            )

        non_nullable_fields = {
            "title",
            "estimated_pomodoros",
            "is_completed",
        }

        null_fields = [
            field_name
            for field_name in self.model_fields_set
            if (
                field_name in non_nullable_fields
                and getattr(self, field_name) is None
            )
        ]

        if null_fields:
            formatted_fields = ", ".join(
                sorted(null_fields),
            )

            raise ValueError(
                "Fields cannot be null: "
                f"{formatted_fields}."
            )

        return self


# Veritabanındaki Task modelinin API cevabında nasıl gösterileceğini tanımlar.
class TaskResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        frozen=True,
    )

    id: int = Field(gt=0)

    title: TaskTitle

    description: str | None

    estimated_pomodoros: EstimatedPomodoros

    completed_pomodoros: CompletedPomodoros

    is_completed: bool

    completed_at: datetime | None

    created_at: datetime

    updated_at: datetime

