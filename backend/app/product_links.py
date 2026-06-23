from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .db_models import Product, ProductMarketplaceLink


def load_primary_product_links(db: Session, product_ids: list[str]) -> dict[str, str]:
    if not product_ids:
        return {}

    try:
        statement = (
            select(Product.product_id, ProductMarketplaceLink.url)
            .join(ProductMarketplaceLink, ProductMarketplaceLink.product_id == Product.id)
            .where(Product.product_id.in_(product_ids))
            .where(ProductMarketplaceLink.is_primary.is_(True))
            .order_by(ProductMarketplaceLink.id)
        )
        rows = db.execute(statement).all()
    except SQLAlchemyError:
        return {}

    links: dict[str, str] = {}
    for product_id, url in rows:
        links.setdefault(product_id, url)
    return links
