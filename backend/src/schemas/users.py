from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


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