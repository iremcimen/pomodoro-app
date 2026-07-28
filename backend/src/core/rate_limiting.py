from __future__ import annotations

import asyncio
import hashlib
import hmac
import math
import secrets
import time
from collections import OrderedDict, deque
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from enum import StrEnum
from http import HTTPStatus
from typing import Any

from loguru import logger
from redis.exceptions import (
    ConnectionError as RedisConnectionError,
)
from redis.exceptions import RedisError
from starlette.datastructures import MutableHeaders

from src.core.exceptions import (
    AppException,
    RedisUnavailableException,
)
from src.core.redis import RedisManager


# Bütün kuralları tek Redis işlemi içinde atomik kontrol eder.
_SLIDING_WINDOW_LUA = """
local rule_count = #KEYS
local member = ARGV[1]
local redis_time = redis.call("TIME")
local now_ms = (
    tonumber(redis_time[1]) * 1000
    + math.floor(tonumber(redis_time[2]) / 1000)
)

local limits = {}
local windows = {}
local counts = {}
local resets = {}
local blocked = {}
local any_blocked = false
local argument_index = 2

for index = 1, rule_count do
    local limit = tonumber(ARGV[argument_index])
    local window_ms = tonumber(ARGV[argument_index + 1])
    argument_index = argument_index + 2

    limits[index] = limit
    windows[index] = window_ms

    redis.call(
        "ZREMRANGEBYSCORE",
        KEYS[index],
        "-inf",
        now_ms - window_ms
    )

    local count = redis.call("ZCARD", KEYS[index])
    counts[index] = count

    local oldest = redis.call(
        "ZRANGE",
        KEYS[index],
        0,
        0,
        "WITHSCORES"
    )

    local reset_ms = window_ms

    if #oldest > 0 then
        reset_ms = math.max(
            1,
            math.floor(
                tonumber(oldest[2])
                + window_ms
                - now_ms
            )
        )
    end

    resets[index] = reset_ms

    if count >= limit then
        blocked[index] = 1
        any_blocked = true
    else
        blocked[index] = 0
    end
end

if not any_blocked then
    for index = 1, rule_count do
        redis.call(
            "ZADD",
            KEYS[index],
            now_ms,
            member
        )

        redis.call(
            "PEXPIRE",
            KEYS[index],
            windows[index] + 1000
        )

        counts[index] = counts[index] + 1

        if counts[index] == 1 then
            resets[index] = windows[index]
        end
    end
else
    for index = 1, rule_count do
        if counts[index] > 0 then
            redis.call(
                "PEXPIRE",
                KEYS[index],
                windows[index] + 1000
            )
        end
    end
end

local result = {}

if any_blocked then
    table.insert(result, 0)
else
    table.insert(result, 1)
end

for index = 1, rule_count do
    local remaining = math.max(
        0,
        limits[index] - counts[index]
    )

    table.insert(result, limits[index])
    table.insert(result, remaining)
    table.insert(result, resets[index])
    table.insert(result, blocked[index])
end

return result
"""


# Redis kesildiğinde uygulanabilecek endpoint davranışlarını tanımlar.
class FailureMode(StrEnum):
    OPEN = "open"
    CLOSED = "closed"
    LOCAL = "local"


# Tek bir rate-limit kuralının limit ve pencere bilgisini taşır.
@dataclass(frozen=True, slots=True)
class RateLimitRule:
    name: str
    limit: int
    window_seconds: int

    # Geçersiz politika değerlerinin uygulama başlarken fark edilmesini sağlar.
    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError(
                "Rate-limit rule name cannot be empty."
            )

        if self.limit <= 0:
            raise ValueError(
                "Rate-limit rule limit must be positive."
            )

        if self.window_seconds <= 0:
            raise ValueError(
                "Rate-limit window must be positive."
            )


# Bir kuralı kullanıcı, IP veya token gibi bir özneyle eşleştirir.
@dataclass(frozen=True, slots=True)
class RateLimitTarget:
    rule: RateLimitRule
    subject: str


# Rate-limit kontrolünün istemciye yansıtılacak sonucunu taşır.
@dataclass(frozen=True, slots=True)
class RateLimitDecision:
    allowed: bool
    limit: int
    remaining: int
    reset_after_seconds: int
    rule_name: str
    source: str


# 429 cevabını standart hata formatı ve header'larla üretir.
class RateLimitExceededException(AppException):
    status_code = HTTPStatus.TOO_MANY_REQUESTS.value
    code = "RATE_LIMITED"
    message = "Too many requests."
    log_level = "WARNING"

    # Tetiklenen politikanın adını yalnız güvenli log context'ine koyar.
    def __init__(
        self,
        decision: RateLimitDecision,
    ) -> None:
        retry_after = max(
            1,
            decision.reset_after_seconds,
        )

        super().__init__(
            headers={
                "Retry-After": str(retry_after),
                "RateLimit-Limit": str(decision.limit),
                "RateLimit-Remaining": "0",
                "RateLimit-Reset": str(retry_after),
            },
            safe_context={
                "policy": decision.rule_name,
                "source": decision.source,
            },
        )


# Başarılı cevaplara güvenli rate-limit header'larını ekler.
def apply_rate_limit_headers(
    headers: MutableHeaders | dict[str, str],
    decision: RateLimitDecision | None,
) -> None:
    if decision is None:
        return

    headers["RateLimit-Limit"] = str(
        decision.limit
    )
    headers["RateLimit-Remaining"] = str(
        decision.remaining
    )
    headers["RateLimit-Reset"] = str(
        max(1, decision.reset_after_seconds)
    )


# Redis yokken worker başına geçici sliding-window koruması sağlar.
class LocalSlidingWindowLimiter:
    def __init__(
        self,
        *,
        max_buckets: int,
    ) -> None:
        self._max_buckets = max_buckets
        self._buckets: OrderedDict[
            str,
            deque[float],
        ] = OrderedDict()
        self._lock = asyncio.Lock()

    # Süresi geçmiş event'leri local bucket'tan kaldırır.
    def _trim_bucket(
        self,
        bucket: deque[float],
        *,
        cutoff: float,
    ) -> None:
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()

    # Local bellekteki kuralları tek lock altında atomik kontrol eder.
    async def check(
        self,
        *,
        keys: Sequence[str],
        targets: Sequence[RateLimitTarget],
    ) -> RateLimitDecision:
        now = time.monotonic()

        async with self._lock:
            rows: list[
                tuple[RateLimitTarget, int, int, bool]
            ] = []

            for key, target in zip(
                keys,
                targets,
                strict=True,
            ):
                bucket = self._buckets.get(key)

                if bucket is None:
                    bucket = deque()
                    self._buckets[key] = bucket

                self._buckets.move_to_end(key)

                self._trim_bucket(
                    bucket,
                    cutoff=(
                        now
                        - target.rule.window_seconds
                    ),
                )

                blocked = (
                    len(bucket) >= target.rule.limit
                )

                if bucket:
                    reset_after = max(
                        1,
                        math.ceil(
                            bucket[0]
                            + target.rule.window_seconds
                            - now
                        ),
                    )
                else:
                    reset_after = (
                        target.rule.window_seconds
                    )

                rows.append(
                    (
                        target,
                        len(bucket),
                        reset_after,
                        blocked,
                    )
                )

            any_blocked = any(
                row[3]
                for row in rows
            )

            if not any_blocked:
                for key in keys:
                    self._buckets[key].append(now)

                rows = [
                    (
                        target,
                        count + 1,
                        reset_after,
                        blocked,
                    )
                    for (
                        target,
                        count,
                        reset_after,
                        blocked,
                    ) in rows
                ]

            while (
                len(self._buckets)
                > self._max_buckets
            ):
                self._buckets.popitem(last=False)

            return _select_decision(
                rows=rows,
                allowed=not any_blocked,
                source="local",
            )

    # Başarılı login sonrasında ilgili local hesabın sayacını temizler.
    async def clear(
        self,
        keys: Iterable[str],
    ) -> None:
        async with self._lock:
            for key in keys:
                self._buckets.pop(key, None)


# Birden fazla kural sonucundan header'da gösterilecek en baskın olanı seçer.
def _select_decision(
    *,
    rows: Sequence[
        tuple[RateLimitTarget, int, int, bool]
    ],
    allowed: bool,
    source: str,
) -> RateLimitDecision:
    if allowed:
        selected = min(
            rows,
            key=lambda row: (
                (
                    row[0].rule.limit - row[1]
                )
                / row[0].rule.limit,
                row[2],
            ),
        )
    else:
        blocked_rows = [
            row
            for row in rows
            if row[3]
        ]

        selected = max(
            blocked_rows,
            key=lambda row: row[2],
        )

    target, count, reset_after, _ = selected

    return RateLimitDecision(
        allowed=allowed,
        limit=target.rule.limit,
        remaining=max(
            0,
            target.rule.limit - count,
        ),
        reset_after_seconds=max(
            1,
            reset_after,
        ),
        rule_name=target.rule.name,
        source=source,
    )


# Redis Lua script'i, anahtar gizleme ve kesinti davranışını yönetir.
class RateLimiter:
    def __init__(
        self,
        *,
        redis_manager: RedisManager,
        enabled: bool,
        key_salt: str,
        local_max_buckets: int,
    ) -> None:
        if not key_salt:
            raise ValueError(
                "Rate-limit key salt cannot be empty."
            )

        self._redis = redis_manager
        self._enabled = enabled
        self._key_salt = key_salt.encode("utf-8")
        self._local = LocalSlidingWindowLimiter(
            max_buckets=local_max_buckets,
        )
        self._script: Any | None = None

        if self._redis.configured:
            self._script = (
                self._redis.client.register_script(
                    _SLIDING_WINDOW_LUA
                )
            )

    # Ham özneyi Redis anahtarında kullanılamayan HMAC-SHA-256 değerine çevirir.
    def fingerprint(
        self,
        subject: str,
    ) -> str:
        normalized_subject = subject.strip()

        if not normalized_subject:
            raise ValueError(
                "Rate-limit subject cannot be empty."
            )

        return hmac.new(
            key=self._key_salt,
            msg=normalized_subject.encode("utf-8"),
            digestmod=hashlib.sha256,
        ).hexdigest()

    # Bir target için gizli ve namespace'li Redis anahtarı üretir.
    def _key_for_target(
        self,
        target: RateLimitTarget,
    ) -> str:
        return self._redis.key(
            "rate-limit",
            target.rule.name,
            self.fingerprint(target.subject),
        )

    # Redis Lua sonucunu uygulama kararına dönüştürür.
    def _parse_redis_result(
        self,
        *,
        raw_result: object,
        targets: Sequence[RateLimitTarget],
    ) -> RateLimitDecision:
        if not isinstance(raw_result, list):
            raise RedisError(
                "Invalid rate-limit script result."
            )

        values = [
            int(value)
            for value in raw_result
        ]

        expected_length = 1 + (len(targets) * 4)

        if len(values) != expected_length:
            raise RedisError(
                "Unexpected rate-limit script result length."
            )

        allowed = values[0] == 1
        rows: list[
            tuple[RateLimitTarget, int, int, bool]
        ] = []

        offset = 1

        for target in targets:
            limit = values[offset]
            remaining = values[offset + 1]
            reset_ms = values[offset + 2]
            blocked = values[offset + 3] == 1
            offset += 4

            count = max(0, limit - remaining)

            rows.append(
                (
                    target,
                    count,
                    max(1, math.ceil(reset_ms / 1000)),
                    blocked,
                )
            )

        return _select_decision(
            rows=rows,
            allowed=allowed,
            source="redis",
        )

    # Redis kesintisinde endpoint'in OPEN, CLOSED veya LOCAL kararını uygular.
    async def _handle_redis_failure(
        self,
        *,
        keys: Sequence[str],
        targets: Sequence[RateLimitTarget],
        failure_mode: FailureMode,
        exception: Exception,
    ) -> RateLimitDecision | None:
        logger.bind(
            failure_mode=failure_mode.value,
            rule_count=len(targets),
            exception_type=type(exception).__name__,
        ).warning(
            "rate_limit_redis_unavailable"
        )

        if failure_mode is FailureMode.OPEN:
            return None

        if failure_mode is FailureMode.CLOSED:
            raise RedisUnavailableException() from exception

        return await self._local.check(
            keys=keys,
            targets=targets,
        )

    # Bütün target'ları tek Lua çağrısında kontrol eder.
    async def check(
        self,
        targets: Sequence[RateLimitTarget],
        *,
        failure_mode: FailureMode,
    ) -> RateLimitDecision | None:
        if not self._enabled:
            return None

        if not targets:
            raise ValueError(
                "At least one rate-limit target is required."
            )

        keys = [
            self._key_for_target(target)
            for target in targets
        ]

        if self._script is None:
            return await self._handle_redis_failure(
                keys=keys,
                targets=targets,
                failure_mode=failure_mode,
                exception=RedisConnectionError(
                    "Redis is not configured."
                ),
            )

        arguments: list[str | int] = [
            secrets.token_urlsafe(18)
        ]

        for target in targets:
            arguments.extend(
                [
                    target.rule.limit,
                    target.rule.window_seconds * 1000,
                ]
            )

        try:
            raw_result = await self._script(
                keys=keys,
                args=arguments,
                client=self._redis.client,
            )
        except (
            RedisError,
            TimeoutError,
            RuntimeError,
        ) as exc:
            return await self._handle_redis_failure(
                keys=keys,
                targets=targets,
                failure_mode=failure_mode,
                exception=exc,
            )

        return self._parse_redis_result(
            raw_result=raw_result,
            targets=targets,
        )

    # Kontrol sonucu izin vermiyorsa standart 429 exception'ı üretir.
    async def enforce(
        self,
        targets: Sequence[RateLimitTarget],
        *,
        failure_mode: FailureMode,
    ) -> RateLimitDecision | None:
        decision = await self.check(
            targets,
            failure_mode=failure_mode,
        )

        if (
            decision is not None
            and not decision.allowed
        ):
            raise RateLimitExceededException(
                decision
            )

        return decision

    # Başarılı login sonrası seçilen hesabın Redis ve local sayacını temizler.
    async def clear(
        self,
        targets: Sequence[RateLimitTarget],
    ) -> None:
        if not targets:
            return

        keys = [
            self._key_for_target(target)
            for target in targets
        ]

        await self._local.clear(keys)

        if not self._enabled or not self._redis.configured:
            return

        try:
            await self._redis.client.delete(*keys)
        except (
            RedisError,
            TimeoutError,
            RuntimeError,
        ) as exc:
            logger.bind(
                rule_count=len(targets),
                exception_type=type(exc).__name__,
            ).warning(
                "rate_limit_clear_failed"
            )
