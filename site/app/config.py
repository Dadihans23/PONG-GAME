"""Configuration lue dans les variables d'environnement (fichier .env).

Aucun secret n'a de valeur par défaut : l'application refuse de démarrer
sans SECRET_KEY ni ADMIN_PASSWORD_HASH.
"""

from __future__ import annotations

import os
import re
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


def _site_url(value: str | None) -> str:
    url = (value or "").strip().rstrip("/") or "https://tilto.fun"
    if not re.fullmatch(r"https?://[A-Za-z0-9.-]+(:[0-9]+)?", url):
        raise ConfigError("SITE_URL doit être une adresse comme https://tilto.fun (sans chemin)")
    return url


@dataclass(frozen=True)
class SmtpConfig:
    """Notification par e-mail des messages de contact (facultative)."""
    host: str
    port: int
    user: str
    password: str
    sender: str
    notify_to: str
    security: str  # "ssl" (SMTPS, port 465) ou "starttls"

    @classmethod
    def from_env(cls, env: dict[str, str]) -> "SmtpConfig | None":
        host = env.get("SMTP_HOST", "").strip()
        sender = env.get("SMTP_FROM", "").strip()
        notify_to = env.get("CONTACT_NOTIFY_TO", "").strip()
        if not (host and sender and notify_to):
            return None  # notification désactivée
        port = _int("SMTP_PORT", env.get("SMTP_PORT"), 587)
        security = env.get("SMTP_SECURITY", "").strip().lower() or (
            "ssl" if port == 465 else "starttls")
        if security not in {"ssl", "starttls"}:
            raise ConfigError("SMTP_SECURITY doit valoir ssl ou starttls")
        for name, value in (("SMTP_FROM", sender), ("CONTACT_NOTIFY_TO", notify_to)):
            if "@" not in value or any(c in value for c in "\r\n"):
                raise ConfigError(f"{name} doit être une adresse e-mail")
        return cls(host=host, port=port, user=env.get("SMTP_USER", "").strip(),
                   password=env.get("SMTP_PASSWORD", ""), sender=sender,
                   notify_to=notify_to, security=security)


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
    # Formulaire de contact
    contact_max_per_hour: int = 3       # messages acceptés par IP et par heure
    contact_global_per_hour: int = 30   # tous visiteurs confondus
    contact_min_seconds: int = 3        # délai minimal entre affichage et envoi
    smtp: SmtpConfig | None = None
    # Adresse publique du site, sans « / » final : URL canoniques, sitemap,
    # Open Graph, données structurées. Jamais déduite de l'en-tête Host.
    site_url: str = "https://tilto.fun"

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
            contact_max_per_hour=_int(
                "CONTACT_MAX_PER_HOUR", env.get("CONTACT_MAX_PER_HOUR"), 3),
            contact_global_per_hour=_int(
                "CONTACT_GLOBAL_PER_HOUR", env.get("CONTACT_GLOBAL_PER_HOUR"), 30),
            contact_min_seconds=_int(
                "CONTACT_MIN_SECONDS", env.get("CONTACT_MIN_SECONDS"), 3),
            smtp=SmtpConfig.from_env(env),
            site_url=_site_url(env.get("SITE_URL")),
        )
