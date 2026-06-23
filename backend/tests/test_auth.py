from __future__ import annotations

import unittest

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import backend.app.main as main_module
from backend.app.auth import get_current_user
from backend.app.database import Base
from backend.app.db_models import Marketplace, Product, ProductMarketplaceLink
from backend.app.main import create_care_plan, login, me, register
from backend.app.main import save_profile
from backend.app.recommendation import (
    RecommendationCategory,
    RecommendationEngine,
    RecommendationMeta,
    RecommendationProduct,
    RecommendationRequest,
    RecommendationResult,
)
from backend.app.schemas import (
    CarePlanRequest,
    LoginRequest,
    RegisterRequest,
    SkinProfilePayload,
)


class AuthApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self._engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(bind=self._engine)
        self._session_factory = sessionmaker(
            bind=self._engine,
            autoflush=False,
            autocommit=False,
        )
        self._db = self._session_factory()

    def tearDown(self) -> None:
        self._db.close()
        self._engine.dispose()

    def test_register_creates_user_and_returns_jwt(self) -> None:
        response = register(
            RegisterRequest(
                name="Test User",
                email="TEST@example.com",
                password="password123",
            ),
            self._db,
        )

        self.assertTrue(response.accessToken)
        self.assertEqual(response.tokenType, "bearer")
        self.assertEqual(response.user.email, "test@example.com")

    def test_register_rejects_duplicate_email(self) -> None:
        payload = RegisterRequest(
            name="Test User",
            email="test@example.com",
            password="password123",
        )
        register(payload, self._db)

        with self.assertRaises(HTTPException) as context:
            register(payload, self._db)

        self.assertEqual(context.exception.status_code, 409)

    def test_login_accepts_correct_password_and_rejects_wrong_password(self) -> None:
        register(
            RegisterRequest(
                name="Test User",
                email="test@example.com",
                password="password123",
            ),
            self._db,
        )

        successful_response = login(
            LoginRequest(email="test@example.com", password="password123"),
            self._db,
        )

        with self.assertRaises(HTTPException) as context:
            login(LoginRequest(email="test@example.com", password="wrong"), self._db)

        self.assertTrue(successful_response.accessToken)
        self.assertEqual(context.exception.status_code, 401)

    def test_me_requires_valid_jwt(self) -> None:
        register_response = register(
            RegisterRequest(
                name="Test User",
                email="test@example.com",
                password="password123",
            ),
            self._db,
        )

        with self.assertRaises(HTTPException) as context:
            get_current_user(credentials=None, db=self._db)

        current_user = get_current_user(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer",
                credentials=register_response.accessToken,
            ),
            db=self._db,
        )
        response = me(current_user)

        self.assertEqual(context.exception.status_code, 401)
        self.assertEqual(response.email, "test@example.com")

    def test_profile_persists_survey_status_for_next_login(self) -> None:
        register_response = register(
            RegisterRequest(
                name="Test User",
                email="test@example.com",
                password="password123",
            ),
            self._db,
        )
        current_user = get_current_user(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer",
                credentials=register_response.accessToken,
            ),
            db=self._db,
        )

        save_profile(
            SkinProfilePayload(
                skinType="комбинированная",
                age=30,
                allergies=["на спирт"],
                priceRange="средний",
            ),
            current_user,
            self._db,
        )
        login_response = login(
            LoginRequest(email="test@example.com", password="password123"),
            self._db,
        )

        self.assertTrue(login_response.user.hasCompletedSurvey)
        self.assertIsNotNone(login_response.user.skinProfile)
        self.assertEqual(login_response.user.skinProfile.skinType, "комбинированная")

    def test_care_plan_uses_primary_marketplace_link_when_available(self) -> None:
        product = Product(
            product_id="brand-product",
            brand="Brand",
            name="Product",
        )
        marketplace = Marketplace(code="wb", name="Wildberries")
        self._db.add_all([product, marketplace])
        self._db.flush()
        self._db.add(
            ProductMarketplaceLink(
                product_id=product.id,
                marketplace_id=marketplace.id,
                url="https://market.example/brand-product",
                is_primary=True,
            )
        )
        self._db.commit()

        original_get_engine = main_module.get_recommendation_engine
        main_module.get_recommendation_engine = lambda: _StubEngine()
        try:
            response = create_care_plan(
                CarePlanRequest(
                    skinType="комбинированная",
                    age=30,
                    allergies=[],
                    priceRange="средний",
                ),
                self._db,
            )
        finally:
            main_module.get_recommendation_engine = original_get_engine

        self.assertEqual(
            response.categories[0].products[0].url,
            "https://market.example/brand-product",
        )


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
                )
            ],
            partial=False,
            meta=RecommendationMeta(
                total_candidates=1,
                scored_candidates=1,
                excluded_by_allergy=0,
            ),
        )
