"""Pages publiques : présentation, confidentialité, téléchargement, santé."""

from __future__ import annotations

import re
import sqlite3
from collections.abc import Iterator
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse

from . import db, render
from .uploads import IMAGE_TYPES, STORED_NAME

router = APIRouter()

APK_MIME = "application/vnd.android.package-archive"


def get_conn(request: Request) -> Iterator[sqlite3.Connection]:
    yield from db.get_db(request.app.state.settings.db_path)


def site_context(conn: sqlite3.Connection) -> dict:
    site = db.get_settings(conn)
    logo = site.get("studio_logo", "")
    site["studio_logo_url"] = f"/media/{logo}" if logo else ""
    return {
        "site": site,
        "year": datetime.now().year,
        # L'APK courant sert au héros, au bloc final et au lien de navigation.
        "apk": db.current_apk(conn),
    }


@router.api_route("/", methods=["GET", "HEAD"])
def home(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    context = site_context(conn)
    context.update(
        features=db.list_items(conn, "feature"),
        steps=db.list_items(conn, "step"),
        screenshots=db.list_screenshots(conn),
    )
    return render.page(request, "index.html", context)


@router.api_route("/confidentialite", methods=["GET", "HEAD"])
def privacy(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    return render.page(request, "privacy.html", site_context(conn))


def download_name(game_name: str, version: str) -> str:
    base = re.sub(r"[^A-Za-z0-9_-]", "", game_name) or "Tilto"
    return f"{base}-{version}.apk"


@router.api_route("/telecharger", methods=["GET", "HEAD"])
def download(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    apk = db.current_apk(conn)
    settings = request.app.state.settings
    path = settings.apk_dir / apk["filename"] if apk else None
    if apk is None or not path.is_file():
        raise HTTPException(404, "Aucune version de l'application n'est disponible pour le moment.")
    game = db.get_settings(conn).get("game_name", "Tilto")
    return FileResponse(
        path,
        media_type=APK_MIME,
        filename=download_name(game, apk["version"]),
        headers={"Cache-Control": "no-cache", "X-Checksum-SHA256": apk["sha256"]},
    )


@router.get("/media/{name}")
def media(name: str, request: Request):
    """Images téléversées (logo, captures). Le nom est vérifié strictement."""
    if not STORED_NAME.match(name) or name.endswith(".apk"):
        raise HTTPException(404)
    path = request.app.state.settings.images_dir / name
    if not path.is_file():
        raise HTTPException(404)
    ext = name.rsplit(".", 1)[1]
    headers = {"Cache-Control": "public, max-age=31536000, immutable"}
    if ext == "svg":
        # Un SVG ouvert directement ne doit rien pouvoir exécuter.
        headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    return FileResponse(path, media_type=IMAGE_TYPES[ext], headers=headers)


@router.api_route("/sante", methods=["GET", "HEAD"])
def health(request: Request):
    try:
        conn = db.connect(request.app.state.settings.db_path)
        try:
            conn.execute("SELECT 1").fetchone()
        finally:
            conn.close()
    except sqlite3.Error:
        return JSONResponse({"status": "erreur"}, status_code=503)
    return {"status": "ok"}
