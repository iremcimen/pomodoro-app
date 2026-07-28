from ipaddress import ip_network
from functools import lru_cache
from pathlib import Path
from typing import Literal
from urllib.parse import parse_qs, urlparse

from pydantic import (
    Field,
    SecretStr,
    field_validator,
    model_validator,
)
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


FORBIDDEN_SECRET_VALUES = {
    "",
    "change-me",
    "changeme",
    "default",
    "development",
    "password",
    "secret",
    "your-secret-here",
}


def is_strong_secret(value: str) -> bool:
    normalized_value = value.strip()

    return (
        len(normalized_value) >= 32
        and normalized_value.lower()
        not in FORBIDDEN_SECRET_VALUES
    )


def validate_production_database_url(
    database_url: str,
) -> list[str]:
    errors: list[str] = []
    parsed_url = urlparse(database_url)

    if not parsed_url.scheme.startswith("postgresql"):
        errors.append(
            "DATABASE_URL must use PostgreSQL in production."
        )

    if not parsed_url.hostname:
        errors.append(
            "DATABASE_URL must contain a database host."
        )
    elif parsed_url.hostname.lower() in {
        "localhost",
        "127.0.0.1",
        "::1",
    }:
        errors.append(
            "DATABASE_URL cannot use a loopback host "
            "in production."
        )

    if not parsed_url.username:
        errors.append(
            "DATABASE_URL must contain a database username."
        )

    if not parsed_url.password:
        errors.append(
            "DATABASE_URL must contain a database password."
        )
    elif (
        parsed_url.password.strip().lower()
        in FORBIDDEN_SECRET_VALUES
    ):
        errors.append(
            "DATABASE_URL contains an unsafe "
            "placeholder password."
        )

    query_parameters = parse_qs(parsed_url.query)
    ssl_modes = query_parameters.get("sslmode", [])

    if not ssl_modes or ssl_modes[0] not in {
        "require",
        "verify-ca",
        "verify-full",
    }:
        errors.append(
            "DATABASE_URL must enable SSL with sslmode=require, "
            "verify-ca or verify-full in production."
        )

    return errors


def validate_production_redis_url(
    redis_url: str,
) -> list[str]:
    errors: list[str] = []
    parsed_url = urlparse(redis_url)

    if parsed_url.scheme != "rediss":
        errors.append(
            "REDIS_URL must use rediss:// in production."
        )

    if not parsed_url.hostname:
        errors.append(
            "REDIS_URL must contain a Redis host."
        )
    elif parsed_url.hostname.lower() in {
        "localhost",
        "127.0.0.1",
        "::1",
    }:
        errors.append(
            "REDIS_URL cannot use a loopback host "
            "in production."
        )

    if not parsed_url.username:
        errors.append(
            "REDIS_URL must contain an ACL username "
            "in production."
        )

    if not parsed_url.password:
        errors.append(
            "REDIS_URL must contain a password "
            "in production."
        )
    elif (
        parsed_url.password.strip().lower()
        in FORBIDDEN_SECRET_VALUES
    ):
        errors.append(
            "REDIS_URL contains an unsafe "
            "placeholder password."
        )

    return errors


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application settings
    APP_NAME: str = "Pomodoro API"
    SERVICE_NAME: str = "pomodoro-api"
    APP_VERSION: str = "0.1.0"
    ENVIRONMENT: Environment = "development"
    DEBUG: bool = Field(
        default=False,
        validation_alias="POMODORO_DEBUG",
    )
    API_V1_PREFIX: str = "/api/v1"
    MAX_REQUEST_BODY_BYTES: int = Field(
        default=1_048_576,
        gt=0,
    )

    # Database settings
    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = Field(
        default=5,
        ge=1,
    )
    DATABASE_MAX_OVERFLOW: int = Field(
        default=10,
        ge=0,
    )
    DATABASE_POOL_TIMEOUT: int = Field(
        default=30,
        gt=0,
    )
    DATABASE_STATEMENT_TIMEOUT_MS: int = Field(
        default=30_000,
        gt=0,
    )

    # Redis settings
    REDIS_URL: SecretStr | None = None
    REDIS_KEY_PREFIX: str = "pomo"
    REDIS_SERVICE_PREFIX: str = "api"
    REDIS_REQUIRED: bool = False

    REDIS_MAX_CONNECTIONS: int = Field(
        default=20,
        ge=1,
    )
    REDIS_CONNECT_TIMEOUT_SECONDS: float = Field(
        default=1.0,
        gt=0,
    )
    REDIS_SOCKET_TIMEOUT_SECONDS: float = Field(
        default=1.0,
        gt=0,
    )
    REDIS_HEALTHCHECK_TIMEOUT_SECONDS: float = Field(
        default=1.0,
        gt=0,
    )
    REDIS_POOL_HEALTHCHECK_INTERVAL_SECONDS: int = Field(
        default=30,
        ge=0,
    )
    REDIS_SSL_CA_CERTS: Path | None = None

    # JWT and authentication settings
    JWT_SECRET_KEY: SecretStr
    JWT_ALGORITHM: Literal["HS256"] = "HS256"
    JWT_ISSUER: str = "pomodoro-api"
    JWT_AUDIENCE: str = "pomodoro-app"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=10,
        gt=0,
    )
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(
        default=30,
        gt=0,
    )
    REFRESH_TOKEN_PEPPER: SecretStr

    # CORS, host and proxy settings
    CORS_ALLOWED_ORIGINS: list[str] = []
    TRUSTED_HOSTS: list[str] = [
        "localhost",
        "127.0.0.1",
    ]
    TRUSTED_PROXY_IPS: list[str] = []

    # Rate-limit settings
    # Rate-limit sistemini açıp kapatır.
    RATE_LIMIT_ENABLED: bool = False

    # Redis anahtarlarında kullanılan özel verileri HMAC ile gizler.
    RATE_LIMIT_KEY_SALT: SecretStr

    # Redis kesildiğinde kullanılacak worker-local bucket üst sınırıdır.
    RATE_LIMIT_LOCAL_MAX_BUCKETS: int = Field(
        default=10_000,
        ge=100,
        le=1_000_000,
    )

    # Logging and observability settings
    LOG_LEVEL: LogLevel = "INFO"
    LOG_JSON: bool = False
    LOG_COLORIZE: bool = True

    @field_validator("API_V1_PREFIX")
    @classmethod
    def validate_api_v1_prefix(
        cls,
        value: str,
    ) -> str:
        normalized_value = value.strip()

        if not normalized_value.startswith("/"):
            normalized_value = f"/{normalized_value}"

        return normalized_value.rstrip("/")

    @field_validator(
        "APP_NAME",
        "SERVICE_NAME",
        "APP_VERSION",
        "REDIS_KEY_PREFIX",
        "REDIS_SERVICE_PREFIX",
        "JWT_ISSUER",
        "JWT_AUDIENCE",
    )
    @classmethod
    def validate_required_text(
        cls,
        value: str,
    ) -> str:
        normalized_value = value.strip()

        if not normalized_value:
            raise ValueError("Value cannot be empty.")

        return normalized_value

    @field_validator(
        "REDIS_KEY_PREFIX",
        "REDIS_SERVICE_PREFIX",
    )
    @classmethod
    def validate_redis_prefix_segment(
        cls,
        value: str,
    ) -> str:
        if ":" in value:
            raise ValueError(
                "Redis prefix segments cannot contain ':'."
            )

        return value

    @field_validator("CORS_ALLOWED_ORIGINS")
    @classmethod
    def normalize_cors_origins(
        cls,
        values: list[str],
    ) -> list[str]:
        return [
            value.strip().rstrip("/")
            for value in values
            if value.strip()
        ]

    @field_validator(
        "TRUSTED_HOSTS",
        "TRUSTED_PROXY_IPS",
    )
    @classmethod
    def normalize_string_lists(
        cls,
        values: list[str],
    ) -> list[str]:
        return [
            value.strip()
            for value in values
            if value.strip()
        ]

    # Güvenilir proxy listesinde yalnız geçerli IP veya CIDR bulunmasını sağlar.
    @field_validator("TRUSTED_PROXY_IPS")
    @classmethod
    def validate_trusted_proxy_networks(
        cls,
        values: list[str],
    ) -> list[str]:
        normalized_values = [
            value.strip()
            for value in values
            if value.strip()
        ]

        for value in normalized_values:
            try:
                ip_network(value, strict=False)
            except ValueError as exc:
                raise ValueError(
                    "TRUSTED_PROXY_IPS values must be "
                    "valid IP addresses or CIDR networks."
                ) from exc

        return normalized_values

    @model_validator(mode="after")
    def validate_environment_settings(
        self,
    ) -> "Settings":
        errors: list[str] = []

        if self.REDIS_REQUIRED and not self.REDIS_URL:
            errors.append(
                "REDIS_URL is required when "
                "REDIS_REQUIRED is true."
            )

        if self.RATE_LIMIT_ENABLED and self.REDIS_URL is None:
            errors.append(
                "REDIS_URL is required when rate limiting is enabled."
            )

        if self.ENVIRONMENT != "production":
            if errors:
                raise ValueError(
                    "Invalid configuration:\n- "
                    + "\n- ".join(errors)
                )

            return self

        if self.DEBUG:
            errors.append(
                "POMODORO_DEBUG must be false in production."
            )

        jwt_secret = (
            self.JWT_SECRET_KEY.get_secret_value()
        )
        refresh_token_pepper = (
            self.REFRESH_TOKEN_PEPPER.get_secret_value()
        )

        rate_limit_key_salt = (
            self.RATE_LIMIT_KEY_SALT.get_secret_value()
        )

        if not is_strong_secret(jwt_secret):
            errors.append(
                "JWT_SECRET_KEY must contain at least "
                "32 characters and cannot use a placeholder."
            )

        if not is_strong_secret(refresh_token_pepper):
            errors.append(
                "REFRESH_TOKEN_PEPPER must contain at least "
                "32 characters and cannot use a placeholder."
            )

        if (
            self.RATE_LIMIT_ENABLED
            and not is_strong_secret(rate_limit_key_salt)
        ):
            errors.append(
                "RATE_LIMIT_KEY_SALT must contain at least "
                "32 characters and cannot use a placeholder."
            )

        if rate_limit_key_salt in {
            jwt_secret,
            refresh_token_pepper,
        }:
            errors.append(
                "RATE_LIMIT_KEY_SALT must be different from "
                "JWT_SECRET_KEY and REFRESH_TOKEN_PEPPER."
            )

        if "*" in self.CORS_ALLOWED_ORIGINS:
            errors.append(
                "Wildcard CORS origins are forbidden "
                "in production."
            )

        insecure_origins = [
            origin
            for origin in self.CORS_ALLOWED_ORIGINS
            if origin.lower().startswith("http://")
        ]

        if insecure_origins:
            errors.append(
                "Production CORS origins must use HTTPS."
            )

        if (
            not self.TRUSTED_HOSTS
            or "*" in self.TRUSTED_HOSTS
        ):
            errors.append(
                "TRUSTED_HOSTS must contain explicit hosts "
                "in production."
            )

        if self.REDIS_URL is not None:
            errors.extend(
                validate_production_redis_url(
                    self.REDIS_URL.get_secret_value()
                )
            )

        if (
            self.REDIS_SSL_CA_CERTS is not None
            and not self.REDIS_SSL_CA_CERTS.is_file()
        ):
            errors.append(
                "REDIS_SSL_CA_CERTS must point to "
                "an existing CA certificate file."
            )

        errors.extend(
            validate_production_database_url(
                self.DATABASE_URL
            )
        )

        if errors:
            raise ValueError(
                "Invalid production configuration:\n- "
                + "\n- ".join(errors)
            )

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


settings = get_settings()
