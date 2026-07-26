from pydantic import BaseModel, ConfigDict, Field


class TaskProgressResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    task_id: int = Field(gt=0)
    title: str
    estimated_pomodoros: int = Field(ge=0)
    completed_pomodoros: int = Field(ge=0)
    is_completed: bool


class StatisticsSummaryResponse(BaseModel):
    model_config = ConfigDict(frozen=True)

    daily_focus_seconds: int = Field(ge=0)
    weekly_focus_seconds: int = Field(ge=0)
    daily_completed_pomodoros: int = Field(ge=0)
    weekly_completed_pomodoros: int = Field(ge=0)
    task_progress: list[TaskProgressResponse]
