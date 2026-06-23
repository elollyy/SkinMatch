from __future__ import annotations

from datetime import datetime, timezone
from functools import lru_cache

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import (
    create_access_token,
    get_current_user,
    hash_password,
    normalize_email,
    verify_password,
)
from .catalog import load_catalog
from .config import Settings, get_settings
from .database import Base, engine, get_db
from .db_models import Marketplace, Product, ProductMarketplaceLink, User
from .model import PMMLEvaluator
from .product_links import load_primary_product_links
from .recommendation import RecommendationEngine, RecommendationRequest, build_product_id
from .schemas import (
    AuthResponse,
    CarePlanMetaResponse,
    CarePlanRequest,
    CarePlanResponse,
    CategoryResponse,
    CompatibilityConflictResponse,
    IntroductionPhaseResponse,
    IntroductionSchemeResponse,
    LoginRequest,
    ProductResponse,
    RegisterRequest,
    SkinProfilePayload,
    UsageGuidanceResponse,
    UserResponse,
)

app = FastAPI(title="SkinMatch Care Plan API", version="0.1.0")


@lru_cache(maxsize=1)
def get_runtime_settings() -> Settings:
    return get_settings()


runtime_settings = get_runtime_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(runtime_settings.cors_allowed_origins),
    allow_origin_regex=runtime_settings.cors_allowed_origin_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.on_event("startup")
def create_database_tables() -> None:
    Base.metadata.create_all(bind=engine)
    _ensure_user_profile_columns()


@lru_cache(maxsize=1)
def get_recommendation_engine() -> RecommendationEngine:
    settings = get_runtime_settings()
    catalog = load_catalog(settings.dataset_path)
    evaluator = PMMLEvaluator(settings.model_path)
    return RecommendationEngine(catalog=catalog, evaluator=evaluator)


@app.get("/health")
def health() -> dict[str, object]:
    engine = get_recommendation_engine()
    settings = get_runtime_settings()
    return {
        "status": "ok",
        "datasetPath": str(settings.dataset_path),
        "modelPath": str(settings.model_path),
        "catalogProducts": len(engine._catalog.products),
        "catalogInvalidRows": engine._catalog.invalid_rows,
        "evaluatorAvailable": engine._evaluator.status.available,
        "evaluatorError": engine._evaluator.status.error,
    }


@app.post(
    "/api/v1/auth/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> AuthResponse:
    email = normalize_email(payload.email)
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User with this email already exists",
        )

    user = User(
        name=payload.name.strip(),
        email=email,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User with this email already exists",
        ) from error
    db.refresh(user)

    return _auth_response(user)


@app.post("/api/v1/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    email = normalize_email(payload.email)
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    return _auth_response(user)


@app.get("/api/v1/auth/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)) -> UserResponse:
    return _user_response(current_user)


@app.post("/api/v1/auth/profile", response_model=UserResponse)
def save_profile(
    payload: SkinProfilePayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserResponse:
    user = db.get(User, current_user.id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    user.has_completed_survey = True
    user.skin_profile_json = payload.model_dump()
    user.survey_completed_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return _user_response(user)


@app.post("/api/v1/care-plan", response_model=CarePlanResponse)
def create_care_plan(
    payload: CarePlanRequest,
    db: Session | None = Depends(get_db),
) -> CarePlanResponse:
    engine = get_recommendation_engine()
    result = engine.build(
        RecommendationRequest(
            skin_type=payload.skinType,
            age=payload.age,
            allergies=payload.allergies,
            price_range=payload.priceRange,
        )
    )
    primary_links = _load_primary_links_if_available(db, result)

    return CarePlanResponse(
        categories=[
            CategoryResponse(
                categoryCode=category.category_code,
                displayName=category.display_name,
                products=[
                    ProductResponse(
                        productId=product.product_id,
                        brand=product.brand,
                        productName=product.product_name,
                        url=primary_links[product.product_id],
                        usageGuidance=_map_usage_guidance(product.usage_guidance),
                    )
                    for product in category.products
                    if product.product_id in primary_links
                ],
            )
            for category in result.categories
            if any(p.product_id in primary_links for p in category.products)
        ],
        partial=result.partial,
        meta=CarePlanMetaResponse(
            totalCandidates=result.meta.total_candidates,
            scoredCandidates=result.meta.scored_candidates,
            excludedByAllergy=result.meta.excluded_by_allergy,
        ),
    )


def _auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        accessToken=create_access_token(user_id=user.id),
        user=_user_response(user),
    )


def _user_response(user: User) -> UserResponse:
    raw_profile = user.skin_profile_json
    skin_profile = None
    if isinstance(raw_profile, dict):
        skin_profile = SkinProfilePayload.model_validate(raw_profile)

    return UserResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        hasCompletedSurvey=user.has_completed_survey,
        skinProfile=skin_profile,
    )


def _ensure_user_profile_columns() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("users"):
        return

    existing_columns = {column["name"] for column in inspector.get_columns("users")}
    statements = []
    if "has_completed_survey" not in existing_columns:
        statements.append(
            "ALTER TABLE users ADD COLUMN has_completed_survey BOOLEAN NOT NULL DEFAULT false"
        )
    if "skin_profile_json" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN skin_profile_json JSON")
    if "survey_completed_at" not in existing_columns:
        statements.append("ALTER TABLE users ADD COLUMN survey_completed_at TIMESTAMP")

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _load_primary_links_if_available(db: object, result) -> dict[str, str]:
    if not isinstance(db, Session):
        return {}

    product_ids = [
        product.product_id
        for category in result.categories
        for product in category.products
    ]
    return load_primary_product_links(db, product_ids)


def _map_usage_guidance(guidance) -> UsageGuidanceResponse | None:
    if guidance is None:
        return None

    return UsageGuidanceResponse(
        activeFamily=guidance.active_family,
        displayLabel=guidance.display_label,
        introductionScheme=IntroductionSchemeResponse(
            cycleLengthDays=guidance.introduction_scheme.cycle_length_days,
            phases=[
                IntroductionPhaseResponse(
                    weekStart=phase.week_start,
                    weekEnd=phase.week_end,
                    dayStart=phase.day_start,
                    dayEnd=phase.day_end,
                    allowedCycleDays=phase.allowed_cycle_days,
                    label=phase.label,
                    note=phase.note,
                )
                for phase in guidance.introduction_scheme.phases
            ],
            startWithEveningOnly=guidance.introduction_scheme.start_with_evening_only,
        ),
        conflicts=[
            CompatibilityConflictResponse(
                label=conflict.label,
                explanation=conflict.explanation,
                categoryCodes=conflict.category_codes,
                activeFamilies=conflict.active_families,
            )
            for conflict in guidance.conflicts
        ],
        applicationTips=guidance.application_tips,
    )


# ── Admin: product link management ────────────────────────────────────────────

from pydantic import BaseModel as _BaseModel


class ProductLinkRequest(_BaseModel):
    product_slug: str
    url: str
    marketplace_code: str = "default"
    is_primary: bool = True


class ProductLinkResponse(_BaseModel):
    product_slug: str
    url: str
    marketplace_code: str
    is_primary: bool


class CatalogProductItem(_BaseModel):
    product_slug: str
    brand: str
    product_name: str
    category: str


def _upsert_product_link(
    db: Session,
    product_slug: str,
    marketplace_code: str,
    url: str,
    is_primary: bool,
) -> None:
    product = db.query(Product).filter(Product.product_id == product_slug).first()
    if product is None:
        product = Product(product_id=product_slug, brand="", name=product_slug)
        db.add(product)
        db.flush()

    marketplace = (
        db.query(Marketplace).filter(Marketplace.code == marketplace_code).first()
    )
    if marketplace is None:
        marketplace = Marketplace(code=marketplace_code, name=marketplace_code)
        db.add(marketplace)
        db.flush()

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

    db.commit()


@app.get("/api/v1/admin/catalog", response_model=list[CatalogProductItem])
def admin_list_catalog() -> list[CatalogProductItem]:
    engine = get_recommendation_engine()
    items = []
    for product in engine.catalog.products:
        slug = build_product_id(product.brand, product.product_name)
        items.append(
            CatalogProductItem(
                product_slug=slug,
                brand=product.brand,
                product_name=product.product_name,
                category=product.purpose,
            )
        )
    return items


@app.post("/api/v1/admin/product-links", response_model=ProductLinkResponse)
def admin_add_product_link(
    payload: ProductLinkRequest,
    db: Session = Depends(get_db),
) -> ProductLinkResponse:
    _upsert_product_link(
        db,
        product_slug=payload.product_slug,
        marketplace_code=payload.marketplace_code,
        url=payload.url,
        is_primary=payload.is_primary,
    )
    return ProductLinkResponse(
        product_slug=payload.product_slug,
        url=payload.url,
        marketplace_code=payload.marketplace_code,
        is_primary=payload.is_primary,
    )


@app.get("/api/v1/admin/product-links", response_model=list[ProductLinkResponse])
def admin_list_product_links(db: Session = Depends(get_db)) -> list[ProductLinkResponse]:
    rows = (
        db.query(Product.product_id, Marketplace.code, ProductMarketplaceLink.url, ProductMarketplaceLink.is_primary)
        .join(ProductMarketplaceLink, ProductMarketplaceLink.product_id == Product.id)
        .join(Marketplace, Marketplace.id == ProductMarketplaceLink.marketplace_id)
        .all()
    )
    return [
        ProductLinkResponse(
            product_slug=row.product_id,
            url=row.url,
            marketplace_code=row.code,
            is_primary=row.is_primary,
        )
        for row in rows
    ]
