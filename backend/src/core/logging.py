from __future__ import annotations

import inspect
import logging
import sys
from types import FrameType
from typing import cast

from loguru import logger

from src.core.config import settings


_TEXT_FORMAT = (
    "<green>{time:YYYY-MM-DDTHH:mm:ss.SSS!UTC}</green> "
    "<level>{level:<8}</level> "
    "<cyan>service={extra[service]}</cyan> "
    "<cyan>env={extra[environment]}</cyan> "
    "<yellow>request_id={extra[request_id]}</yellow> "
    "<blue>{name}:{function}:{line}</blue> "
    "<level>{message}</level>"
)

_configured = False


class InterceptHandler(logging.Handler):
    """Redirect standard-library logs to Loguru."""

    def emit(self, record: logging.LogRecord) -> None:
        try:
            level: str | int = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        frame = inspect.currentframe()
        depth = 2

        while frame is not None and self._is_logging_frame(frame):
            frame = frame.f_back
            depth += 1

        logger.opt(
            depth=depth,
            exception=record.exc_info,
        ).log(
            level,
            record.getMessage(),
        )

    @staticmethod
    def _is_logging_frame(frame: FrameType) -> bool:
        logging_file = cast(str | None, logging.__file__)

        if logging_file is None:
            return False

        return frame.f_code.co_filename == logging_file


def configure_standard_logging() -> None:
    handler = InterceptHandler()

    logging.basicConfig(
        handlers=[handler],
        level=logging.NOTSET,
        force=True,
    )

    logger_names = (
        "uvicorn",
        "uvicorn.error",
        "uvicorn.access",
        "fastapi",
    )

    for logger_name in logger_names:
        standard_logger = logging.getLogger(logger_name)
        standard_logger.handlers = [handler]
        standard_logger.propagate = False


def configure_logging() -> None:
    global _configured

    if _configured:
        return

    logger.remove()

    logger.configure(
        extra={
            "service": settings.SERVICE_NAME,
            "environment": settings.ENVIRONMENT,
            "request_id": "-",
        }
    )

    logger.add(
        sys.stdout,
        level=settings.LOG_LEVEL,
        format=_TEXT_FORMAT,
        serialize=settings.LOG_JSON,
        colorize=settings.LOG_COLORIZE and not settings.LOG_JSON,
        enqueue=True,
        backtrace=settings.DEBUG,
        diagnose=False,
    )

    configure_standard_logging()

    _configured = True


# Loguru loglarını yapılandırır.
# Uvicorn ve FastAPI’nin standart logging çıktılarını Loguru’ya yönlendirir.
# Development’ta okunabilir log üretir.
# Production’da JSON log üretebilir.