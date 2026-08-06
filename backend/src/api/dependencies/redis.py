from typing import Annotated

from fastapi import Depends, Request

from src.core.redis import RedisManager


def get_redis_manager(
    request: Request,
) -> RedisManager:
    redis_manager = getattr(
        request.app.state,
        "redis_manager",
        None,
    )

    if not isinstance(redis_manager, RedisManager):
        raise RuntimeError(
            "Redis manager is not initialized."
        )

    return redis_manager


RedisDependency = Annotated[
    RedisManager,
    Depends(get_redis_manager),
]

# Bu yeni dependency, ileride rate-limit middleware veya endpoint’lerin mevcut manager’a erişmesini sağlar.