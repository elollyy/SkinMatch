from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    host: str
    port: int
    model_path: Path
    dataset_path: Path
    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str
    jwt_access_token_expire_minutes: int
    cors_allowed_origins: tuple[str, ...]
    cors_allowed_origin_regex: str


def _read_csv_env(name: str) -> tuple[str, ...]:
    raw_value = os.getenv(name, "")
    values = [value.strip() for value in raw_value.split(",")]
    return tuple(value for value in values if value)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    app_dir = Path(__file__).resolve().parent
    backend_dir = app_dir.parent
    repo_root = backend_dir.parent

    return Settings(
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        model_path=Path(
            os.getenv(
                "MODEL_PATH",
                str(repo_root / "SANN_PMML_Code_cosmetics-2.xml"),
            )
        ),
        dataset_path=Path(
            os.getenv("DATASET_PATH", str(repo_root / "cosmetics.csv"))
        ),
        database_url=os.getenv(
            "DATABASE_URL",
            f"sqlite:///{backend_dir / 'skinmatch.db'}",
        ),
        jwt_secret_key=os.getenv(
            "JWT_SECRET_KEY",
            "change-this-secret-for-local-development-only",
        ),
        jwt_algorithm=os.getenv("JWT_ALGORITHM", "HS256"),
        jwt_access_token_expire_minutes=int(
            os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "1440")
        ),
        cors_allowed_origins=_read_csv_env("CORS_ALLOWED_ORIGINS"),
        cors_allowed_origin_regex=os.getenv(
            "CORS_ALLOWED_ORIGIN_REGEX",
            r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        ),
    )
