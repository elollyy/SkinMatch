"""Import product links from Книга1.csv into the database."""

from __future__ import annotations

import csv
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.app.database import SessionLocal
from backend.app.db_models import Marketplace, Product, ProductMarketplaceLink

CSV_PATH = Path(__file__).parent.parent / "Книга1.csv"

DOMAIN_TO_CODE: dict[str, str] = {
    "goldapple.ru": "goldapple",
    "goldapple.qa": "goldapple",
    "hollyshop.ru": "hollyshop",
    "www.letu.ru": "letu",
    "letu.ru": "letu",
    "rivegauche.ru": "rivegauche",
    "www.ozon.ru": "ozon",
    "cream.shop": "creamshop",
    "www.heybabescosmetics.com": "heybabes",
    "www.erborian.ru": "erborian",
    "market.yandex.ru": "yandex",
    "apteka.ru": "apteka",
    "ru.stylekorean.com": "stylekorean",
}

MARKETPLACE_NAMES: dict[str, str] = {
    "goldapple": "Gold Apple",
    "hollyshop": "Hollyshop",
    "letu": "Letu",
    "rivegauche": "Rive Gauche",
    "ozon": "Ozon",
    "creamshop": "Cream.shop",
    "heybabes": "Hey Babes Cosmetics",
    "erborian": "Erborian Russia",
    "yandex": "Яндекс Маркет",
    "apteka": "Apteka.ru",
    "stylekorean": "Style Korean",
}


def _normalize_text(text: str) -> str:
    lowered = text.lower()
    return re.sub(r"\s+", " ", lowered)


def build_product_id(brand: str, product_name: str) -> str:
    base = _normalize_text(f"{brand} {product_name}")
    slug = re.sub(r"[^0-9a-zа-яё]+", "-", base).strip("-")
    return slug or "product"


def marketplace_code_from_url(url: str) -> str | None:
    try:
        domain = urlparse(url).netloc
    except Exception:
        return None
    return DOMAIN_TO_CODE.get(domain)


def upsert_product(db, product_slug: str, brand: str, name: str) -> Product:
    product = db.query(Product).filter(Product.product_id == product_slug).first()
    if product is None:
        product = Product(product_id=product_slug, brand=brand, name=name)
        db.add(product)
        db.flush()
    else:
        if brand and not product.brand:
            product.brand = brand
        if name and not product.name:
            product.name = name
    return product


def upsert_marketplace(db, code: str) -> Marketplace:
    marketplace = db.query(Marketplace).filter(Marketplace.code == code).first()
    if marketplace is None:
        marketplace = Marketplace(code=code, name=MARKETPLACE_NAMES.get(code, code))
        db.add(marketplace)
        db.flush()
    return marketplace


def upsert_link(db, product: Product, marketplace: Marketplace, url: str, is_primary: bool) -> None:
    link = (
        db.query(ProductMarketplaceLink)
        .filter(
            ProductMarketplaceLink.product_id == product.id,
            ProductMarketplaceLink.marketplace_id == marketplace.id,
        )
        .first()
    )
    if link is None:
        link = ProductMarketplaceLink(
            product_id=product.id,
            marketplace_id=marketplace.id,
            url=url,
            is_primary=is_primary,
        )
        db.add(link)
    else:
        link.url = url
        link.is_primary = is_primary


def main() -> None:
    added = 0
    updated = 0
    skipped = 0

    db = SessionLocal()
    try:
        with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                brand = (row.get("Бренд") or "").strip()
                name = (row.get("Название продукта") or "").strip()
                url_field = (row.get("Ссылка") or "").strip()

                if not brand or not name or not url_field:
                    skipped += 1
                    continue

                urls = [u.strip() for u in url_field.split(";") if u.strip()]
                if not urls:
                    skipped += 1
                    continue

                product_slug = build_product_id(brand, name)
                product = upsert_product(db, product_slug, brand, name)

                for i, url in enumerate(urls):
                    code = marketplace_code_from_url(url)
                    if code is None:
                        print(f"  WARN: unknown domain for URL: {url}")
                        continue

                    marketplace = upsert_marketplace(db, code)

                    existing = (
                        db.query(ProductMarketplaceLink)
                        .filter(
                            ProductMarketplaceLink.product_id == product.id,
                            ProductMarketplaceLink.marketplace_id == marketplace.id,
                        )
                        .first()
                    )
                    is_primary = i == 0
                    if existing is None:
                        upsert_link(db, product, marketplace, url, is_primary)
                        added += 1
                    else:
                        upsert_link(db, product, marketplace, url, is_primary)
                        updated += 1

        db.commit()
        print(f"Готово: добавлено {added}, обновлено {updated}, пропущено {skipped}")
    except Exception as exc:
        db.rollback()
        print(f"Ошибка: {exc}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
