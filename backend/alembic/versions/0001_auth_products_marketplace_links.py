from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0001_auth_products_marketplace_links"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)

    op.create_table(
        "products",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.String(length=255), nullable=False),
        sa.Column("brand", sa.String(length=255), nullable=False),
        sa.Column("name", sa.String(length=512), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_products_id"), "products", ["id"], unique=False)
    op.create_index(op.f("ix_products_product_id"), "products", ["product_id"], unique=True)

    op.create_table(
        "marketplaces",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_marketplaces_code"), "marketplaces", ["code"], unique=True)
    op.create_index(op.f("ix_marketplaces_id"), "marketplaces", ["id"], unique=False)

    op.create_table(
        "product_marketplace_links",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("marketplace_id", sa.Integer(), nullable=False),
        sa.Column("url", sa.String(length=2048), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["marketplace_id"], ["marketplaces.id"]),
        sa.ForeignKeyConstraint(["product_id"], ["products.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("product_id", "marketplace_id", "url", name="uq_product_marketplace_url"),
    )
    op.create_index(
        op.f("ix_product_marketplace_links_id"),
        "product_marketplace_links",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_product_marketplace_links_marketplace_id"),
        "product_marketplace_links",
        ["marketplace_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_product_marketplace_links_product_id"),
        "product_marketplace_links",
        ["product_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_product_marketplace_links_product_id"),
        table_name="product_marketplace_links",
    )
    op.drop_index(
        op.f("ix_product_marketplace_links_marketplace_id"),
        table_name="product_marketplace_links",
    )
    op.drop_index(
        op.f("ix_product_marketplace_links_id"),
        table_name="product_marketplace_links",
    )
    op.drop_table("product_marketplace_links")
    op.drop_index(op.f("ix_marketplaces_id"), table_name="marketplaces")
    op.drop_index(op.f("ix_marketplaces_code"), table_name="marketplaces")
    op.drop_table("marketplaces")
    op.drop_index(op.f("ix_products_product_id"), table_name="products")
    op.drop_index(op.f("ix_products_id"), table_name="products")
    op.drop_table("products")
    op.drop_index(op.f("ix_users_id"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
