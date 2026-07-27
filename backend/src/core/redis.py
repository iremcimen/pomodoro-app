from __future__ import annotations

import asyncio
from pathlib import Path
from urllib.parse import quote

from loguru import logger
from redis.asyncio import ConnectionPool, Redis
from redis.exceptions import (
    ConnectionError as RedisConnectionError,
)
from redis.exceptions import RedisError
from redis.exceptions import TimeoutError as RedisTimeoutError

from src.core.config import Settings


_ENVIRONMENT_SEGMENTS = {
    "development": "dev",
    "test": "test",
    "staging": "staging",
    "production": "prod",
}


class RedisManager:
    def __init__(
        self,
        *,
        url: str | None,
        key_namespace: str,
        environment: str,
        service: str,
        required: bool,
        max_connections: int,
        connect_timeout_seconds: float,
        socket_timeout_seconds: float,
        healthcheck_timeout_seconds: float,
        pool_healthcheck_interval_seconds: int,
        ssl_ca_certs: Path | None = None,
    ) -> None:
        self._url = url
        self._key_namespace = key_namespace
        self._environment = environment
        self._service = service
        self._required = required
        self._max_connections = max_connections
        self._connect_timeout_seconds = (
            connect_timeout_seconds
        )
        self._socket_timeout_seconds = socket_timeout_seconds
        self._healthcheck_timeout_seconds = (
            healthcheck_timeout_seconds
        )
        self._pool_healthcheck_interval_seconds = (
            pool_healthcheck_interval_seconds
        )
        self._ssl_ca_certs = ssl_ca_certs

        self._pool: ConnectionPool | None = None
        self._client: Redis | None = None

    @classmethod
    def from_settings(
        cls,
        config: Settings,
    ) -> "RedisManager":
        redis_url = (
            config.REDIS_URL.get_secret_value()
            if config.REDIS_URL is not None
            else None
        )

        return cls(
            url=redis_url,
            key_namespace=config.REDIS_KEY_PREFIX,
            environment=config.ENVIRONMENT,
            service=config.REDIS_SERVICE_PREFIX,
            required=config.REDIS_REQUIRED,
            max_connections=config.REDIS_MAX_CONNECTIONS,
            connect_timeout_seconds=(
                config.REDIS_CONNECT_TIMEOUT_SECONDS
            ),
            socket_timeout_seconds=(
                config.REDIS_SOCKET_TIMEOUT_SECONDS
            ),
            healthcheck_timeout_seconds=(
                config.REDIS_HEALTHCHECK_TIMEOUT_SECONDS
            ),
            pool_healthcheck_interval_seconds=(
                config.REDIS_POOL_HEALTHCHECK_INTERVAL_SECONDS
            ),
            ssl_ca_certs=config.REDIS_SSL_CA_CERTS,
        )

    @property
    def configured(self) -> bool:
        return self._url is not None

    @property
    def client(self) -> Redis:
        if self._client is None:
            raise RuntimeError(
                "Redis client has not been initialized."
            )

        return self._client

    @property
    def pool(self) -> ConnectionPool:
        if self._pool is None:
            raise RuntimeError(
                "Redis connection pool has not been initialized."
            )

        return self._pool

    @property
    def key_prefix(self) -> str:
        environment_segment = _ENVIRONMENT_SEGMENTS[
            self._environment
        ]

        return (
            f"{self._key_namespace}:"
            f"{environment_segment}:"
            f"{self._service}"
        )

    def key(
        self,
        *parts: str | int,
    ) -> str:
        if not parts:
            raise ValueError(
                "At least one Redis key segment is required."
            )

        encoded_parts: list[str] = []

        for part in parts:
            value = str(part).strip()

            if not value:
                raise ValueError(
                    "Redis key segments cannot be empty."
                )

            encoded_parts.append(
                quote(value, safe="._-")
            )

        return ":".join(
            [self.key_prefix, *encoded_parts]
        )

    async def open(self) -> None:
        if self._pool is not None:
            return

        if self._url is None:
            if self._required:
                raise RuntimeError(
                    "Redis is required but REDIS_URL is missing."
                )

            logger.info("redis_disabled")
            return

        connection_options: dict[str, object] = {}

        if self._url.startswith("rediss://"):
            connection_options["ssl_cert_reqs"] = "required"

            if self._ssl_ca_certs is not None:
                connection_options["ssl_ca_certs"] = str(
                    self._ssl_ca_certs
                )

        self._pool = ConnectionPool.from_url(
            self._url,
            decode_responses=True,
            max_connections=self._max_connections,
            socket_connect_timeout=(
                self._connect_timeout_seconds
            ),
            socket_timeout=self._socket_timeout_seconds,
            socket_keepalive=True,
            retry_on_timeout=False,
            health_check_interval=(
                self._pool_healthcheck_interval_seconds
            ),
            client_name=(
                f"{self._service}-{self._environment}"
            ),
            **connection_options,
        )
        self._client = Redis(
            connection_pool=self._pool,
        )

        try:
            await self.ping(operation="startup")
        except (RedisError, TimeoutError):
            if self._required:
                raise

            logger.warning(
                "redis_startup_failed_continuing_fail_open"
            )

    async def ping(
        self,
        *,
        operation: str,
    ) -> bool:
        if self._client is None:
            raise RedisConnectionError(
                "Redis client is not available."
            )

        try:
            async with asyncio.timeout(
                self._healthcheck_timeout_seconds
            ):
                response = await self._client.ping()
        except (RedisTimeoutError, TimeoutError) as exc:
            logger.bind(
                operation=operation,
                exception_type=type(exc).__name__,
            ).warning(
                "redis_operation_timeout"
            )
            raise
        except RedisError as exc:
            logger.bind(
                operation=operation,
                exception_type=type(exc).__name__,
            ).error(
                "redis_connection_failed"
            )
            raise

        return bool(response)

    async def close(self) -> None:
        client = self._client
        pool = self._pool

        self._client = None
        self._pool = None

        if client is not None:
            try:
                await client.aclose()
            except RedisError as exc:
                logger.bind(
                    exception_type=type(exc).__name__,
                ).warning(
                    "redis_client_close_failed"
                )

        if pool is not None:
            try:
                await pool.aclose()
            except RedisError as exc:
                logger.bind(
                    exception_type=type(exc).__name__,
                ).warning(
                    "redis_pool_close_failed"
                )

            logger.info("redis_pool_closed")

# Bu dosya bağlantı havuzunu, timeout’ları, startup ping’ini, kapanışı ve key üretimini yönetecek.