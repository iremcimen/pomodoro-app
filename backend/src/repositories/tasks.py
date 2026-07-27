from collections.abc import Mapping

from sqlalchemy import (
    select,
    update as sql_update,
)
from sqlalchemy.orm import Session

from src.models.tasks import Task


# Task kayıtlarıyla ilgili bütün veritabanı işlemlerini yönetir.
class TaskRepository:
    # Genel PATCH işleminde değiştirilebilecek alanları sınırlar.
    _UPDATABLE_FIELDS = frozenset(
        {
            "title",
            "description",
            "estimated_pomodoros",
            "is_completed",
            "completed_at",
        }
    )

    # Repository'nin kullanacağı veritabanı oturumunu kaydeder.
    def __init__(
        self,
        db: Session,
    ) -> None:
        self._db = db

    # Verilen bilgileri kullanarak kullanıcıya ait yeni bir Task oluşturur.
    def create(
        self,
        *,
        user_id: int,
        title: str,
        description: str | None,
        estimated_pomodoros: int,
    ) -> Task:
        task = Task(
            user_id=user_id,
            title=title,
            description=description,
            estimated_pomodoros=(
                estimated_pomodoros
            ),
        )

        self._db.add(task)
        self._db.flush()
        self._db.refresh(task)

        return task

    # Task'ı yalnızca belirtilen kullanıcıya aitse bulup döndürür.
    def get_by_id_for_user(
        self,
        *,
        task_id: int,
        user_id: int,
    ) -> Task | None:
        statement = select(Task).where(
            Task.id == task_id,
            Task.user_id == user_id,
        )

        return self._db.execute(
            statement,
        ).scalar_one_or_none()

    # Kullanıcının Task listesini filtre ve limit uygulayarak döndürür.
    def list_for_user(
        self,
        *,
        user_id: int,
        is_completed: bool | None,
        limit: int,
    ) -> list[Task]:
        statement = select(Task).where(
            Task.user_id == user_id,
        )

        if is_completed is not None:
            statement = statement.where(
                Task.is_completed
                == is_completed,
            )

        statement = (
            statement
            .order_by(
                Task.created_at.desc(),
                Task.id.desc(),
            )
            .limit(limit)
        )

        return list(
            self._db.execute(
                statement,
            ).scalars().all()
        )

    # Task'ın yalnızca izin verilen alanlarını yeni değerlerle günceller.
    def update(
        self,
        task: Task,
        values: Mapping[str, object],
    ) -> Task:
        unsupported_fields = (
            values.keys()
            - self._UPDATABLE_FIELDS
        )

        if unsupported_fields:
            field_names = ", ".join(
                sorted(unsupported_fields),
            )

            raise ValueError(
                "Unsupported task fields: "
                f"{field_names}"
            )

        for field_name, value in values.items():
            setattr(
                task,
                field_name,
                value,
            )

        self._db.flush()
        self._db.refresh(task)

        return task

    # Task'ın tamamlanan Pomodoro sayısını veritabanında güvenli şekilde bir artırır.
    def increment_completed_pomodoros(
        self,
        *,
        task_id: int,
        user_id: int,
    ) -> Task | None:
        statement = (
            sql_update(Task)
            .where(
                Task.id == task_id,
                Task.user_id == user_id,
            )
            .values(
                completed_pomodoros=(
                    Task.completed_pomodoros + 1
                ),
            )
            .returning(Task)
        )

        task = self._db.execute(
            statement,
        ).scalar_one_or_none()

        if task is not None:
            self._db.refresh(task)

        return task

    # Verilen Task kaydını veritabanından siler.
    def delete(
        self,
        task: Task,
    ) -> None:
        self._db.delete(task)
        self._db.flush()