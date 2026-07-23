from typing import Literal, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)


_USERNAME_PATTERN = r"^[a-z0-9_]+$"


def _strip_and_lower(value: object) -> object:
    if isinstance(value, str):
        return value.strip().lower()

    return value


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(max_length=320)
    username: str = Field(
        min_length=3,
        max_length=50,
        pattern=_USERNAME_PATTERN,
    )
    full_name: str | None = Field(
        default=None,
        max_length=100,
    )
    password: str = Field(
        min_length=8,
        max_length=128,
        repr=False,
        json_schema_extra={"writeOnly": True},
    )

    @field_validator("email", "username", mode="before")
    @classmethod
    def normalize_identity_fields(cls, value: object) -> object:
        return _strip_and_lower(value)

    @field_validator("full_name", mode="before")
    @classmethod
    def normalize_full_name(cls, value: object) -> object:
        if not isinstance(value, str):
            return value

        normalized_value = value.strip()
        return normalized_value or None


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr | None = Field(
        default=None,
        max_length=320,
    )
    username: str | None = Field(
        default=None,
        min_length=3,
        max_length=50,
        pattern=_USERNAME_PATTERN,
    )
    password: str = Field(
        min_length=8,
        max_length=128,
        repr=False,
        json_schema_extra={"writeOnly": True},
    )

    @field_validator("email", "username", mode="before")
    @classmethod
    def normalize_identity_fields(cls, value: object) -> object:
        return _strip_and_lower(value)

    @model_validator(mode="after")
    def validate_login_identifier(self) -> Self:
        if (self.email is None) == (self.username is None):
            raise ValueError(
                "Exactly one of email or username must be provided."
            )

        return self


class RefreshTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(
        min_length=32,
        max_length=512,
        repr=False,
        json_schema_extra={"writeOnly": True},
    )

    @field_validator("refresh_token", mode="before")
    @classmethod
    def normalize_refresh_token(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip()

        return value


class LogoutRequest(RefreshTokenRequest):
    pass


class TokenPairResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    access_token: str = Field(min_length=1)
    refresh_token: str = Field(min_length=32)
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = Field(
        gt=0,
        description="Access token lifetime in seconds.",
    )