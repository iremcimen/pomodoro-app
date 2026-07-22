from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

PROJECT_ROOT = Path(__file__).resolve().parents[3]
ENV_FILE = PROJECT_ROOT / ".env"


Environment = Literal[
    "development",
    "test",
    "staging",
    "production",
]

LogLevel = Literal[
    "TRACE",
    "DEBUG",
    "INFO",
    "SUCCESS",
    "WARNING",
    "ERROR",
    "CRITICAL",
]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    APP_NAME: str = "Pomodoro API"
    SERVICE_NAME: str = "pomodoro-api"
    APP_VERSION: str = "0.1.0"

    ENVIRONMENT: Environment = "development"
    DEBUG: bool = Field(
        default=False,
        validation_alias="POMODORO_DEBUG",
    )
    API_V1_PREFIX: str = "/api/v1"

    CORS_ALLOWED_ORIGINS: list[str] = []
    
    DATABASE_URL: str

    LOG_LEVEL: LogLevel = "INFO"
    LOG_JSON: bool = False
    LOG_COLORIZE: bool = True

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: Literal["HS256"] = "HS256"
    JWT_ISSUER: str = "pomodoro-api"
    JWT_AUDIENCE: str = "pomodoro-app"

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    REFRESH_TOKEN_PEPPER: str

    @field_validator("API_V1_PREFIX")
    @classmethod
    def validate_api_v1_prefix(cls, value: str) -> str:
        normalized_value = value.strip()

        if not normalized_value.startswith("/"):
            normalized_value = f"/{normalized_value}"

        return normalized_value.rstrip("/")

    @field_validator("APP_NAME", "SERVICE_NAME", "APP_VERSION")
    @classmethod
    def validate_required_text(cls, value: str) -> str:
        normalized_value = value.strip()

        if not normalized_value:
            raise ValueError("Value cannot be empty.")

        return normalized_value


@lru_cache
def get_settings() -> Settings:
    # Required values are loaded from environment variables
    # by pydantic-settings at runtime.
    return Settings()  # type: ignore[call-arg]


settings = get_settings()
