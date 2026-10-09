"""Administration : connexion, contenu, studio, captures, APK."""

from __future__ import annotations

import re
import sqlite3
import time
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import UploadFile

from . import db, render
from .routes_public import get_conn
from .security import csrf_token, csrf_valid, password_fingerprint, verify_password
from .uploads import VERSION_RE, UploadError, delete_file, save_apk, save_image

router = APIRouter(prefix="/admin")


class LoginRequired(Exception):
    """Levée quand une page d'administration est demandée sans session valide."""


LISTS = {
    "arguments": {"kind": "feature", "title": "Arguments (section « Le jeu »)",
                  "item": "argument", "kicker": True, "body_label": "Texte"},
    "etapes": {"kind": "step", "title": "Comment jouer",
               "item": "étape", "kicker": False, "body_label": "Précision (facultatif)"},
}

# clé : (libellé, longueur maximale, zone de texte sur plusieurs lignes)
TEXT_FIELDS = {
    "game_name": ("Nom du jeu (titre du héros)", 60, False),
    "tagline": ("Accroche du héros", 300, True),
    "hero_note": ("Mention sous les boutons (ex. « Gratuit · Android »)", 80, False),
    "download_title": ("Titre du bloc de téléchargement", 80, False),
    "download_text": ("Phrase du bloc de téléchargement", 300, True),
    "play_store_url": ("Lien Play Store (https://…, vide = bouton masqué)", 500, False),
    "contact_email": ("Adresse de contact (lien « Contact » du pied de page)", 200, False),
}

def valid_date(value: str) -> bool:
    """Date AAAA-MM-JJ (champ <input type="date">)."""
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return len(value) == 10

EMAIL_RE = re.compile(r"^[^@\s<>\"']+@[^@\s<>\"']+\.[^@\s<>\"']+$")


# --- Session et protections ----------------------------------------------------

def is_admin(request: Request) -> bool:
    session = request.session
    settings = request.app.state.settings
    if not session.get("admin"):
        return False
    if session.get("pwfp") != password_fingerprint(settings.admin_password_hash):
        return False  # mot de passe changé depuis la connexion
    return time.time() - session.get("login_at", 0) < settings.session_max_age


def require_admin(request: Request) -> None:
    if not is_admin(request):
        request.session.pop("admin", None)
        raise LoginRequired


async def form_with_csrf(request: Request):
    form = await request.form()
    token = form.get("csrf_token")
    if not csrf_valid(request, token if isinstance(token, str) else None):
        raise HTTPException(403, "Jeton de sécurité invalide ou expiré. Rechargez la page et réessayez.")
    return form


async def admin_form(request: Request):
    """Pour chaque POST d'administration : session valide puis jeton CSRF."""
    require_admin(request)
    return await form_with_csrf(request)


def admin_page(request: Request, name: str, context: dict | None = None, status_code: int = 200):
    context = dict(context or {})
    context["csrf"] = csrf_token(request)
    return render.page(request, name, context, status_code=status_code)


def back(url: str) -> RedirectResponse:
    return RedirectResponse(url, status_code=303)


def text(form, key: str, max_len: int) -> str:
    value = form.get(key, "")
    value = value if isinstance(value, str) else ""
    return value.replace("\r\n", "\n").strip()[:max_len]


def upload(form, key: str) -> UploadFile | None:
    value = form.get(key)
    if isinstance(value, UploadFile) and value.filename:
        return value
    return None


# --- Connexion -----------------------------------------------------------------

@router.get("/connexion")
def login_page(request: Request):
    if is_admin(request):
        return back("/admin")
    return admin_page(request, "admin/login.html")


@router.post("/connexion")
async def login(request: Request):
    form = await form_with_csrf(request)
    settings = request.app.state.settings
    limiter = request.app.state.login_limiter
    ip = request.client.host if request.client else "inconnu"
    if limiter.blocked(ip):
        raise HTTPException(429, "Trop de tentatives de connexion. Réessayez dans quelques minutes.")
    password = form.get("password")
    if isinstance(password, str) and await run_in_threadpool(
        verify_password, password, settings.admin_password_hash
    ):
        limiter.reset(ip)
        request.session.clear()  # nouvelle session, nouveau jeton CSRF
        request.session.update(
            admin=True, login_at=int(time.time()),
            pwfp=password_fingerprint(settings.admin_password_hash),
        )
        return back("/admin")
    limiter.fail(ip)
    return admin_page(request, "admin/login.html",
                      {"error": "Mot de passe incorrect."}, status_code=401)


@router.post("/deconnexion")
async def logout(request: Request):
    await form_with_csrf(request)
    request.session.clear()
    return back("/admin/connexion")


# --- Tableau de bord ----------------------------------------------------------

@router.get("")
def dashboard(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/dashboard.html", {
        "site": db.get_settings(conn),
        "apk": db.current_apk(conn),
        "n_screens": len(db.list_screenshots(conn)),
    })


# --- Textes -----------------------------------------------------------------------

@router.get("/textes")
def texts_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/texts.html",
                      {"site": db.get_settings(conn), "fields": TEXT_FIELDS})


@router.post("/textes")
def texts_save(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    values = {key: text(form, key, max_len) for key, (_, max_len, _) in TEXT_FIELDS.items()}
    errors = []
    if not values["game_name"]:
        errors.append("Le nom du jeu est obligatoire.")
    if values["play_store_url"] and not values["play_store_url"].startswith("https://"):
        errors.append("Le lien Play Store doit commencer par https://")
    if values["contact_email"] and not EMAIL_RE.match(values["contact_email"]):
        errors.append("L'adresse de contact n'est pas valide.")
    if errors:
        return admin_page(request, "admin/texts.html",
                          {"site": values, "fields": TEXT_FIELDS, "errors": errors},
                          status_code=400)
    db.set_settings(conn, values)
    render.flash(request, "Textes enregistrés.")
    return back("/admin/textes")


# --- Studio -----------------------------------------------------------------------

@router.get("/studio")
def studio_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/studio.html", {"site": db.get_settings(conn)})


@router.post("/studio")
def studio_save(request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    current = db.get_settings(conn)
    name = text(form, "studio_name", 60)
    if not name:
        render.flash(request, "Le nom du studio est obligatoire.", "error")
        return back("/admin/studio")
    values = {"studio_name": name}
    old_logo = current.get("studio_logo", "")
    logo = upload(form, "logo")
    if logo:
        try:
            values["studio_logo"] = save_image(logo.file, settings.images_dir,
                                               settings.max_image_bytes, allow_svg=True)
        except UploadError as exc:
            render.flash(request, str(exc), "error")
            return back("/admin/studio")
    elif form.get("remove_logo"):
        values["studio_logo"] = ""
    db.set_settings(conn, values)
    if "studio_logo" in values and old_logo:
        delete_file(settings.images_dir, old_logo)
    render.flash(request, "Studio enregistré.")
    return back("/admin/studio")


# --- Confidentialité ---------------------------------------------------------

@router.get("/confidentialite")
def privacy_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/privacy.html", {"site": db.get_settings(conn)})


@router.post("/confidentialite")
def privacy_save(request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    updated = text(form, "privacy_updated", 10)
    if not valid_date(updated):
        render.flash(request, "Date de mise à jour invalide.", "error")
        return back("/admin/confidentialite")
    db.set_settings(conn, {"privacy_policy": text(form, "privacy_policy", 50_000),
                           "privacy_updated": updated})
    render.flash(request, "Politique de confidentialité enregistrée.")
    return back("/admin/confidentialite")


# --- Listes : arguments et étapes ----------------------------------------------

def list_conf(slug: str) -> dict:
    conf = LISTS.get(slug)
    if conf is None:
        raise HTTPException(404)
    return conf


@router.get("/listes/{slug}")
def list_page(slug: str, request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    conf = list_conf(slug)
    return admin_page(request, "admin/list.html",
                      {"slug": slug, "conf": conf, "items": db.list_items(conn, conf["kind"])})


@router.post("/listes/{slug}/ajouter")
def list_add(slug: str, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    title = text(form, "title", 120)
    if not title:
        render.flash(request, "Le titre est obligatoire.", "error")
        return back(f"/admin/listes/{slug}")
    with conn:
        conn.execute(
            "INSERT INTO content_item (kind, position, kicker, title, body)"
            " VALUES (?, ?, ?, ?, ?)",
            (kind, db.next_position(conn, "content_item", "kind = ?", (kind,)),
             text(form, "kicker", 40), title, text(form, "body", 1000)),
        )
    render.flash(request, "Élément ajouté.")
    return back(f"/admin/listes/{slug}")


@router.post("/listes/{slug}/{item_id}/modifier")
def list_edit(slug: str, item_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    title = text(form, "title", 120)
    if not title:
        render.flash(request, "Le titre est obligatoire.", "error")
        return back(f"/admin/listes/{slug}")
    with conn:
        conn.execute(
            "UPDATE content_item SET kicker = ?, title = ?, body = ? WHERE id = ? AND kind = ?",
            (text(form, "kicker", 40), title, text(form, "body", 1000), item_id, kind))
    render.flash(request, "Élément modifié.")
    return back(f"/admin/listes/{slug}")


@router.post("/listes/{slug}/{item_id}/supprimer")
def list_delete(slug: str, item_id: int, request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    with conn:
        conn.execute("DELETE FROM content_item WHERE id = ? AND kind = ?", (item_id, kind))
    render.flash(request, "Élément supprimé.")
    return back(f"/admin/listes/{slug}")


@router.post("/listes/{slug}/{item_id}/deplacer")
def list_move(slug: str, item_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    direction = -1 if form.get("direction") == "up" else 1
    db.move(conn, "content_item", item_id, direction, "kind = ?", (kind,))
    return back(f"/admin/listes/{slug}")


# --- Captures d'écran ------------------------------------------------------------

@router.get("/captures")
def screens_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/screenshots.html",
                      {"screenshots": db.list_screenshots(conn)})


def _screenshot_image(request: Request, form) -> str | None:
    """Image de capture envoyée avec le formulaire : nom enregistré, ou None.
    Lève UploadError si le fichier est refusé."""
    image = upload(form, "image")
    if image is None:
        return None
    settings = request.app.state.settings
    return save_image(image.file, settings.images_dir, settings.max_image_bytes, allow_svg=False)


@router.post("/captures/ajouter")
def screens_add(request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    caption = text(form, "caption", 120)
    try:
        name = _screenshot_image(request, form)
    except UploadError as exc:
        render.flash(request, str(exc), "error")
        return back("/admin/captures")
    if name is None and not caption:
        render.flash(request, "Choisissez une image ou saisissez une légende.", "error")
        return back("/admin/captures")
    with conn:
        conn.execute(
            "INSERT INTO screenshot (filename, caption, position, created_at)"
            " VALUES (?, ?, ?, ?)",
            (name, caption, db.next_position(conn, "screenshot"), db.now_iso()),
        )
    render.flash(request, "Capture ajoutée.")
    return back("/admin/captures")


@router.post("/captures/{shot_id}/modifier")
def screens_edit(shot_id: int, request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    """Modifie la légende et, si un fichier est joint, remplace l'image."""
    row = conn.execute("SELECT filename FROM screenshot WHERE id = ?", (shot_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    try:
        name = _screenshot_image(request, form)
    except UploadError as exc:
        render.flash(request, str(exc), "error")
        return back("/admin/captures")
    with conn:
        conn.execute("UPDATE screenshot SET caption = ?, filename = COALESCE(?, filename)"
                     " WHERE id = ?", (text(form, "caption", 120), name, shot_id))
    if name and row["filename"]:
        delete_file(request.app.state.settings.images_dir, row["filename"])
    render.flash(request, "Capture enregistrée.")
    return back("/admin/captures")


@router.post("/captures/{shot_id}/supprimer")
def screens_delete(shot_id: int, request: Request, form=Depends(admin_form),
                   conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT filename FROM screenshot WHERE id = ?", (shot_id,)).fetchone()
    if row:
        with conn:
            conn.execute("DELETE FROM screenshot WHERE id = ?", (shot_id,))
        delete_file(request.app.state.settings.images_dir, row["filename"])
        render.flash(request, "Capture supprimée.")
    return back("/admin/captures")


@router.post("/captures/{shot_id}/deplacer")
def screens_move(shot_id: int, request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    db.move(conn, "screenshot", shot_id, -1 if form.get("direction") == "up" else 1)
    return back("/admin/captures")


# --- APK ----------------------------------------------------------------------------

@router.get("/apk")
def apk_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/apk.html", {
        "apks": db.list_apks(conn),
        "max_mb": request.app.state.settings.max_apk_mb,
    })


@router.post("/apk/deposer")
def apk_upload(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    version = text(form, "version", 32)
    if not VERSION_RE.match(version):
        render.flash(request, "Numéro de version invalide (exemple : 1.2.0).", "error")
        return back("/admin/apk")
    if conn.execute("SELECT 1 FROM apk_release WHERE version = ?", (version,)).fetchone():
        render.flash(request, f"La version {version} existe déjà.", "error")
        return back("/admin/apk")
    apk_file = upload(form, "apk")
    if apk_file is None:
        render.flash(request, "Choisissez un fichier APK.", "error")
        return back("/admin/apk")
    try:
        saved = save_apk(apk_file.file, settings.apk_dir, settings.max_apk_bytes)
    except UploadError as exc:
        render.flash(request, str(exc), "error")
        return back("/admin/apk")
    make_current = bool(form.get("make_current"))
    try:
        with conn:
            if make_current:
                conn.execute("UPDATE apk_release SET is_current = 0 WHERE is_current = 1")
            conn.execute(
                "INSERT INTO apk_release (version, filename, size_bytes, sha256, uploaded_at,"
                " is_current) VALUES (?, ?, ?, ?, ?, ?)",
                (version, saved.filename, saved.size, saved.sha256, db.now_iso(),
                 1 if make_current else 0),
            )
    except sqlite3.IntegrityError:
        delete_file(settings.apk_dir, saved.filename)
        render.flash(request, f"La version {version} existe déjà.", "error")
        return back("/admin/apk")
    render.flash(request, f"Version {version} déposée" + (" et publiée." if make_current else "."))
    return back("/admin/apk")


@router.post("/apk/{apk_id}/courante")
def apk_set_current(apk_id: int, request: Request, form=Depends(admin_form),
                    conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT version FROM apk_release WHERE id = ?", (apk_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    with conn:
        conn.execute("UPDATE apk_release SET is_current = 0 WHERE is_current = 1")
        conn.execute("UPDATE apk_release SET is_current = 1 WHERE id = ?", (apk_id,))
    render.flash(request, f"La version {row['version']} est maintenant proposée au téléchargement.")
    return back("/admin/apk")


@router.post("/apk/{apk_id}/supprimer")
def apk_delete(apk_id: int, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT * FROM apk_release WHERE id = ?", (apk_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    if row["is_current"]:
        render.flash(request, "Impossible de supprimer la version courante : "
                              "publiez-en une autre d'abord.", "error")
        return back("/admin/apk")
    with conn:
        conn.execute("DELETE FROM apk_release WHERE id = ?", (apk_id,))
    delete_file(request.app.state.settings.apk_dir, row["filename"])
    render.flash(request, f"Version {row['version']} supprimée.")
    return back("/admin/apk")
