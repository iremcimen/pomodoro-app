import re
from typing import TypeGuard
from uuid import uuid4


REQUEST_ID_HEADER = "X-Request-ID"

_REQUEST_ID_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$"
)


def generate_request_id() -> str:
    return str(uuid4())


def is_valid_request_id(value: object) -> TypeGuard[str]:
    return (
        isinstance(value, str)
        and _REQUEST_ID_PATTERN.fullmatch(value) is not None
    )


def get_or_create_request_id(value: object) -> str:
    if not isinstance(value, str):
        return generate_request_id()

    normalized_value = value.strip()

    if is_valid_request_id(normalized_value):
        return normalized_value

    return generate_request_id()

# request ID üretme, doğrulama ve mevcut request ID’yi okuma işini yapar