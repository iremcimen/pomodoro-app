from datetime import datetime
from typing import Annotated, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)


FocusDurationMinutes = Annotated[
    int,
    Field(
        ge=1,
        le=180,
        description=(
            "Focus session duration in minutes."
        ),
    ),
]

ShortBreakMinutes = Annotated[
    int,
    Field(
        ge=1,
        le=60,
        description=(
            "Short break duration in minutes."
        ),
    ),
]

LongBreakMinutes = Annotated[
    int,
    Field(
        ge=1,
        le=120,
        description=(
            "Long break duration in minutes."
        ),
    ),
]

LongBreakInterval = Annotated[
    int,
    Field(
        ge=1,
        le=12,
        description=(
            "Number of focus sessions before a long break."
        ),
    ),
]

# Uygulamanın varsayılan değerleri
class UserSettingsDefaults(BaseModel):
    model_config = ConfigDict(
        frozen=True,
        extra="forbid",
    )

    focus_duration_minutes: FocusDurationMinutes = 25
    short_break_minutes: ShortBreakMinutes = 5
    long_break_minutes: LongBreakMinutes = 15
    long_break_interval: LongBreakInterval = 4

    auto_start_break: bool = False
    auto_start_focus: bool = False
    sound_enabled: bool = True
    vibration_enabled: bool = True

# PATCH isteğinin doğrulanması
class UpdateUserSettingsRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    focus_duration_minutes: (
        FocusDurationMinutes | None
    ) = None

    short_break_minutes: (
        ShortBreakMinutes | None
    ) = None

    long_break_minutes: (
        LongBreakMinutes | None
    ) = None

    long_break_interval: (
        LongBreakInterval | None
    ) = None

    auto_start_break: bool | None = None
    auto_start_focus: bool | None = None
    sound_enabled: bool | None = None
    vibration_enabled: bool | None = None

    @model_validator(mode="after")
    def validate_patch_request(
        self,
    ) -> Self:
        if not self.model_fields_set:
            raise ValueError(
                "At least one field must be provided."
            )

        null_fields = [
            field_name
            for field_name in self.model_fields_set
            if getattr(self, field_name) is None
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

# Veritabanı modelinin API cevabına çevrilmesi
class UserSettingsResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        frozen=True,
    )

    focus_duration_minutes: FocusDurationMinutes
    short_break_minutes: ShortBreakMinutes
    long_break_minutes: LongBreakMinutes
    long_break_interval: LongBreakInterval

    auto_start_break: bool
    auto_start_focus: bool
    sound_enabled: bool
    vibration_enabled: bool

    updated_at: datetime