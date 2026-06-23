from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0002_user_survey_profile"
down_revision = "0001_auth_products_marketplace_links"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "has_completed_survey",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.add_column("users", sa.Column("skin_profile_json", sa.JSON(), nullable=True))
    op.add_column(
        "users",
        sa.Column("survey_completed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "survey_completed_at")
    op.drop_column("users", "skin_profile_json")
    op.drop_column("users", "has_completed_survey")
