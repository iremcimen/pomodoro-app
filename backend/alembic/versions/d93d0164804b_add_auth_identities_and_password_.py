"""add auth identities and password credentials

Revision ID: d93d0164804b
Revises: 35f767597c67
Create Date: 2026-07-31 15:51:43.197995

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd93d0164804b'
down_revision: Union[str, Sequence[str], None] = '35f767597c67'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""

    op.create_table(
        "auth_identities",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "provider",
            sa.String(length=32),
            nullable=False,
        ),
        sa.Column(
            "provider_subject",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "email_snapshot",
            sa.String(length=320),
            nullable=False,
        ),
        sa.Column(
            "email_verified",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column(
            "display_name",
            sa.String(length=100),
            nullable=True,
        ),
        sa.Column(
            "avatar_url",
            sa.String(length=2048),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "last_login_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=(
                "fk_auth_identities_"
                "user_id_users"
            ),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "provider",
            "provider_subject",
            name=(
                "uq_auth_identities_"
                "provider_subject"
            ),
        ),
        sa.UniqueConstraint(
            "user_id",
            "provider",
            name=(
                "uq_auth_identities_"
                "user_provider"
            ),
        ),
    )

    op.create_index(
        "ix_auth_identities_user_id",
        "auth_identities",
        ["user_id"],
        unique=False,
    )

    op.create_table(
        "password_credentials",
        sa.Column(
            "user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "password_changed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=(
                "fk_password_credentials_"
                "user_id_users"
            ),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id"),
    )

    # Mevcut email/parola kullanıcılarının
    # parola hash'lerini yeni tabloya taşır.
    op.execute(
        sa.text(
            """
            INSERT INTO password_credentials (
                user_id,
                password_hash,
                password_changed_at,
                created_at
            )
            SELECT
                id,
                password_hash,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            FROM users
            WHERE password_hash IS NOT NULL
            """
        )
    )

    # Veriler kopyalandıktan sonra eski alan kaldırılır.
    op.drop_column(
        "users",
        "password_hash",
    )


def downgrade() -> None:
    """Downgrade schema."""

    # Önce nullable oluşturulur; doğrudan
    # NOT NULL eklemek dolu users tablosunda hata verir.
    op.add_column(
        "users",
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=True,
        ),
    )

    op.execute(
        sa.text(
            """
            UPDATE users AS target_user
            SET password_hash =
                password_credentials.password_hash
            FROM password_credentials
            WHERE
                password_credentials.user_id =
                target_user.id
            """
        )
    )

    connection = op.get_bind()

    users_without_password = (
        connection.execute(
            sa.text(
                """
                SELECT COUNT(*)
                FROM users
                WHERE password_hash IS NULL
                """
            )
        ).scalar_one()
    )

    # Google-only kullanıcılara sahte parola
    # üretmeden downgrade işlemini durdurur.
    if users_without_password > 0:
        raise RuntimeError(
            "Cannot safely downgrade because "
            "Google-only users have no password."
        )

    op.alter_column(
        "users",
        "password_hash",
        existing_type=sa.String(length=255),
        nullable=False,
    )

    op.drop_table(
        "password_credentials",
    )

    op.drop_index(
        "ix_auth_identities_user_id",
        table_name="auth_identities",
    )

    op.drop_table(
        "auth_identities",
    )

