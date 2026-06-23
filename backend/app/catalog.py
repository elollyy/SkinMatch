from __future__ import annotations

import csv
import hashlib
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import pandas as pd
except ImportError:  # pragma: no cover - exercised when pandas is installed
    pd = None


EXPECTED_COLUMNS = (
    "Предназночение",
    "Бренд",
    "Название продукта",
    "Ценовой сегмент",
    "Возрастная категория",
    "Ингредиенты",
    "Тип состава",
    "Комбинированная",
    "Сухая кожа",
    "Нормальная",
    "Жирная",
    "Чувствительная",
    "Проблемная кожа",
    "Универсальность",
    "Оценка",
    "Категория эффективности",
    "Кластер",
    "split",
)

SKIN_COLUMNS = (
    "Комбинированная",
    "Сухая кожа",
    "Нормальная",
    "Жирная",
    "Чувствительная",
    "Проблемная кожа",
)


@dataclass(frozen=True)
class CatalogProduct:
    purpose: str
    brand: str
    product_name: str
    price_segment: str
    age_category: str
    ingredients: str
    composition_type: str
    combined_skin: float
    dry_skin: float
    normal_skin: float
    oily_skin: float
    sensitive_skin: float
    problematic_skin: float
    universality: float
    rating: float
    effectiveness_category: str
    cluster: str
    dataset_split: str
    url: str

    def model_features(self) -> dict[str, Any]:
        return {
            "Комбинированная": self.combined_skin,
            "Сухая кожа": self.dry_skin,
            "Нормальная": self.normal_skin,
            "Жирная": self.oily_skin,
            "Чувствительная": self.sensitive_skin,
            "Проблемная кожа": self.problematic_skin,
            "Универсальность": self.universality,
            "Оценка": self.rating,
            "Предназночение": self.purpose,
            "Ценовой сегмент": self.price_segment,
            "Возрастная категория": self.age_category,
            "Тип состава": self.composition_type,
        }

    def skin_flag(self, column_name: str) -> float:
        mapping = {
            "Комбинированная": self.combined_skin,
            "Сухая кожа": self.dry_skin,
            "Нормальная": self.normal_skin,
            "Жирная": self.oily_skin,
            "Чувствительная": self.sensitive_skin,
            "Проблемная кожа": self.problematic_skin,
        }
        return mapping.get(column_name, 0.0)


@dataclass(frozen=True)
class CatalogLoadResult:
    products: list[CatalogProduct]
    invalid_rows: int


def load_catalog(path: Path) -> CatalogLoadResult:
    invalid_rows = 0
    products: list[CatalogProduct] = []

    for raw_row in _iter_rows(path):
        try:
            products.append(_build_product(raw_row))
        except ValueError:
            invalid_rows += 1

    return CatalogLoadResult(products=products, invalid_rows=invalid_rows)


def _iter_rows(path: Path) -> list[dict[str, str]]:
    if pd is not None:
        data_frame = pd.read_csv(
            path,
            sep=";",
            encoding="utf-8-sig",
            usecols=list(range(len(EXPECTED_COLUMNS))),
            dtype=str,
            keep_default_na=False,
        )
        return [
            {column: _clean_text(record.get(column, "")) for column in EXPECTED_COLUMNS}
            for record in data_frame.to_dict(orient="records")
        ]

    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file, delimiter=";")
        header = next(reader, [])
        header = list(header[: len(EXPECTED_COLUMNS)])

        rows = []
        for values in reader:
            record = {
                column: _clean_text(value)
                for column, value in zip(header, values[: len(EXPECTED_COLUMNS)])
            }
            rows.append(record)

        return rows


def _build_product(raw_row: dict[str, str]) -> CatalogProduct:
    required_values = (
        raw_row.get("Предназночение", ""),
        raw_row.get("Бренд", ""),
        raw_row.get("Название продукта", ""),
    )
    if any(not value for value in required_values):
        raise ValueError("Catalog row is missing a required field")

    return CatalogProduct(
        purpose=raw_row["Предназночение"],
        brand=raw_row["Бренд"],
        product_name=raw_row["Название продукта"],
        price_segment=raw_row.get("Ценовой сегмент", ""),
        age_category=raw_row.get("Возрастная категория", ""),
        ingredients=raw_row.get("Ингредиенты", ""),
        composition_type=raw_row.get("Тип состава", ""),
        combined_skin=_parse_float(raw_row.get("Комбинированная", "0")),
        dry_skin=_parse_float(raw_row.get("Сухая кожа", "0")),
        normal_skin=_parse_float(raw_row.get("Нормальная", "0")),
        oily_skin=_parse_float(raw_row.get("Жирная", "0")),
        sensitive_skin=_parse_float(raw_row.get("Чувствительная", "0")),
        problematic_skin=_parse_float(raw_row.get("Проблемная кожа", "0")),
        universality=_parse_float(raw_row.get("Универсальность", "0")),
        rating=_parse_float(raw_row.get("Оценка", "0")),
        effectiveness_category=raw_row.get("Категория эффективности", ""),
        cluster=raw_row.get("Кластер", ""),
        dataset_split=raw_row.get("split", ""),
        url=_placeholder_url(
            brand=raw_row["Бренд"],
            product_name=raw_row["Название продукта"],
        ),
    )


def _parse_float(raw_value: str) -> float:
    value = _clean_text(raw_value).replace(",", ".")
    if not value:
        return 0.0

    try:
        return float(value)
    except ValueError as error:
        raise ValueError(f"Unable to parse numeric value: {raw_value}") from error


def _clean_text(value: Any) -> str:
    return str(value or "").strip()


def _placeholder_url(*, brand: str, product_name: str) -> str:
    base_value = f"{brand}-{product_name}"
    slug = _slugify(base_value)
    if slug:
        return f"https://example.com/products/{slug}"

    suffix = hashlib.sha1(base_value.encode("utf-8")).hexdigest()[:12]
    return f"https://example.com/products/{suffix}"


def _slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_value).strip("-")
    return slug
