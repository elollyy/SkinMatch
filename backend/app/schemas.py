from __future__ import annotations

from pydantic import BaseModel, Field


class CarePlanRequest(BaseModel):
    skinType: str = Field(min_length=1)
    age: int = Field(ge=0)
    allergies: list[str] = Field(default_factory=list)
    priceRange: str = Field(default="средний")


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=6)


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1)


class SkinProfilePayload(BaseModel):
    skinType: str = Field(min_length=1)
    age: int = Field(ge=0)
    allergies: list[str] = Field(default_factory=list)
    priceRange: str = Field(default="средний")


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    hasCompletedSurvey: bool = False
    skinProfile: SkinProfilePayload | None = None


class AuthResponse(BaseModel):
    accessToken: str
    tokenType: str = "bearer"
    user: UserResponse


class IntroductionPhaseResponse(BaseModel):
    weekStart: int = Field(ge=1)
    weekEnd: int | None = Field(default=None, ge=1)
    dayStart: int = Field(ge=1)
    dayEnd: int | None = Field(default=None, ge=1)
    allowedCycleDays: list[int] = Field(default_factory=list)
    label: str
    note: str | None = None


class IntroductionSchemeResponse(BaseModel):
    cycleLengthDays: int = Field(ge=1)
    phases: list[IntroductionPhaseResponse] = Field(default_factory=list)
    startWithEveningOnly: bool = True


class CompatibilityConflictResponse(BaseModel):
    label: str
    explanation: str
    categoryCodes: list[str] = Field(default_factory=list)
    activeFamilies: list[str] = Field(default_factory=list)


class UsageGuidanceResponse(BaseModel):
    activeFamily: str
    displayLabel: str
    introductionScheme: IntroductionSchemeResponse
    conflicts: list[CompatibilityConflictResponse] = Field(default_factory=list)
    applicationTips: list[str] = Field(default_factory=list)


class ProductResponse(BaseModel):
    productId: str
    brand: str
    productName: str
    url: str
    usageGuidance: UsageGuidanceResponse | None = None


class CategoryResponse(BaseModel):
    categoryCode: str
    displayName: str
    products: list[ProductResponse]


class CarePlanMetaResponse(BaseModel):
    totalCandidates: int
    scoredCandidates: int
    excludedByAllergy: int


class CarePlanResponse(BaseModel):
    categories: list[CategoryResponse]
    partial: bool
    meta: CarePlanMetaResponse
