"""Configuration lue dans les variables d'environnement (fichier .env).

Aucun secret n'a de valeur par défaut : l'application refuse de démarrer
sans SECRET_KEY ni ADMIN_PASSWORD_HASH.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


class ConfigError(RuntimeError):
    """Configuration absente ou invalide."""


def _bool(value: str | None, default: bool) -> bool:
    if value is None or value.strip() == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "oui", "on"}


def _int(name: str, value: str | None, default: int) -> int:
    if value is None or value.strip() == "":
        return default
    try:
        number = int(value)
    except ValueError as exc:
        raise ConfigError(f"{name} doit être un nombre entier") from exc
    if number <= 0:
        raise ConfigError(f"{name} doit être positif")
    return number


@dataclass(frozen=True)
class Settings:
    secret_key: str
    admin_password_hash: str
    data_dir: Path
    cookie_secure: bool = False
    session_max_age: int = 8 * 3600
    max_apk_mb: int = 200
    max_image_mb: int = 5
    login_max_attempts: int = 5
    login_window_seconds: int = 15 * 60

    @property
    def db_path(self) -> Path:
        return self.data_dir / "tilto.sqlite3"

    @property
    def images_dir(self) -> Path:
        return self.data_dir / "uploads" / "images"

    @property
    def apk_dir(self) -> Path:
        return self.data_dir / "uploads" / "apk"

    @property
    def max_apk_bytes(self) -> int:
        return self.max_apk_mb * 1024 * 1024

    @property
    def max_image_bytes(self) -> int:
        return self.max_image_mb * 1024 * 1024

    @classmethod
    def from_env(cls, env: dict[str, str] | None = None) -> "Settings":
        env = dict(os.environ if env is None else env)
        secret = env.get("SECRET_KEY", "").strip()
        if len(secret) < 32:
            raise ConfigError(
                "SECRET_KEY manquante ou trop courte (32 caractères minimum). "
                "Générez-la avec : python -m app.hashpw --secret"
            )
        pw_hash = env.get("ADMIN_PASSWORD_HASH", "").strip()
        if not pw_hash.startswith("scrypt:"):
            raise ConfigError(
                "ADMIN_PASSWORD_HASH manquant ou invalide. "
                "Générez-le avec : python -m app.hashpw"
            )
        return cls(
            secret_key=secret,
            admin_password_hash=pw_hash,
            data_dir=Path(env.get("DATA_DIR", "./data")).resolve(),
            cookie_secure=_bool(env.get("COOKIE_SECURE"), False),
            session_max_age=_int("SESSION_MAX_AGE", env.get("SESSION_MAX_AGE"), 8 * 3600),
            max_apk_mb=_int("MAX_APK_MB", env.get("MAX_APK_MB"), 200),
            max_image_mb=_int("MAX_IMAGE_MB", env.get("MAX_IMAGE_MB"), 5),
            login_max_attempts=_int("LOGIN_MAX_ATTEMPTS", env.get("LOGIN_MAX_ATTEMPTS"), 5),
            login_window_seconds=_int(
                "LOGIN_WINDOW_SECONDS", env.get("LOGIN_WINDOW_SECONDS"), 15 * 60
            ),
        )
