from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Query

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.repositories.focus_sessions import FocusSessionRepository
from src.repositories.tasks import TaskRepository
from src.schemas.statistics import (
    StatisticsSummaryResponse,
    TaskProgressResponse,
)


router = APIRouter(
    prefix="/statistics",
    tags=["Statistics"],
)

TimezoneOffset = Annotated[
    int,
    Query(ge=-840, le=840),
]


def calculate_period_starts(
    now: datetime,
    timezone_offset_minutes: int,
) -> tuple[datetime, datetime]:
    offset = timedelta(
        minutes=timezone_offset_minutes,
    )
    local_now = now.astimezone(UTC) + offset
    local_day_start = local_now.replace(
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )
    day_start = local_day_start - offset
    week_start = local_day_start - timedelta(days=local_day_start.weekday()) - offset
    return day_start, week_start


@router.get(
    "/summary",
    response_model=StatisticsSummaryResponse,
    summary="Get focus statistics summary",
)
def get_statistics_summary(
    current_user: CurrentUser,
    db: DbSession,
    timezone_offset_minutes: TimezoneOffset = 0,
) -> StatisticsSummaryResponse:
    day_start, week_start = calculate_period_starts(
        datetime.now(UTC),
        timezone_offset_minutes,
    )

    sessions = FocusSessionRepository(db)
    daily_seconds, daily_count = sessions.completed_focus_summary(
        user_id=current_user.id,
        since=day_start,
    )
    weekly_seconds, weekly_count = sessions.completed_focus_summary(
        user_id=current_user.id,
        since=week_start,
    )
    tasks = TaskRepository(db).list_for_user(
        user_id=current_user.id,
        is_completed=None,
        limit=100,
    )

    return StatisticsSummaryResponse(
        daily_focus_seconds=daily_seconds,
        weekly_focus_seconds=weekly_seconds,
        daily_completed_pomodoros=daily_count,
        weekly_completed_pomodoros=weekly_count,
        task_progress=[
            TaskProgressResponse(
                task_id=task.id,
                title=task.title,
                estimated_pomodoros=(task.estimated_pomodoros),
                completed_pomodoros=(task.completed_pomodoros),
                is_completed=task.is_completed,
            )
            for task in tasks
        ],
    )
