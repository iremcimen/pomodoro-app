from src.core.exceptions import (
    UsernameAlreadyExistsException,
)
from src.models.users import User
from src.repositories.users import UserRepository
from src.schemas.users import (
    UpdateCurrentUserRequest,
)


class UserService:
    def __init__(
        self,
        user_repository: UserRepository,
    ) -> None:
        self._users = user_repository

    def update_current_user(
        self,
        current_user: User,
        request: UpdateCurrentUserRequest,
    ) -> User:
        username = current_user.username
        full_name = current_user.full_name

        if request.username is not None:
            username = request.username

            if (
                username != current_user.username
                and self._users.exists_by_username(
                    username,
                )
            ):
                raise UsernameAlreadyExistsException()

        if "full_name" in request.model_fields_set:
            full_name = request.full_name

        return self._users.update_profile(
            current_user,
            username=username,
            full_name=full_name,
        )
