"""Point d'entrée : uvicorn --factory app.main:create_app"""

from __future__ import annotations

import logging
import mimetypes
import time
from http import HTTPStatus
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.sessions import SessionMiddleware
from starlette.responses import RedirectResponse

from . import contact, db, render
from .config import Settings
from .routes_admin import LoginRequired
from .routes_admin import router as admin_router
from .routes_public import router as public_router
from .security import BodySizeLimitMiddleware, LoginLimiter, SecurityHeadersMiddleware

APP_DIR = Path(__file__).resolve().parent

# Python 3.12 ne connaît pas toujours .woff2 (selon /etc/mime.types) : sans
# cela, StaticFiles servirait les polices en text/plain.
mimetypes.add_type("font/woff2", ".woff2")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()

    db.init_db(settings.db_path, settings.images_dir)
    settings.images_dir.mkdir(parents=True, exist_ok=True)
    settings.apk_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(debug=False, docs_url=None, redoc_url=None, openapi_url=None)
    app.state.settings = settings
    app.state.templates = render.make_templates(APP_DIR / "templates")
    app.state.login_limiter = LoginLimiter(
        settings.login_max_attempts, settings.login_window_seconds
    )
    # Formulaire de contact : horloge (remplaçable dans les tests) et limitations.
    app.state.contact_clock = time.time
    app.state.contact_limiter = LoginLimiter(settings.contact_max_per_hour, 3600)
    app.state.contact_global_limiter = LoginLimiter(settings.contact_global_per_hour, 3600)

    # Journaux de l'application (notification SMTP…) dans la sortie standard,
    # visibles avec docker compose logs.
    app_log = logging.getLogger("tilto")
    if not app_log.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(levelname)s %(name)s: %(message)s"))
        app_log.addHandler(handler)
        app_log.setLevel(logging.INFO)

    app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")
    app.include_router(public_router)
    app.include_router(admin_router)

    # Les middlewares ajoutés en dernier s'exécutent en premier.
    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.secret_key,
        session_cookie="tilto_admin",
        max_age=settings.session_max_age,
        path="/admin",  # les pages publiques ne reçoivent jamais de cookie
        same_site="lax",
        https_only=settings.cookie_secure,
    )
    form_margin = 1024 * 1024
    app.add_middleware(
        BodySizeLimitMiddleware,
        default_limit=settings.max_image_bytes + form_margin,
        path_limits={"/admin/apk/deposer": settings.max_apk_bytes + form_margin,
                     "/contact": contact.MAX_BODY_BYTES},
    )
    app.add_middleware(SecurityHeadersMiddleware, hsts=settings.cookie_secure)

    @app.exception_handler(LoginRequired)
    async def _login_required(request: Request, exc: LoginRequired):
        return RedirectResponse("/admin/connexion", status_code=303)

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(request: Request, exc: StarletteHTTPException):
        messages = {
            403: "Action refusée. Rechargez la page et réessayez.",
            404: "Cette page n'existe pas.",
            405: "Méthode non autorisée.",
            429: "Trop de tentatives. Réessayez plus tard.",
        }
        # Les messages par défaut de Starlette (« Not Found »…) sont en anglais :
        # on ne garde que ceux écrits par l'application.
        message = exc.detail if exc.detail != HTTPStatus(exc.status_code).phrase else None
        return render.page(
            request, "error.html",
            {"status": exc.status_code,
             "message": message or messages.get(exc.status_code, "Erreur.")},
            status_code=exc.status_code,
            headers=getattr(exc, "headers", None),
        )

    return app
