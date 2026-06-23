from __future__ import annotations

import unittest

from fastapi.middleware.cors import CORSMiddleware

from backend.app.main import app, create_care_plan, get_recommendation_engine
from backend.app.recommendation import (
    CompatibilityConflict,
    IntroductionPhase,
    IntroductionScheme,
    RecommendationCategory,
    RecommendationEngine,
    RecommendationMeta,
    RecommendationProduct,
    RecommendationRequest,
    RecommendationResult,
    UsageGuidance,
)
from backend.app.schemas import CarePlanRequest


class ApiContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self._original_get_engine = get_recommendation_engine
        import backend.app.main as main_module

        self._main_module = main_module
        main_module.get_recommendation_engine = lambda: _StubEngine()
        self._original_load_links = main_module._load_primary_links_if_available
        main_module._load_primary_links_if_available = _stub_load_primary_links

    def tearDown(self) -> None:
        self._main_module.get_recommendation_engine = self._original_get_engine
        self._main_module.get_recommendation_engine.cache_clear()
        self._main_module._load_primary_links_if_available = self._original_load_links

    def test_create_care_plan_returns_expected_contract(self) -> None:
        response = create_care_plan(
            CarePlanRequest(
                skinType="комбинированная",
                age=30,
                allergies=["на спирт"],
                priceRange="средний",
            )
        )

        self.assertEqual(response.categories[0].categoryCode, "cleansing")
        self.assertEqual(response.categories[0].products[0].productId, "brand-product")
        self.assertIsNone(response.categories[0].products[0].usageGuidance)
        self.assertEqual(
            response.categories[1].products[0].usageGuidance.activeFamily,
            "retinoid",
        )
        self.assertEqual(
            response.categories[1].products[0].usageGuidance.conflicts[0].label,
            "Кислоты и пилинги",
        )
        self.assertFalse(response.partial)
        self.assertEqual(response.meta.scoredCandidates, 2)

    def test_cors_middleware_is_configured(self) -> None:
        cors_layers = [
            middleware
            for middleware in app.user_middleware
            if middleware.cls is CORSMiddleware
        ]

        self.assertEqual(len(cors_layers), 1)
        options = cors_layers[0].kwargs
        self.assertIn("POST", options["allow_methods"])
        self.assertIn("GET", options["allow_methods"])
        self.assertEqual(options["allow_headers"], ["*"])


def _stub_load_primary_links(db: object, result) -> dict[str, str]:
    return {
        "brand-product": "https://goldapple.ru/brand-product",
        "retino-brand-retinol-serum": "https://goldapple.ru/retino-brand-retinol-serum",
    }


class _StubEngine(RecommendationEngine):
    def __init__(self) -> None:
        pass

    def build(self, request: RecommendationRequest) -> RecommendationResult:
        return RecommendationResult(
            categories=[
                RecommendationCategory(
                    category_code="cleansing",
                    display_name="Очищение",
                    products=[
                        RecommendationProduct(
                            product_id="brand-product",
                            brand="Brand",
                            product_name="Product",
                            url="https://example.com/products/brand-product",
                        )
                    ],
                ),
                RecommendationCategory(
                    category_code="intensive_renewal",
                    display_name="Интенсивное обновление",
                    products=[
                        RecommendationProduct(
                            product_id="retino-brand-retinol-serum",
                            brand="Retino Brand",
                            product_name="Retinol Serum",
                            url="https://example.com/products/retinol-serum",
                            usage_guidance=UsageGuidance(
                                active_family="retinoid",
                                display_label="Ретиноид",
                                introduction_scheme=IntroductionScheme(
                                    cycle_length_days=7,
                                    phases=[
                                        IntroductionPhase(
                                            week_start=1,
                                            week_end=2,
                                            day_start=1,
                                            day_end=14,
                                            allowed_cycle_days=[1, 4],
                                            label="Недели 1-2",
                                        ),
                                    ],
                                ),
                                conflicts=[
                                    CompatibilityConflict(
                                        label="Кислоты и пилинги",
                                        explanation="Не сочетать в один вечер.",
                                        category_codes=["intensive_renewal"],
                                        active_families=["acid"],
                                    )
                                ],
                                application_tips=["Используйте вечером."],
                            ),
                        )
                    ],
                ),
            ],
            partial=False,
            meta=RecommendationMeta(
                total_candidates=2,
                scored_candidates=2,
                excluded_by_allergy=0,
            ),
        )
