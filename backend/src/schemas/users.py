from datetime import datetime

from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)

_USERNAME_PATTERN = r"^[a-z0-9_]+$"


class UserResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        frozen=True,
    )

    id: int = Field(gt=0)
    username: str = Field(
        min_length=3,
        max_length=50,
    )
    full_name: str | None = Field(
        default=None,
        max_length=100,
    )
    created_at: datetime


class CurrentUserResponse(UserResponse):
    email: EmailStr = Field(max_length=320)
    is_active: bool
    updated_at: datetime


class UpdateCurrentUserRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    username: str | None = Field(
        default=None,
        min_length=3,
        max_length=50,
        pattern=_USERNAME_PATTERN,
    )

    full_name: str | None = Field(
        default=None,
        max_length=100,
    )

    @field_validator(
        "username",
        mode="before",
    )
    @classmethod
    def normalize_username(
        cls,
        value: object,
    ) -> object:
        if value is None:
            raise ValueError(
                "Username cannot be null."
            )

        if isinstance(value, str):
            return value.strip().lower()

        return value

    @field_validator(
        "full_name",
        mode="before",
    )
    @classmethod
    def normalize_full_name(
        cls,
        value: object,
    ) -> object:
        if not isinstance(value, str):
            return value

        normalized = value.strip()

        return normalized or None

    @model_validator(mode="after")
    def require_at_least_one_field(
        self,
    ) -> Self:
        if not self.model_fields_set:
            raise ValueError(
                "At least one field must be provided."
            )

        return self