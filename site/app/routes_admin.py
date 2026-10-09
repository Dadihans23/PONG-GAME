"""Administration : connexion, contenu, studio, captures, APK, FAQ, mentions
légales, messages de contact."""

from __future__ import annotations

import re
import sqlite3
import time
import unicodedata
from datetime import date
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import UploadFile

from . import db, render
from .routes_public import SECTION_ANCHORS, get_conn
from .security import csrf_token, csrf_valid, password_fingerprint, verify_password
from .uploads import VERSION_RE, UploadError, delete_file, save_apk, save_image

router = APIRouter(prefix="/admin")


class LoginRequired(Exception):
    """Levée quand une page d'administration est demandée sans session valide."""


LISTS = {
    "arguments": {"kind": "feature", "title": "Arguments (section « Le jeu »)",
                  "item": "argument", "kicker": True, "body_label": "Texte",
                  "short": True, "specs": True},
    "etapes": {"kind": "step", "title": "Comment jouer",
               "item": "étape", "kicker": False, "body_label": "Précision (facultatif)",
               "short": False, "specs": False},
}

# Tableaux de lignes ordonnées (table spec_row).
# cols : (colonne, libellé, longueur maximale, zone de texte sur plusieurs lignes).
TABLES = {
    "fiche": {
        "grp": "hero_spec", "title": "Fiche technique (haut de page)", "item": "ligne",
        "hint": "Paires affichées à côté de l'accroche (ex. MODES · Solo · Duel).",
        "cols": [("label", "Libellé (ex. MODES)", 40, False),
                 ("value", "Valeur (ex. Solo · Duel)", 80, False)]},
    "comparatif": {
        "grp": "compare", "title": "Comparatif Solo / Duel", "item": "ligne",
        "hint": "Une ligne par critère. Le titre de la section se règle dans Textes.",
        "cols": [("label", "Critère", 60, False), ("value", "Solo", 160, False),
                 ("value2", "Duel", 160, False)]},
    "bareme": {
        "grp": "scoring", "title": "Barème en solo", "item": "ligne",
        "hint": "Ex. « Chaque renvoi » · « +50 ». Le titre se règle dans Textes.",
        "cols": [("label", "Libellé", 80, False), ("value", "Valeur", 60, False)]},
    "installation": {
        "grp": "install", "title": "Installation de l'APK", "item": "étape",
        "hint": "Étapes numérotées dans l'ordre. La phrase sur le Play Store se règle "
                "dans Textes (« Remarque sous les étapes d'installation »).",
        "cols": [("label", "Étape", 300, True)]},
    # Caractéristiques d'un argument : gérées depuis la page des arguments.
    "caracteristiques": {
        "grp": "feature_spec", "title": "Caractéristiques", "item": "caractéristique",
        "parent": True, "back": "/admin/listes/arguments",
        "cols": [("label", "Libellé (ex. Format)", 40, False),
                 ("value", "Valeur (ex. Premier à 5 points)", 120, False)]},
}

# Textes de la page, par section : clé -> (libellé, longueur maximale, plusieurs lignes).
TEXT_SECTIONS: list[tuple[str, dict[str, tuple[str, int, bool]]]] = [
    ("Haut de page", {
        "game_name": ("Nom du jeu (titre du héros)", 60, False),
        "hero_kicker": ("Sur-titre (ex. PONG VERTICAL · ANDROID · SOLO ET DUEL LOCAL)", 120, False),
        "tagline": ("Accroche", 300, True),
        "hero_text": ("Texte de présentation sous l'accroche", 1000, True),
        "hero_text_short": ("Texte de présentation, version courte pour mobile (facultatif)",
                            500, True),
        "hero_demo_text": ("Légende de la partie de démonstration", 300, True),
        "hero_note": ("Mention sous les boutons (ex. « Gratuit · Android »)", 80, False),
    }),
    ("Section « Le jeu »", {
        "features_kicker": ("Sur-titre de la section", 80, False),
        "features_title": ("Titre de la section", 120, False),
        "features_intro": ("Introduction", 1000, True),
    }),
    ("Solo ou Duel", {
        "compare_kicker": ("Sur-titre du comparatif", 80, False),
        "compare_title": ("Titre du comparatif", 120, False),
    }),
    ("Comment jouer et barème", {
        "steps_title": ("Titre « Comment jouer »", 80, False),
        "scoring_title": ("Titre du barème", 80, False),
    }),
    ("Captures", {
        "screens_title": ("Titre de la section", 80, False),
        "screens_intro": ("Phrase d'introduction", 200, False),
        "screens_note": ("Mention (ex. Captures réelles · Android, 360 × 800)", 120, False),
    }),
    ("Questions fréquentes", {
        "faq_title": ("Titre de la section", 80, False),
        "faq_subtitle": ("Sous-titre", 120, False),
        "faq_text": ("Phrase sous les questions (renvoi vers le contact)", 300, True),
    }),
    ("Téléchargement et installation", {
        "download_title": ("Titre du bloc de téléchargement", 80, False),
        "download_text": ("Phrase du bloc de téléchargement", 300, True),
        "install_title": ("Titre « Installer l'APK »", 80, False),
        "install_note": ("Remarque sous les étapes d'installation (Play Store)", 400, True),
        "notes_title": ("Titre des notes de version (suivi du numéro de version)", 60, False),
    }),
    ("Liens", {
        "play_store_url": ("Lien Play Store (https://…, vide = bouton masqué)", 500, False),
        "contact_email": ("Adresse e-mail affichée sur la page Contact (facultatif)", 200, False),
    }),
    ("Pied de page", {
        "footer_text": ("Texte de présentation court", 300, True),
        "footer_note": ("Mention (ex. Aucune donnée personnelle collectée)", 160, False),
        "footer_trademark": ("Mention de marque", 160, False),
    }),
]
TEXT_FIELDS = {key: spec for _, fields in TEXT_SECTIONS for key, spec in fields.items()}

ANCHOR_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MAX_ANCHOR = 40


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
    if is_admin(request):
        # Nombre de messages non lus, affiché dans le menu.
        conn = db.connect(request.app.state.settings.db_path)
        try:
            context["unread_count"] = db.unread_count(conn)
        finally:
            conn.close()
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
    site = db.get_settings(conn)
    return admin_page(request, "admin/dashboard.html", {
        "site": site,
        "apk": db.current_apk(conn),
        "n_screens": len(db.list_screenshots(conn)),
        "n_faq": len(db.list_faq(conn)),
        "n_messages": len(db.list_messages(conn)),
        "legal_missing": db.legal_missing(site),
    })


# --- Textes -----------------------------------------------------------------------

@router.get("/textes")
def texts_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/texts.html",
                      {"site": db.get_settings(conn), "sections": TEXT_SECTIONS})


@router.post("/textes")
def texts_save(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    # Seuls les champs envoyés sont modifiés.
    values = {key: text(form, key, max_len)
              for key, (_, max_len, _) in TEXT_FIELDS.items() if key in form}
    errors = []
    if "game_name" in values and not values["game_name"]:
        errors.append("Le nom du jeu est obligatoire.")
    if values.get("play_store_url") and not values["play_store_url"].startswith("https://"):
        errors.append("Le lien Play Store doit commencer par https://")
    if values.get("contact_email") and not EMAIL_RE.match(values["contact_email"]):
        errors.append("L'adresse de contact n'est pas valide.")
    if errors:
        return admin_page(request, "admin/texts.html",
                          {"site": {**db.get_settings(conn), **values},
                           "sections": TEXT_SECTIONS, "errors": errors},
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


# --- Mentions légales -------------------------------------------------------

@router.get("/mentions-legales")
def legal_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    site = db.get_settings(conn)
    return admin_page(request, "admin/legal.html", {
        "site": site, "fields": db.LEGAL_FIELDS, "missing": db.legal_missing(site)})


@router.post("/mentions-legales")
def legal_save(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    values = {key: text(form, key, 300) for key in db.LEGAL_FIELDS}
    values["legal_extra"] = text(form, "legal_extra", 20_000)
    if values["legal_email"] and not EMAIL_RE.match(values["legal_email"]):
        render.flash(request, "L'e-mail de l'éditeur n'est pas valide.", "error")
        return back("/admin/mentions-legales")
    values["legal_updated"] = date.today().isoformat()
    db.set_settings(conn, values)
    missing = db.legal_missing(values)
    if missing:
        render.flash(request, "Mentions légales enregistrées, mais incomplètes : "
                              + ", ".join(missing) + ".", "error")
    else:
        render.flash(request, "Mentions légales enregistrées.")
    return back("/admin/mentions-legales")


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
    return admin_page(request, "admin/list.html", {
        "slug": slug, "conf": conf, "items": db.list_items(conn, conf["kind"]),
        "specs": db.rows_by_item(conn, "feature_spec") if conf["specs"] else {},
        "spec_conf": TABLES["caracteristiques"],
    })


def _item_values(form, conf: dict) -> tuple[str, str, str, str]:
    return (text(form, "kicker", 40), text(form, "title", 120), text(form, "body", 1000),
            text(form, "short_body", 500) if conf["short"] else "")


@router.post("/listes/{slug}/ajouter")
def list_add(slug: str, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    conf = list_conf(slug)
    kind = conf["kind"]
    kicker, title, body, short_body = _item_values(form, conf)
    if not title:
        render.flash(request, "Le titre est obligatoire.", "error")
        return back(f"/admin/listes/{slug}")
    with conn:
        conn.execute(
            "INSERT INTO content_item (kind, position, kicker, title, body, short_body)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (kind, db.next_position(conn, "content_item", "kind = ?", (kind,)),
             kicker, title, body, short_body),
        )
    render.flash(request, "Élément ajouté.")
    return back(f"/admin/listes/{slug}")


@router.post("/listes/{slug}/{item_id}/modifier")
def list_edit(slug: str, item_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    conf = list_conf(slug)
    kicker, title, body, short_body = _item_values(form, conf)
    if not title:
        render.flash(request, "Le titre est obligatoire.", "error")
        return back(f"/admin/listes/{slug}")
    with conn:
        conn.execute(
            "UPDATE content_item SET kicker = ?, title = ?, body = ?, short_body = ?"
            " WHERE id = ? AND kind = ?",
            (kicker, title, body, short_body, item_id, conf["kind"]))
    render.flash(request, "Élément modifié.")
    return back(f"/admin/listes/{slug}")


@router.post("/listes/{slug}/{item_id}/supprimer")
def list_delete(slug: str, item_id: int, request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    with conn:
        # Les caractéristiques de l'argument partent avec lui (ON DELETE CASCADE).
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


# --- Tableaux : fiche technique, comparatif, barème, installation, caractéristiques

def table_conf(slug: str) -> dict:
    conf = TABLES.get(slug)
    if conf is None:
        raise HTTPException(404)
    return conf


def table_back(slug: str, conf: dict) -> str:
    return conf.get("back", f"/admin/tableaux/{slug}")


def _row_values(form, conf: dict) -> dict[str, str]:
    values = {"label": "", "value": "", "value2": ""}
    for col, _, max_len, _ in conf["cols"]:
        values[col] = text(form, col, max_len)
    return values


def _row_scope(conn: sqlite3.Connection, conf: dict, row_id: int) -> tuple[str, tuple] | None:
    """Clause WHERE du groupe de la ligne (pour l'ordre), ou None si elle n'existe pas."""
    row = conn.execute("SELECT item_id FROM spec_row WHERE id = ? AND grp = ?",
                       (row_id, conf["grp"])).fetchone()
    if row is None:
        return None
    if row["item_id"] is None:
        return "grp = ? AND item_id IS NULL", (conf["grp"],)
    return "grp = ? AND item_id = ?", (conf["grp"], row["item_id"])


@router.get("/tableaux/{slug}")
def table_page(slug: str, request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    conf = table_conf(slug)
    if conf.get("parent"):
        return back(conf["back"])
    return admin_page(request, "admin/table.html",
                      {"slug": slug, "conf": conf, "rows": db.list_rows(conn, conf["grp"])})


@router.post("/tableaux/{slug}/ajouter")
def table_add(slug: str, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    conf = table_conf(slug)
    values = _row_values(form, conf)
    item_id = None
    if conf.get("parent"):
        raw = form.get("item_id", "")
        item_id = int(raw) if isinstance(raw, str) and raw.isdigit() else None
        exists = item_id is not None and conn.execute(
            "SELECT 1 FROM content_item WHERE id = ? AND kind = 'feature'", (item_id,)).fetchone()
        if not exists:
            raise HTTPException(404)
    if not values["label"]:
        render.flash(request, f"{conf['cols'][0][1]} : champ obligatoire.", "error")
        return back(table_back(slug, conf))
    where, args = (("grp = ? AND item_id = ?", (conf["grp"], item_id)) if item_id is not None
                   else ("grp = ? AND item_id IS NULL", (conf["grp"],)))
    with conn:
        conn.execute(
            "INSERT INTO spec_row (grp, item_id, position, label, value, value2)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (conf["grp"], item_id, db.next_position(conn, "spec_row", where, args),
             values["label"], values["value"], values["value2"]))
    render.flash(request, "Ligne ajoutée.")
    return back(table_back(slug, conf))


@router.post("/tableaux/{slug}/{row_id}/modifier")
def table_edit(slug: str, row_id: int, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    conf = table_conf(slug)
    values = _row_values(form, conf)
    if not values["label"]:
        render.flash(request, f"{conf['cols'][0][1]} : champ obligatoire.", "error")
        return back(table_back(slug, conf))
    with conn:
        conn.execute("UPDATE spec_row SET label = ?, value = ?, value2 = ?"
                     " WHERE id = ? AND grp = ?",
                     (values["label"], values["value"], values["value2"], row_id, conf["grp"]))
    render.flash(request, "Ligne modifiée.")
    return back(table_back(slug, conf))


@router.post("/tableaux/{slug}/{row_id}/supprimer")
def table_delete(slug: str, row_id: int, request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    conf = table_conf(slug)
    with conn:
        conn.execute("DELETE FROM spec_row WHERE id = ? AND grp = ?", (row_id, conf["grp"]))
    render.flash(request, "Ligne supprimée.")
    return back(table_back(slug, conf))


@router.post("/tableaux/{slug}/{row_id}/deplacer")
def table_move(slug: str, row_id: int, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    conf = table_conf(slug)
    scope = _row_scope(conn, conf, row_id)
    if scope is not None:
        db.move(conn, "spec_row", row_id, -1 if form.get("direction") == "up" else 1, *scope)
    return back(table_back(slug, conf))


# --- Questions fréquentes ------------------------------------------------------

def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    value = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return value[:MAX_ANCHOR].strip("-")


def _faq_values(form, conn: sqlite3.Connection, faq_id: int | None) -> tuple[dict, list[str]]:
    values = {
        "question": text(form, "question", 200),
        "answer": text(form, "answer", 2000),
        "short_answer": text(form, "short_answer", 500),
        "footer_label": text(form, "footer_label", 60),
        "anchor": text(form, "anchor", 80).lower(),
    }
    errors = []
    if not values["question"]:
        errors.append("La question est obligatoire.")
    if not values["anchor"]:
        values["anchor"] = slugify(values["question"]) or "question"
    if len(values["anchor"]) > MAX_ANCHOR or not ANCHOR_RE.match(values["anchor"]):
        errors.append("Identifiant d'ancre invalide : lettres minuscules sans accent, "
                      "chiffres et tirets (ex. duel-connexion).")
    elif values["anchor"] in SECTION_ANCHORS:
        errors.append(f"L'identifiant « {values['anchor']} » est déjà pris par une section "
                      "de la page.")
    else:
        taken = conn.execute("SELECT id FROM faq WHERE anchor = ?", (values["anchor"],)).fetchone()
        if taken and taken["id"] != faq_id:
            errors.append(f"L'identifiant « {values['anchor']} » est déjà utilisé par une "
                          "autre question.")
    return values, errors


@router.get("/faq")
def faq_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/faq.html", {"items": db.list_faq(conn)})


@router.post("/faq/ajouter")
def faq_add(request: Request, form=Depends(admin_form),
            conn: sqlite3.Connection = Depends(get_conn)):
    values, errors = _faq_values(form, conn, None)
    if errors:
        for error in errors:
            render.flash(request, error, "error")
        return back("/admin/faq")
    with conn:
        conn.execute(
            "INSERT INTO faq (position, anchor, question, answer, short_answer, footer_label)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (db.next_position(conn, "faq"), values["anchor"], values["question"],
             values["answer"], values["short_answer"], values["footer_label"]))
    render.flash(request, "Question ajoutée.")
    return back("/admin/faq")


@router.post("/faq/{faq_id}/modifier")
def faq_edit(faq_id: int, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    if conn.execute("SELECT 1 FROM faq WHERE id = ?", (faq_id,)).fetchone() is None:
        raise HTTPException(404)
    values, errors = _faq_values(form, conn, faq_id)
    if errors:
        for error in errors:
            render.flash(request, error, "error")
        return back("/admin/faq")
    with conn:
        conn.execute(
            "UPDATE faq SET anchor = ?, question = ?, answer = ?, short_answer = ?,"
            " footer_label = ? WHERE id = ?",
            (values["anchor"], values["question"], values["answer"], values["short_answer"],
             values["footer_label"], faq_id))
    render.flash(request, "Question modifiée.")
    return back("/admin/faq")


@router.post("/faq/{faq_id}/supprimer")
def faq_delete(faq_id: int, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    with conn:
        conn.execute("DELETE FROM faq WHERE id = ?", (faq_id,))
    render.flash(request, "Question supprimée.")
    return back("/admin/faq")


@router.post("/faq/{faq_id}/deplacer")
def faq_move(faq_id: int, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    db.move(conn, "faq", faq_id, -1 if form.get("direction") == "up" else 1)
    return back("/admin/faq")


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
    description = text(form, "description", 500)
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
            "INSERT INTO screenshot (filename, caption, description, position, created_at)"
            " VALUES (?, ?, ?, ?, ?)",
            (name, caption, description, db.next_position(conn, "screenshot"), db.now_iso()),
        )
    render.flash(request, "Capture ajoutée.")
    return back("/admin/captures")


@router.post("/captures/{shot_id}/modifier")
def screens_edit(shot_id: int, request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    """Modifie la légende et la description et, si un fichier est joint, remplace l'image."""
    row = conn.execute("SELECT filename FROM screenshot WHERE id = ?", (shot_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    try:
        name = _screenshot_image(request, form)
    except UploadError as exc:
        render.flash(request, str(exc), "error")
        return back("/admin/captures")
    with conn:
        conn.execute("UPDATE screenshot SET caption = ?, description = ?,"
                     " filename = COALESCE(?, filename) WHERE id = ?",
                     (text(form, "caption", 120), text(form, "description", 500), name, shot_id))
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

def _release_fields(form) -> tuple[str, str, str | None]:
    """Notes de version et date (facultative) ; renvoie aussi un message d'erreur."""
    notes = text(form, "release_notes", 5000)
    release_date = text(form, "release_date", 10)
    if release_date and not valid_date(release_date):
        return notes, release_date, "Date de version invalide."
    return notes, release_date, None


@router.get("/apk")
def apk_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    apks = db.list_apks(conn)
    return admin_page(request, "admin/apk.html", {
        "apks": apks,
        "max_mb": request.app.state.settings.max_apk_mb,
        # Premier dépôt : notes de la 1.0.0 proposées dans le formulaire.
        "default_notes": "" if apks else db.V2_RELEASE_NOTES_1_0_0,
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
    notes, release_date, error = _release_fields(form)
    if error:
        render.flash(request, error, "error")
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
                " is_current, release_notes, release_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (version, saved.filename, saved.size, saved.sha256, db.now_iso(),
                 1 if make_current else 0, notes, release_date),
            )
    except sqlite3.IntegrityError:
        delete_file(settings.apk_dir, saved.filename)
        render.flash(request, f"La version {version} existe déjà.", "error")
        return back("/admin/apk")
    render.flash(request, f"Version {version} déposée" + (" et publiée." if make_current else "."))
    return back("/admin/apk")


@router.post("/apk/{apk_id}/notes")
def apk_notes(apk_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT version FROM apk_release WHERE id = ?", (apk_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    notes, release_date, error = _release_fields(form)
    if error:
        render.flash(request, error, "error")
        return back("/admin/apk")
    with conn:
        conn.execute("UPDATE apk_release SET release_notes = ?, release_date = ? WHERE id = ?",
                     (notes, release_date, apk_id))
    render.flash(request, f"Notes de la version {row['version']} enregistrées.")
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


# --- Messages du formulaire de contact -------------------------------------------

def reply_link(message: sqlite3.Row) -> str:
    subject = quote(f"Re: {message['subject']}")
    return f"mailto:{quote(message['email'], safe='@.+-_')}?subject={subject}"


def _message(conn: sqlite3.Connection, message_id: int) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM contact_message WHERE id = ?", (message_id,)).fetchone()
    if row is None:
        raise HTTPException(404, "Ce message n'existe pas ou a été supprimé.")
    return row


@router.get("/messages")
def messages_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return admin_page(request, "admin/messages.html", {"messages": db.list_messages(conn)})


@router.get("/messages/{message_id}")
def message_page(message_id: int, request: Request,
                 conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    message = _message(conn, message_id)
    return admin_page(request, "admin/message.html",
                      {"m": message, "reply_url": reply_link(message)})


@router.post("/messages/{message_id}/lu")
def message_mark(message_id: int, request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    _message(conn, message_id)
    is_read = 0 if form.get("read") == "0" else 1
    with conn:
        conn.execute("UPDATE contact_message SET is_read = ? WHERE id = ?", (is_read, message_id))
    render.flash(request, "Message marqué comme lu." if is_read else "Message marqué comme non lu.")
    return back(f"/admin/messages/{message_id}" if form.get("stay") else "/admin/messages")


@router.post("/messages/{message_id}/supprimer")
def message_delete(message_id: int, request: Request, form=Depends(admin_form),
                   conn: sqlite3.Connection = Depends(get_conn)):
    with conn:
        conn.execute("DELETE FROM contact_message WHERE id = ?", (message_id,))
    render.flash(request, "Message supprimé.")
    return back("/admin/messages")
