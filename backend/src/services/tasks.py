from datetime import datetime, timezone

from src.core.exceptions import (
    ResourceNotFoundException,
)
from src.models.tasks import Task
from src.models.users import User
from src.repositories.tasks import TaskRepository
from src.schemas.tasks import (
    CreateTaskRequest,
    UpdateTaskRequest,
)


# Task işlemlerindeki iş kurallarını yönetir.
class TaskService:
    # Service'in kullanacağı Task repository'sini kaydeder.
    def __init__(
        self,
        task_repository: TaskRepository,
    ) -> None:
        self._tasks = task_repository

    # Task'ı yalnızca belirtilen kullanıcıya aitse bulur, bulamazsa 404 hatası verir.
    def _get_task_for_user(
        self,
        *,
        task_id: int,
        user_id: int,
    ) -> Task:
        task = self._tasks.get_by_id_for_user(
            task_id=task_id,
            user_id=user_id,
        )

        if task is None:
            raise ResourceNotFoundException(
                "Task"
            )

        return task

    # Giriş yapmış kullanıcıya ait yeni bir Task oluşturur.
    def create_task(
        self,
        current_user: User,
        request: CreateTaskRequest,
    ) -> Task:
        return self._tasks.create(
            user_id=current_user.id,
            title=request.title,
            description=request.description,
            estimated_pomodoros=(
                request.estimated_pomodoros
            ),
        )

    # Giriş yapmış kullanıcının Task listesini filtre ve limit ile getirir.
    def list_tasks(
        self,
        current_user: User,
        *,
        is_completed: bool | None,
        limit: int,
    ) -> list[Task]:
        return self._tasks.list_for_user(
            user_id=current_user.id,
            is_completed=is_completed,
            limit=limit,
        )

    # Giriş yapmış kullanıcıya ait tek bir Task'ı getirir.
    def get_task(
        self,
        current_user: User,
        task_id: int,
    ) -> Task:
        return self._get_task_for_user(
            task_id=task_id,
            user_id=current_user.id,
        )

    # Kullanıcının Task'ını günceller ve tamamlanma zamanını otomatik yönetir.
    def update_task(
        self,
        current_user: User,
        task_id: int,
        request: UpdateTaskRequest,
    ) -> Task:
        task = self._get_task_for_user(
            task_id=task_id,
            user_id=current_user.id,
        )

        values = request.model_dump(
            exclude_unset=True,
        )

        if "is_completed" in values:
            requested_state = values[
                "is_completed"
            ]

            if requested_state != task.is_completed:
                values["completed_at"] = (
                    datetime.now(timezone.utc)
                    if requested_state
                    else None
                )

        return self._tasks.update(
            task,
            values,
        )

    # Kullanıcının Task'ını sahiplik kontrolünden sonra siler.
    def delete_task(
        self,
        current_user: User,
        task_id: int,
    ) -> None:
        task = self._get_task_for_user(
            task_id=task_id,
            user_id=current_user.id,
        )

        self._tasks.delete(task)
