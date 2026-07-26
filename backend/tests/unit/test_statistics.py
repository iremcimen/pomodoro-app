from datetime import UTC, datetime

from src.api.v1.statistics import calculate_period_starts


def test_period_starts_respect_timezone_and_monday() -> None:
    now = datetime(
        2026,
        7,
        26,
        22,
        30,
        tzinfo=UTC,
    )

    day_start, week_start = calculate_period_starts(
        now,
        180,
    )

    assert day_start == datetime(
        2026,
        7,
        26,
        21,
        tzinfo=UTC,
    )
    assert week_start == datetime(
        2026,
        7,
        26,
        21,
        tzinfo=UTC,
    )
