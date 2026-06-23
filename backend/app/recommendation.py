from __future__ import annotations

import re
from collections import defaultdict
from dataclasses import dataclass

from .catalog import CatalogLoadResult, CatalogProduct
from .model import PMMLEvaluator


CATEGORY_MAPPING = {
    "Очищение": ("cleansing", "Очищение"),
    "Увлажнение": ("moisturizing", "Увлажнение"),
    "Интенсивное обновление": ("intensive_renewal", "Интенсивное обновление"),
    "Маска": ("serums_masks", "Сыворотки и маски"),
    "Уход": ("serums_masks", "Сыворотки и маски"),
    "Крем для глаз": ("eye_cream", "Крем для глаз"),
    "Солнцезащитное средство": ("spf", "SPF"),
}

CATEGORY_ORDER = (
    "cleansing",
    "moisturizing",
    "intensive_renewal",
    "serums_masks",
    "eye_cream",
    "spf",
)

SKIN_TYPE_MAPPING = {
    "комбинированная": "Комбинированная",
    "сухая": "Сухая кожа",
    "сухая кожа": "Сухая кожа",
    "нормальная": "Нормальная",
    "жирная": "Жирная",
    "чувствительная": "Чувствительная",
    "проблемная": "Проблемная кожа",
    "проблемная кожа": "Проблемная кожа",
}

PRICE_RANGE_MAPPING = {
    "бюджетный": "Низкий",
    "масс-маркет": "Низкий",
    "средний": "Средний",
    "миддл": "Средний",
    "премиум": "Высокий",
    "люкс": "Высокий",
}

AGE_MATCH_MAPPING = {
    "18+": 18,
    "25+": 25,
    "30+": 30,
    "35+": 35,
    "Для детей": 0,
}

EFFECTIVENESS_WEIGHTS = {
    "Высокая": 3.0,
    "Средняя": 2.0,
    "Низкая": 1.0,
}

ALLERGY_MARKERS = {
    "на спирт": (
        " alcohol",
        "alcohol",
        "ethanol",
        "спирт",
        "денат",
    ),
    "на масла": (
        " oil",
        "масло",
        "seed oil",
        "butter",
        "баттер",
        "ши",
    ),
    "на отдушки": (
        "fragrance",
        "parfum",
        "perfume",
        "ароматизатор",
        "ароматизаторы",
        "отдушка",
    ),
    "другое": (),
}


@dataclass(frozen=True)
class RecommendationRequest:
    skin_type: str
    age: int
    allergies: list[str]
    price_range: str


@dataclass(frozen=True)
class RecommendationProduct:
    product_id: str
    brand: str
    product_name: str
    url: str
    usage_guidance: UsageGuidance | None = None


@dataclass(frozen=True)
class RecommendationCategory:
    category_code: str
    display_name: str
    products: list[RecommendationProduct]


@dataclass(frozen=True)
class RecommendationMeta:
    total_candidates: int
    scored_candidates: int
    excluded_by_allergy: int


@dataclass(frozen=True)
class RecommendationResult:
    categories: list[RecommendationCategory]
    partial: bool
    meta: RecommendationMeta


@dataclass(frozen=True)
class IntroductionPhase:
    week_start: int
    week_end: int | None
    day_start: int
    day_end: int | None
    allowed_cycle_days: list[int]
    label: str
    note: str | None = None


@dataclass(frozen=True)
class IntroductionScheme:
    cycle_length_days: int
    phases: list[IntroductionPhase]
    start_with_evening_only: bool = True


@dataclass(frozen=True)
class CompatibilityConflict:
    label: str
    explanation: str
    category_codes: list[str]
    active_families: list[str]


@dataclass(frozen=True)
class UsageGuidance:
    active_family: str
    display_label: str
    introduction_scheme: IntroductionScheme
    conflicts: list[CompatibilityConflict]
    application_tips: list[str]


@dataclass(frozen=True)
class ScoredProduct:
    category_code: str
    display_name: str
    product_id: str
    brand: str
    product_name: str
    url: str
    score: float
    usage_guidance: UsageGuidance | None = None


@dataclass(frozen=True)
class IntensiveGuidanceResult:
    guidance: UsageGuidance
    is_fallback: bool


ACTIVE_FAMILY_DISPLAY = {
    "retinoid": "Ретиноид",
    "acid": "Кислотный курс",
    "spicule": "Спикулы",
    "other_intensive": "Интенсивный актив",
}

ACTIVE_FAMILY_KEYWORDS = {
    "retinoid": (
        "retinol",
        "retinal",
        "retinoid",
        "retinoate",
        "adapalene",
        "tretinoin",
        "hydroxypinacolone retinoate",
        "granactive",
    ),
    "acid": (
        "salicylic",
        "glycolic",
        "lactic",
        "mandelic",
        "azelaic",
        "aha",
        "bha",
        "pha",
        "gluconolactone",
        "lactobionic",
        "peel",
        "peeling",
        "exfol",
    ),
    "spicule": (
        "spicule",
        "spicules",
        "reedle",
        "hydrolyzed sponge",
        "microneedle",
        "micro needle",
        "cica reedle",
    ),
}

INTENSIVE_GUIDANCE_BY_FAMILY = {
    "retinoid": UsageGuidance(
        active_family="retinoid",
        display_label=ACTIVE_FAMILY_DISPLAY["retinoid"],
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
                    note="Начинайте с двух вечеров в неделю.",
                ),
                IntroductionPhase(
                    week_start=3,
                    week_end=4,
                    day_start=15,
                    day_end=28,
                    allowed_cycle_days=[1, 3, 5],
                    label="Недели 3-4",
                    note="Если кожа спокойна, переходите на через день.",
                ),
                IntroductionPhase(
                    week_start=5,
                    week_end=None,
                    day_start=29,
                    day_end=None,
                    allowed_cycle_days=[1, 3, 5, 7],
                    label="С 5 недели",
                    note="Поддерживайте ритм 3-4 вечера в неделю.",
                ),
            ],
        ),
        conflicts=[
            CompatibilityConflict(
                label="Кислоты и пилинги",
                explanation="В один вечер не сочетайте ретиноид с кислотами и агрессивными обновляющими средствами.",
                category_codes=["intensive_renewal", "serums_masks"],
                active_families=["acid", "spicule"],
            ),
            CompatibilityConflict(
                label="Другие ретиноиды",
                explanation="Не наслаивайте несколько ретиноидных формул в один день.",
                category_codes=["intensive_renewal"],
                active_families=["retinoid"],
            ),
        ],
        application_tips=[
            "Наносите вечером на сухую кожу после мягкого очищения.",
            "Если появляется сухость, добавьте увлажняющий крем до и после актива.",
            "На следующий день обязательно используйте SPF 30+.",
        ],
    ),
    "acid": UsageGuidance(
        active_family="acid",
        display_label=ACTIVE_FAMILY_DISPLAY["acid"],
        introduction_scheme=IntroductionScheme(
            cycle_length_days=7,
            phases=[
                IntroductionPhase(
                    week_start=1,
                    week_end=2,
                    day_start=1,
                    day_end=14,
                    allowed_cycle_days=[2, 5],
                    label="Недели 1-2",
                    note="Стартуйте с двух вечеров в неделю.",
                ),
                IntroductionPhase(
                    week_start=3,
                    week_end=None,
                    day_start=15,
                    day_end=None,
                    allowed_cycle_days=[2, 4, 6],
                    label="С 3 недели",
                    note="Повышайте частоту только при хорошей переносимости.",
                ),
            ],
        ),
        conflicts=[
            CompatibilityConflict(
                label="Ретиноиды",
                explanation="Не используйте кислоты и ретиноиды в один вечер, чтобы не усилить раздражение.",
                category_codes=["intensive_renewal"],
                active_families=["retinoid"],
            ),
            CompatibilityConflict(
                label="Другие кислоты и скрабы",
                explanation="Избегайте дублирования кислот, спикул и абразивных эксфолиантов в один день.",
                category_codes=["intensive_renewal", "serums_masks"],
                active_families=["acid", "spicule"],
            ),
        ],
        application_tips=[
            "Используйте вечером и не наносите на раздраженную кожу.",
            "После курса кислоты закрывайте уход увлажняющим кремом.",
            "Днем нужен SPF 30+ и деликатное очищение.",
        ],
    ),
    "spicule": UsageGuidance(
        active_family="spicule",
        display_label=ACTIVE_FAMILY_DISPLAY["spicule"],
        introduction_scheme=IntroductionScheme(
            cycle_length_days=7,
            phases=[
                IntroductionPhase(
                    week_start=1,
                    week_end=2,
                    day_start=1,
                    day_end=14,
                    allowed_cycle_days=[3],
                    label="Недели 1-2",
                    note="Дайте коже привыкнуть к одному вечеру в неделю.",
                ),
                IntroductionPhase(
                    week_start=3,
                    week_end=None,
                    day_start=15,
                    day_end=None,
                    allowed_cycle_days=[3, 6],
                    label="С 3 недели",
                    note="При хорошей переносимости можно перейти на два вечера.",
                ),
            ],
        ),
        conflicts=[
            CompatibilityConflict(
                label="Ретиноиды и кислоты",
                explanation="Не комбинируйте спикулы с ретиноидами, кислотами и механическими скрабами в один вечер.",
                category_codes=["intensive_renewal", "serums_masks"],
                active_families=["retinoid", "acid", "spicule"],
            ),
        ],
        application_tips=[
            "Наносите вечером без дополнительных кислотных или ретиноидных слоев.",
            "Если кожа реагирует покалыванием дольше обычного, сделайте паузу.",
            "На следующий день используйте успокаивающий крем и SPF 30+.",
        ],
    ),
    "other_intensive": UsageGuidance(
        active_family="other_intensive",
        display_label=ACTIVE_FAMILY_DISPLAY["other_intensive"],
        introduction_scheme=IntroductionScheme(
            cycle_length_days=7,
            phases=[
                IntroductionPhase(
                    week_start=1,
                    week_end=2,
                    day_start=1,
                    day_end=14,
                    allowed_cycle_days=[3],
                    label="Недели 1-2",
                    note="Начинайте осторожно: один вечер в неделю.",
                ),
                IntroductionPhase(
                    week_start=3,
                    week_end=None,
                    day_start=15,
                    day_end=None,
                    allowed_cycle_days=[3, 6],
                    label="С 3 недели",
                    note="Если нет чувствительности, добавьте второй вечер.",
                ),
            ],
        ),
        conflicts=[
            CompatibilityConflict(
                label="Другие сильные активы",
                explanation="Пока актив не распознан, не сочетайте его в один вечер с кислотами, ретиноидами и спикулами.",
                category_codes=["intensive_renewal", "serums_masks"],
                active_families=["retinoid", "acid", "spicule", "other_intensive"],
            ),
        ],
        application_tips=[
            "Наносите только вечером и следите за реакцией кожи.",
            "Если появляется жжение или стойкое покраснение, увеличьте интервалы между нанесениями.",
            "Днем поддерживайте барьерный уход и SPF 30+.",
        ],
    ),
}


class RecommendationEngine:
    def __init__(self, catalog: CatalogLoadResult, evaluator: PMMLEvaluator) -> None:
        self._catalog = catalog
        self._evaluator = evaluator

    def build(self, request: RecommendationRequest) -> RecommendationResult:
        skin_column = map_skin_type(request.skin_type)
        mapped_price = map_price_range(request.price_range)
        target_age_category = map_age_category(request.age)

        partial = self._catalog.invalid_rows > 0 or not self._evaluator.status.available
        total_candidates = 0
        scored_candidates = 0
        excluded_by_allergy = 0
        candidates_by_category: dict[str, list[ScoredProduct]] = defaultdict(list)

        for product in self._catalog.products:
            category_info = map_category(product.purpose)
            if category_info is None:
                continue

            if not _matches_skin_type(product, skin_column):
                continue

            if product.price_segment != mapped_price:
                continue

            if not is_age_compatible(product.age_category, request.age):
                continue

            total_candidates += 1

            if has_allergy_conflict(product.ingredients, request.allergies):
                excluded_by_allergy += 1
                continue

            predicted_effectiveness = product.effectiveness_category
            try:
                predicted_effectiveness = self._evaluator.predict_effectiveness(
                    product.model_features()
                )
            except Exception:
                partial = True

            score = calculate_score(
                product=product,
                predicted_effectiveness=predicted_effectiveness,
                skin_column=skin_column,
                target_age_category=target_age_category,
            )
            scored_candidates += 1

            category_code, display_name = category_info
            product_id = build_product_id(product.brand, product.product_name)
            usage_guidance = None
            if category_code == "intensive_renewal":
                guidance_result = build_intensive_guidance(product)
                usage_guidance = guidance_result.guidance
                if guidance_result.is_fallback:
                    partial = True

            candidates_by_category[category_code].append(
                ScoredProduct(
                    category_code=category_code,
                    display_name=display_name,
                    product_id=product_id,
                    brand=product.brand,
                    product_name=product.product_name,
                    url=product.url,
                    score=score,
                    usage_guidance=usage_guidance,
                )
            )

        categories = _build_categories(candidates_by_category)
        if any(code not in {category.category_code for category in categories} for code in CATEGORY_ORDER):
            partial = True

        return RecommendationResult(
            categories=categories,
            partial=partial,
            meta=RecommendationMeta(
                total_candidates=total_candidates,
                scored_candidates=scored_candidates,
                excluded_by_allergy=excluded_by_allergy,
            ),
        )


def map_price_range(value: str) -> str:
    normalized = _normalize_text(value)
    return PRICE_RANGE_MAPPING.get(normalized, "Средний")


def map_age_category(age: int) -> str:
    if age < 25:
        return "18+"
    if age < 30:
        return "25+"
    if age < 35:
        return "30+"
    return "35+"


def map_skin_type(value: str) -> str:
    normalized = _normalize_text(value)
    return SKIN_TYPE_MAPPING.get(normalized, "Нормальная")


def map_category(value: str) -> tuple[str, str] | None:
    return CATEGORY_MAPPING.get(value.strip())


def is_age_compatible(product_age_category: str, age: int) -> bool:
    if product_age_category == "Для детей":
        return age < 18

    minimum_age = AGE_MATCH_MAPPING.get(product_age_category)
    if minimum_age is None:
        return True

    return age >= minimum_age


def has_allergy_conflict(ingredients: str, allergies: list[str]) -> bool:
    normalized_ingredients = f" {_normalize_ingredients(ingredients)} "
    for allergy in allergies:
        markers = ALLERGY_MARKERS.get(_normalize_text(allergy), ())
        if any(marker in normalized_ingredients for marker in markers):
            return True

    return False


def calculate_score(
    *,
    product: CatalogProduct,
    predicted_effectiveness: str,
    skin_column: str,
    target_age_category: str,
) -> float:
    score = EFFECTIVENESS_WEIGHTS.get(predicted_effectiveness, 1.0)

    if product.skin_flag(skin_column) >= 1.0:
        score += 1.0

    if product.age_category == target_age_category:
        score += 0.5

    score += product.rating / 10.0
    return score


def _matches_skin_type(product: CatalogProduct, skin_column: str) -> bool:
    return product.skin_flag(skin_column) >= 1.0 or product.universality >= 1.0


def _build_categories(
    candidates_by_category: dict[str, list[ScoredProduct]]
) -> list[RecommendationCategory]:
    categories: list[RecommendationCategory] = []

    for category_code in CATEGORY_ORDER:
        scored_products = candidates_by_category.get(category_code, [])
        if not scored_products:
            continue

        sorted_products = sorted(
            scored_products,
            key=lambda product: (-product.score, product.brand, product.product_name),
        )[:3]

        categories.append(
            RecommendationCategory(
                category_code=category_code,
                display_name=sorted_products[0].display_name,
                products=[
                    RecommendationProduct(
                        product_id=product.product_id,
                        brand=product.brand,
                        product_name=product.product_name,
                        url=product.url,
                        usage_guidance=product.usage_guidance,
                    )
                    for product in sorted_products
                ],
            )
        )

    return categories


def _normalize_text(value: str) -> str:
    return value.strip().lower()


def _normalize_ingredients(value: str) -> str:
    lowered = value.lower()
    return re.sub(r"\s+", " ", lowered)


def build_product_id(brand: str, product_name: str) -> str:
    base = _normalize_text(f"{brand} {product_name}")
    slug = re.sub(r"[^0-9a-zа-яё]+", "-", base).strip("-")
    return slug or "product"


def build_intensive_guidance(product: CatalogProduct) -> IntensiveGuidanceResult:
    active_family = detect_active_family(product)
    if active_family is None:
        return IntensiveGuidanceResult(
            guidance=INTENSIVE_GUIDANCE_BY_FAMILY["other_intensive"],
            is_fallback=True,
        )

    return IntensiveGuidanceResult(
        guidance=INTENSIVE_GUIDANCE_BY_FAMILY[active_family],
        is_fallback=False,
    )


def detect_active_family(product: CatalogProduct) -> str | None:
    normalized_blob = _normalize_ingredients(
        f"{product.brand} {product.product_name} {product.ingredients}"
    )

    for active_family, keywords in ACTIVE_FAMILY_KEYWORDS.items():
        if any(_keyword_matches(normalized_blob, keyword) for keyword in keywords):
            return active_family

    return None


def _keyword_matches(normalized_blob: str, keyword: str) -> bool:
    escaped_keyword = re.escape(keyword.lower())
    pattern = rf"(?<![0-9a-zа-яё]){escaped_keyword}(?![0-9a-zа-яё])"
    return re.search(pattern, normalized_blob) is not None
