from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError


_password_hasher = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """Return an Argon2 hash for a plaintext password."""
    return _password_hasher.hash(password)


def verify_password(
    password: str,
    password_hash: str,
) -> bool:
    """Return whether a plaintext password matches its stored hash."""
    try:
        return _password_hasher.verify(
            password,
            password_hash,
        )
    except UnknownHashError:
        return False