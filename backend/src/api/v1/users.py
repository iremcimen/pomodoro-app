from typing import Annotated

from fastapi import APIRouter, Depends

from src.api.dependencies.auth import CurrentUser
from src.api.dependencies.database import DbSession
from src.models.users import User
from src.repositories.users import UserRepository
from src.schemas.users import (
    CurrentUserResponse,
    UpdateCurrentUserRequest,
)
from src.services.users import UserService


router = APIRouter(
    prefix="/users",
    tags=["Users"],
)


def get_user_service(
    db: DbSession,
) -> UserService:
    return UserService(
        user_repository=UserRepository(db),
    )


UserServiceDependency = Annotated[
    UserService,
    Depends(get_user_service),
]


@router.get(
    "/me",
    response_model=CurrentUserResponse,
    summary="Get the current user",
)
def get_me(
    current_user: CurrentUser,
) -> User:
    return current_user


@router.patch(
    "/me",
    response_model=CurrentUserResponse,
    summary="Update the current user",
)
def update_me(
    payload: UpdateCurrentUserRequest,
    current_user: CurrentUser,
    user_service: UserServiceDependency,
) -> User:
    return user_service.update_current_user(
        current_user,
        payload,
    )