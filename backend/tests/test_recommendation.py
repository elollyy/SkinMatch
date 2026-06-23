from __future__ import annotations

import unittest

from backend.app.catalog import CatalogLoadResult, CatalogProduct
from backend.app.model import ModelStatus
from backend.app.recommendation import (
    RecommendationEngine,
    RecommendationRequest,
    build_intensive_guidance,
    detect_active_family,
    has_allergy_conflict,
    map_age_category,
    map_category,
    map_price_range,
)


class RecommendationEngineTest(unittest.TestCase):
    def test_maps_price_range_to_new_dataset_values(self) -> None:
        self.assertEqual(map_price_range("бюджетный"), "Низкий")
        self.assertEqual(map_price_range("средний"), "Средний")
        self.assertEqual(map_price_range("люкс"), "Высокий")
        self.assertEqual(map_price_range("премиум"), "Высокий")
        self.assertEqual(map_price_range("миддл"), "Средний")

    def test_maps_age_bucket_including_30_plus(self) -> None:
        self.assertEqual(map_age_category(22), "18+")
        self.assertEqual(map_age_category(27), "25+")
        self.assertEqual(map_age_category(30), "30+")
        self.assertEqual(map_age_category(34), "30+")
        self.assertEqual(map_age_category(41), "35+")
        self.assertEqual(map_age_category(50), "35+")

    def test_filters_allergies_with_expected_marker_sets(self) -> None:
        self.assertTrue(has_allergy_conflict("water, denat. alcohol", ["на спирт"]))
        self.assertTrue(has_allergy_conflict("масло ши, вода", ["на масла"]))
        self.assertTrue(has_allergy_conflict("water, parfum", ["на отдушки"]))
        self.assertFalse(has_allergy_conflict("water, glycerin", ["другое"]))

    def test_maps_purpose_to_category_code(self) -> None:
        self.assertEqual(map_category("Очищение"), ("cleansing", "Очищение"))
        self.assertEqual(
            map_category("Интенсивное обновление"),
            ("intensive_renewal", "Интенсивное обновление"),
        )
        self.assertEqual(map_category("Маска"), ("serums_masks", "Сыворотки и маски"))
        self.assertEqual(
            map_category("Солнцезащитное средство"),
            ("spf", "SPF"),
        )

    def test_detects_active_family_from_name_and_ingredients(self) -> None:
        self.assertEqual(
            detect_active_family(
                _product(
                    purpose="Интенсивное обновление",
                    product_name="0.3% Retinol Serum",
                    ingredients="water, retinol, squalane",
                )
            ),
            "retinoid",
        )
        self.assertEqual(
            detect_active_family(
                _product(
                    purpose="Интенсивное обновление",
                    product_name="AHA Night Peel",
                    ingredients="water, glycolic acid, panthenol",
                )
            ),
            "acid",
        )
        self.assertEqual(
            detect_active_family(
                _product(
                    purpose="Интенсивное обновление",
                    product_name="VT Reedle Shot 100",
                    ingredients="water, hydrolyzed sponge, glycerin",
                )
            ),
            "spicule",
        )

    def test_unknown_intensive_product_falls_back_to_safe_guidance(self) -> None:
        guidance = build_intensive_guidance(
            _product(
                purpose="Интенсивное обновление",
                product_name="Barrier Reset Booster",
                ingredients="water, panthenol, madecassoside",
            )
        )

        self.assertTrue(guidance.is_fallback)
        self.assertEqual(guidance.guidance.active_family, "other_intensive")
        self.assertEqual(
            guidance.guidance.introduction_scheme.phases[0].allowed_cycle_days,
            [3],
        )

    def test_build_includes_intensive_renewal_in_expected_order(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(
                products=[
                    _product(
                        purpose="Маска",
                        brand="Mask Brand",
                        product_name="Mask Product",
                        price_segment="Средний",
                        age_category="30+",
                        ingredients="water, glycerin",
                        combined_skin=1.0,
                        rating=4.3,
                        effectiveness_category="Средняя",
                    ),
                    _product(
                        purpose="Интенсивное обновление",
                        brand="Renew Brand",
                        product_name="Renew Product",
                        price_segment="Средний",
                        age_category="30+",
                        ingredients="water, glycerin",
                        combined_skin=1.0,
                        rating=4.8,
                        effectiveness_category="Высокая",
                    ),
                    _product(
                        purpose="Увлажнение",
                        brand="Moist Brand",
                        product_name="Moist Product",
                        price_segment="Средний",
                        age_category="30+",
                        ingredients="water, glycerin",
                        combined_skin=1.0,
                        rating=4.1,
                        effectiveness_category="Средняя",
                    ),
                ],
                invalid_rows=0,
            ),
            evaluator=_StaticEvaluator(
                predictions={
                    "Маска:4.3": "Средняя",
                    "Интенсивное обновление:4.8": "Высокая",
                    "Увлажнение:4.1": "Средняя",
                }
            ),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=30,
                allergies=[],
                price_range="средний",
            )
        )

        self.assertEqual(
            [category.category_code for category in result.categories],
            ["moisturizing", "intensive_renewal", "serums_masks"],
        )
        self.assertEqual(
            result.categories[1].display_name,
            "Интенсивное обновление",
        )
        renewal_product = result.categories[1].products[0]
        self.assertEqual(renewal_product.product_id, "renew-brand-renew-product")
        self.assertEqual(renewal_product.usage_guidance.active_family, "other_intensive")
        self.assertTrue(result.partial)

    def test_builds_expected_response_shape(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(
                products=[
                    _product(
                        purpose="Очищение",
                        brand="Alpha",
                        product_name="Clean One",
                        price_segment="Средний",
                        age_category="30+",
                        ingredients="water, glycerin",
                        combined_skin=1.0,
                        rating=4.5,
                        effectiveness_category="Высокая",
                    ),
                    _product(
                        purpose="Солнцезащитное средство",
                        brand="Beta",
                        product_name="Sun One",
                        price_segment="Средний",
                        age_category="18+",
                        ingredients="water, glycerin",
                        combined_skin=1.0,
                        rating=4.0,
                        effectiveness_category="Средняя",
                    ),
                ],
                invalid_rows=0,
            ),
            evaluator=_StaticEvaluator(
                predictions={
                    "Очищение:4.5": "Высокая",
                    "Солнцезащитное средство:4.0": "Средняя",
                }
            ),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=30,
                allergies=[],
                price_range="средний",
            )
        )

        self.assertEqual(
            [category.category_code for category in result.categories],
            ["cleansing", "spf"],
        )
        self.assertEqual(result.categories[0].products[0].brand, "Alpha")
        self.assertEqual(result.categories[0].products[0].product_id, "alpha-clean-one")
        self.assertTrue(result.partial)
        self.assertEqual(result.meta.total_candidates, 2)
        self.assertEqual(result.meta.scored_candidates, 2)

    def test_build_returns_guidance_for_recognized_intensive_family(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(
                products=[
                    _product(
                        purpose="Интенсивное обновление",
                        brand="Retino Brand",
                        product_name="0.3% Retinol Night Serum",
                        ingredients="water, retinol, squalane",
                        price_segment="Средний",
                        age_category="30+",
                        combined_skin=1.0,
                        rating=4.9,
                        effectiveness_category="Высокая",
                    ),
                ],
                invalid_rows=0,
            ),
            evaluator=_StaticEvaluator(
                predictions={
                    "Интенсивное обновление:4.9": "Высокая",
                }
            ),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=30,
                allergies=[],
                price_range="средний",
            )
        )

        product = result.categories[0].products[0]
        self.assertEqual(product.usage_guidance.active_family, "retinoid")
        self.assertEqual(
            product.usage_guidance.introduction_scheme.cycle_length_days,
            7,
        )
        self.assertEqual(product.usage_guidance.conflicts[0].label, "Кислоты и пилинги")
        self.assertTrue(result.partial)

    def test_build_prefers_exact_30_plus_bucket_with_new_price_segments(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(
                products=[
                    _product(
                        brand="Alpha",
                        product_name="Age Match",
                        price_segment="Высокий",
                        age_category="30+",
                        ingredients="water, glycerin",
                        rating=4.0,
                        effectiveness_category="Высокая",
                    ),
                    _product(
                        brand="Beta",
                        product_name="Older Bucket",
                        price_segment="Высокий",
                        age_category="35+",
                        ingredients="water, glycerin",
                        rating=4.0,
                        effectiveness_category="Высокая",
                    ),
                ],
                invalid_rows=0,
            ),
            evaluator=_StaticEvaluator(
                predictions={
                    "Очищение:4.0": "Высокая",
                }
            ),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=32,
                allergies=[],
                price_range="люкс",
            )
        )

        self.assertEqual(result.categories[0].products[0].brand, "Alpha")

    def test_marks_partial_when_evaluator_is_unavailable(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(products=[_product()], invalid_rows=0),
            evaluator=_UnavailableEvaluator(),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=30,
                allergies=[],
                price_range="средний",
            )
        )

        self.assertTrue(result.partial)
        self.assertEqual(result.categories[0].products[0].brand, "Alpha")

    def test_returns_empty_categories_when_filters_exclude_everything(self) -> None:
        engine = RecommendationEngine(
            catalog=CatalogLoadResult(products=[_product()], invalid_rows=0),
            evaluator=_StaticEvaluator(predictions={"Очищение:4.2": "Высокая"}),
        )

        result = engine.build(
            RecommendationRequest(
                skin_type="комбинированная",
                age=30,
                allergies=["на спирт"],
                price_range="средний",
            )
        )

        self.assertEqual(result.categories, [])
        self.assertTrue(result.partial)
        self.assertEqual(result.meta.excluded_by_allergy, 1)


class _StaticEvaluator:
    def __init__(self, *, predictions: dict[str, str]) -> None:
        self.predictions = predictions
        self.status = ModelStatus(available=True)

    def predict_effectiveness(self, features: dict[str, object]) -> str:
        key = f"{features['Предназночение']}:{features['Оценка']}"
        return self.predictions[key]


class _UnavailableEvaluator:
    status = ModelStatus(available=False, error="not installed")

    def predict_effectiveness(self, features: dict[str, object]) -> str:
        raise RuntimeError("unavailable")


def _product(
    *,
    purpose: str = "Очищение",
    brand: str = "Alpha",
    product_name: str = "Clean One",
    price_segment: str = "Средний",
    age_category: str = "25+",
    ingredients: str = "water, denat. alcohol",
    combined_skin: float = 1.0,
    rating: float = 4.2,
    effectiveness_category: str = "Средняя",
) -> CatalogProduct:
    return CatalogProduct(
        purpose=purpose,
        brand=brand,
        product_name=product_name,
        price_segment=price_segment,
        age_category=age_category,
        ingredients=ingredients,
        composition_type="Смешанный",
        combined_skin=combined_skin,
        dry_skin=0.0,
        normal_skin=0.0,
        oily_skin=0.0,
        sensitive_skin=0.0,
        problematic_skin=0.0,
        universality=0.0,
        rating=rating,
        effectiveness_category=effectiveness_category,
        cluster="Группа1",
        dataset_split="train",
        url="https://example.com/products/alpha-clean-one",
    )
