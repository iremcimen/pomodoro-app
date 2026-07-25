from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Path,
    Query,
    Response,
    status,
)

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.models.tasks import Task
from src.repositories.tasks import TaskRepository
from src.schemas.tasks import (
    CreateTaskRequest,
    TaskResponse,
    UpdateTaskRequest,
)
from src.services.tasks import TaskService


# Task endpointlerini /tasks adresi altında toplar.
router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
)


# Listeleme limitinin 1 ile 100 arasında olmasını sağlar.
TaskLimit = Annotated[
    int,
    Query(
        ge=1,
        le=100,
    ),
]


# URL'den alınan Task kimliğinin pozitif bir sayı olmasını sağlar.
TaskId = Annotated[
    int,
    Path(
        gt=0,
    ),
]


# Her HTTP isteği için Task service ve repository nesnelerini oluşturur.
def get_task_service(
    db: DbSession,
) -> TaskService:
    return TaskService(
        task_repository=TaskRepository(db),
    )


# TaskService nesnesinin FastAPI tarafından otomatik oluşturulmasını sağlar.
TaskServiceDependency = Annotated[
    TaskService,
    Depends(get_task_service),
]


# Giriş yapmış kullanıcıya ait yeni bir Task oluşturur.
@router.post(
    "",
    response_model=TaskResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a task",
)
def create_task(
    payload: CreateTaskRequest,
    current_user: CurrentUser,
    task_service: TaskServiceDependency,
) -> Task:
    return task_service.create_task(
        current_user,
        payload,
    )


# Giriş yapmış kullanıcının Task listesini filtre ve limit ile döndürür.
@router.get(
    "",
    response_model=list[TaskResponse],
    summary="List the current user's tasks",
)
def list_tasks(
    current_user: CurrentUser,
    task_service: TaskServiceDependency,
    is_completed: bool | None = None,
    limit: TaskLimit = 20,
) -> list[Task]:
    return task_service.list_tasks(
        current_user,
        is_completed=is_completed,
        limit=limit,
    )


# Giriş yapmış kullanıcıya ait tek bir Task'ı döndürür.
@router.get(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Get a task",
)
def get_task(
    task_id: TaskId,
    current_user: CurrentUser,
    task_service: TaskServiceDependency,
) -> Task:
    return task_service.get_task(
        current_user,
        task_id,
    )


# Giriş yapmış kullanıcıya ait Task'ın gönderilen alanlarını günceller.
@router.patch(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Update a task",
)
def update_task(
    task_id: TaskId,
    payload: UpdateTaskRequest,
    current_user: CurrentUser,
    task_service: TaskServiceDependency,
) -> Task:
    return task_service.update_task(
        current_user,
        task_id,
        payload,
    )


# Giriş yapmış kullanıcıya ait Task'ı siler ve boş cevap döndürür.
@router.delete(
    "/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a task",
)
def delete_task(
    task_id: TaskId,
    current_user: CurrentUser,
    task_service: TaskServiceDependency,
) -> Response:
    task_service.delete_task(
        current_user,
        task_id,
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )
