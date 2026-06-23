# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SkinMatch is a Flutter app for personalized skincare recommendations. It has two main components:

- **Flutter frontend** (`lib/`) — mobile/web/desktop UI with Provider-based state management
- **Python FastAPI backend** (`backend/`) — serves care plan recommendations using a PMML ML model scored against a CSV product catalog

## Commands

### Flutter

```bash
flutter pub get          # install dependencies
flutter run -d linux     # run on Linux desktop (zero-config in debug mode)
flutter analyze          # static analysis
flutter test             # widget/unit tests
flutter build apk        # Android APK
flutter build web        # web build
dart format .            # format all Dart files
```

Run a single test file:
```bash
flutter test test/widget_test.dart
```

### Backend

```bash
# From repo root — activate the venv in backend/
source backend/.venv/bin/activate
pip install -r backend/requirements.txt

# Start the server
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000

# Run backend tests (from repo root with venv active)
python -m pytest backend/tests/
# or with unittest discovery
python -m unittest discover -s backend/tests
```

Check the backend is healthy:
```bash
curl http://127.0.0.1:8000/health
```

### Database migrations (Alembic)

```bash
# Run from backend/ directory with venv active
cd backend
alembic upgrade head          # apply all pending migrations
alembic revision --autogenerate -m "description"  # generate a new migration
alembic downgrade -1          # roll back one migration
```

The startup event also runs `_ensure_user_profile_columns()` which manually adds missing columns to an existing `users` table — this is a fallback for databases created before Alembic was introduced.

### Running with a backend

```bash
# Linux debug (default: 127.0.0.1:8000 is auto-configured in debug mode)
flutter run -d linux

# Android emulator
flutter run -d android --dart-define=CARE_PLAN_API_URL=http://10.0.2.2:8000

# Demo mock (no backend needed)
flutter run --dart-define=CARE_PLAN_ALLOW_MOCK_FALLBACK=true
```

## Architecture

### Flutter app

**Startup & routing** (`lib/main.dart`)  
`UserService`, `ThemeService`, and `BackendConfigService` are loaded before `runApp`. Routing is handled via `onGenerateRoute` with zero transition duration. The initial screen is derived from `UserService` state: unauthenticated → `WelcomeScreen`; authenticated but no survey → `SurveyScreen`; otherwise → `AppShell`. Named routes include `/login`, `/register`, `/survey`, `/history`, `/settings`, `/backend`, `/theme`, and tab shortcuts `/home`, `/care`, `/result`, `/profile`.

**AppShell** (`lib/screens/app_shell.dart`)  
Four-tab bottom navigation: Home (0), Care/Result (1), Intensive Course (2), Profile (3). Navigate to a specific tab or course product via `Navigator.pushNamed('/course', arguments: productId)`.

**State management** (Provider)  
- `UserService` — persists user, auth token, and skin profile to `SharedPreferences`; exposes `register`, `login`, `logout`, `completeSurvey`, `loadCurrentUser`; validates stored JWT against `/api/v1/auth/me` on startup and clears local state if invalid
- `ThemeService` — persists theme mode and accent color
- `BackendConfigService` — stores the backend API URL (overrides the compile-time `CARE_PLAN_API_URL` env var); auto-defaults to `http://127.0.0.1:8000` on Linux debug builds
- `CarePlanService` — a `ProxyProvider` that reconstructs whenever `BackendConfigService.apiUrl` changes; holds all recommendation-fetching and response-parsing logic

**HTTP transport** (`lib/services/care_plan_transport.dart`)  
Conditional export: uses `dart:html` fetch on web, `dart:io` `HttpClient` on native. Both implement `postJson(Uri, Map)`.

**Care plan flow**  
`CarePlanService.fetchPlanResult(SkinProfile)` → maps skin type and price range to backend vocabulary → POST `/api/v1/care-plan` → parses and sorts categories by `_categoryOrder` → returns `CarePlanFetchResult`. Up to 3 products per category are kept. Products in `intensive_renewal` include `UsageGuidance` with a phased introduction scheme.

**Data models** (`lib/models/user_model.dart`)  
`UserModel`, `SkinProfile`, `CarePlan`, `CareCategory`, `ProductRecommendation`, `UsageGuidance`, `IntroductionScheme`, `IntroductionPhase`, `CompatibilityConflict`, `CarePlanMeta`.

### Python backend

**Entry point** (`backend/app/main.py`)  
FastAPI app with CORS middleware. Endpoints:
- `GET /health` — readiness check with catalog/model stats
- `POST /api/v1/auth/register` — creates a user, returns `AuthResponse` (token + user)
- `POST /api/v1/auth/login` — returns `AuthResponse`
- `GET /api/v1/auth/me` — returns `UserResponse` (requires `Authorization: Bearer <token>`)
- `POST /api/v1/auth/profile` — saves the skin profile to `User.skin_profile_json`
- `POST /api/v1/care-plan` — returns `CarePlanResponse` (no auth required)

The `RecommendationEngine` and product catalog are instantiated once via `@lru_cache`.

**Database** (`backend/app/database.py`, `backend/app/db_models.py`)  
SQLAlchemy + SQLite (default `backend/skinmatch.db`). Models: `User` (auth + skin profile), `Product`, `Marketplace`, `ProductMarketplaceLink`. Schema is created on startup via `Base.metadata.create_all`. Alembic manages migrations from `backend/alembic/`.

**Auth** (`backend/app/auth.py`)  
JWT HS256 tokens via `python-jose`. `get_current_user` is a FastAPI dependency used on protected routes. Key env vars: `JWT_SECRET_KEY` (change in production), `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` (default 1440), `DATABASE_URL` (default SQLite).

**Product links** (`backend/app/product_links.py`)  
`load_primary_product_links(db, product_ids)` queries the DB for `is_primary=True` marketplace URLs and returns a dict that `/api/v1/care-plan` uses to override the CSV-sourced `url` field on each product.

**Data sources** (repo root)  
- `cosmetics.csv` — product catalog (loaded by `backend/app/catalog.py`)
- `SANN_PMML_Code_cosmetics-2.xml` — PMML neural-net model (loaded by `backend/app/model.py` via `pypmml`)

Both paths are configurable via `MODEL_PATH` / `DATASET_PATH` env vars.

**Recommendation pipeline** (`backend/app/recommendation.py`)  
`RecommendationEngine.build(RecommendationRequest)` filters the catalog by skin type, price segment, and age compatibility, excludes allergy conflicts, scores candidates with `calculate_score` (PMML effectiveness prediction + skin flag + age match + rating), then returns the top-3 products per category in `CATEGORY_ORDER`. Products in `intensive_renewal` get `UsageGuidance` based on detected active family (retinoid / acid / spicule / other).

**Config** (`backend/app/config.py`)  
Settings are frozen dataclasses loaded via `get_settings()`. Key env vars beyond `MODEL_PATH` / `DATASET_PATH`: `DATABASE_URL` (default SQLite at `backend/skinmatch.db`), `JWT_SECRET_KEY` (must be changed for production), `JWT_ALGORITHM` (default `HS256`), `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` (default 1440), `CORS_ALLOWED_ORIGINS` (comma-separated), `CORS_ALLOWED_ORIGIN_REGEX` (default allows `localhost` and `127.0.0.1` on any port).

## Key conventions

- Dart: 2-space indent, `snake_case` files, `PascalCase` classes, `lowerCamelCase` vars/methods
- Lint rules enforced via `flutter_lints`; run `flutter analyze` before committing
- Backend uses `python-dotenv`-free config — all settings via env vars or defaults in `config.py`
- The `partial: true` flag on a `CarePlanResponse` means results may be incomplete (missing categories, PMML unavailable, catalog parse errors); the Flutter client shows a warning but still renders available categories
- Backend tests use `unittest` and can also be discovered with `pytest`; they stub `RecommendationEngine` to avoid touching the CSV/PMML files
