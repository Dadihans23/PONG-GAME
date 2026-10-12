"""API lue par l'application mobile.

GET /api/app/studio : nom, présentation et logo du studio, que l'app affiche
(page Le studio) et met en cache. Lecture seule, sans cookie, sans effet de bord.
Contrat fixé avec l'app (schema 1) : ne pas renommer ni retirer de champ.

Toutes les URL absolues partent de `Settings.site_url` (réglage SITE_URL),
jamais de l'hôte de la requête.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response

from . import db
from .routes_public import get_conn
from .uploads import IMAGE_TYPES, STORED_NAME, image_size

router = APIRouter(prefix="/api")

SCHEMA_VERSION = 1

# Formats que l'app sait afficher. Un logo SVG ou GIF reste sur le site, mais
# l'API renvoie alors "logo": null.
APP_LOGO_TYPES = ("png", "jpg", "webp")

# Date renvoyée quand la page Studio n'a jamais été enregistrée et qu'il n'y a
# pas de logo : une valeur fixe, jamais l'heure de l'appel.
FALLBACK_UPDATED_AT = "2026-10-12T00:00:00+00:00"

CACHE_CONTROL = "public, max-age=3600"


@lru_cache(maxsize=16)
def _file_sha256(path: str, mtime_ns: int, size: int) -> str:
    """Empreinte d'un fichier ; mtime et taille dans la clé : recalculée s'il change."""
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def logo_info(images_dir: Path, name: str, site_url: str) -> dict | None:
    """Logo pour l'app, ou None (pas de logo, format non affichable, fichier absent)."""
    if not name or not STORED_NAME.match(name):
        return None
    ext = name.rsplit(".", 1)[1]
    if ext not in APP_LOGO_TYPES:
        return None
    path = images_dir / name
    try:
        stat = path.stat()
    except OSError:
        return None
    size = image_size(path)
    if not size or not size[0] or not size[1]:
        return None
    return {
        "url": f"{site_url}/media/{name}",
        "sha256": _file_sha256(str(path), stat.st_mtime_ns, stat.st_size),
        "width": size[0],
        "height": size[1],
        "content_type": IMAGE_TYPES[ext],
    }


def _updated_at(conn: sqlite3.Connection, images_dir: Path, logo_name: str) -> str:
    """Dernier enregistrement de la page Studio ; à défaut, date du fichier du logo ;
    à défaut, une date fixe."""
    saved = db.get_internal(conn, "_saved:studio")
    if saved:
        return saved
    if logo_name and STORED_NAME.match(logo_name):
        try:
            mtime = (images_dir / logo_name).stat().st_mtime
        except OSError:
            pass
        else:
            return datetime.fromtimestamp(int(mtime), timezone.utc).isoformat()
    return FALLBACK_UPDATED_AT


def studio_payload(conn: sqlite3.Connection, images_dir: Path, site_url: str) -> dict:
    site = db.get_settings(conn)
    logo_name = site.get("studio_logo", "")
    return {
        "schema": SCHEMA_VERSION,
        "studio": {
            "name": site.get("studio_name", "").strip() or "Nexora",
            "about": site.get("studio_about", "").strip(),
            "website": site_url,
            "contact_url": f"{site_url}/contact",
        },
        "logo": logo_info(images_dir, logo_name, site_url),
        "updated_at": _updated_at(conn, images_dir, logo_name),
    }


def _etag_matches(header: str | None, etag: str) -> bool:
    if not header:
        return False
    for candidate in header.split(","):
        candidate = candidate.strip()
        if candidate == "*" or candidate.removeprefix("W/") == etag:
            return True
    return False


@router.api_route("/app/studio", methods=["GET", "HEAD"])
def app_studio(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    payload = studio_payload(conn, settings.images_dir, settings.site_url)
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    etag = '"' + hashlib.sha256(body).hexdigest()[:32] + '"'
    headers = {"Cache-Control": CACHE_CONTROL, "ETag": etag, "X-Robots-Tag": "noindex"}
    if _etag_matches(request.headers.get("if-none-match"), etag):
        return Response(status_code=304, headers=headers)
    return Response(body, media_type="application/json; charset=utf-8", headers=headers)
