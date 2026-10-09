"""Administration : connexion, contenu, studio, captures, APK, FAQ, mentions
légales, messages de contact.

Gabarits dans templates/admin/ (maquette « Tilto Admin v2 »). Formulaires HTML
classiques : chaque envoi recharge la page. Un envoi refusé n'enregistre rien et
réaffiche la page avec les valeurs saisies, un bandeau en haut et le message sous
le champ fautif (`errors` : nom du champ -> message). Un envoi réussi redirige
(303) avec un message de retour (render.flash).
"""

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
from .routes_public import SECTION_ANCHORS, download_name, get_conn, release_notes_lines
from .security import csrf_token, csrf_valid, password_fingerprint, verify_password
from .uploads import VERSION_RE, UploadError, delete_file, save_apk, save_image

router = APIRouter(prefix="/admin")


class LoginRequired(Exception):
    """Levée quand une page d'administration est demandée sans session valide."""


# --- Pages et menu ---------------------------------------------------------------

CONTENT = "Contenu de la page"
LEGAL = "Pages légales"

# clé -> (titre, sous-titre, fil d'Ariane, adresse). {host} = domaine du site.
PAGES: dict[str, tuple[str, str, str, str]] = {
    "dashboard": ("Tableau de bord", "L'état de {host}, et ce qu'il reste à remplir.", "", "/admin"),
    "messages": ("Messages", "Reçus par le formulaire de contact du site.", "", "/admin/messages"),
    "textes": ("Textes", "Le titre, l'accroche, le bloc de téléchargement, les liens et le pied "
               "de page.", CONTENT, "/admin/textes"),
    "fiche": ("Fiche technique", "Le haut de page : sur-titre, présentation, fiche et légende "
              "de la démo.", CONTENT, "/admin/tableaux/fiche"),
    "arguments": ("Arguments", "La section « Le jeu » du site.", CONTENT,
                  "/admin/listes/arguments"),
    "comparatif": ("Solo / Duel", "Le tableau comparatif des deux modes.", CONTENT,
                   "/admin/tableaux/comparatif"),
    "etapes": ("Comment jouer", "Les étapes de la section « Comment jouer », dans l'ordre.",
               CONTENT, "/admin/listes/etapes"),
    "bareme": ("Barème", "Le petit tableau des points, à côté de « Comment jouer ».", CONTENT,
               "/admin/tableaux/bareme"),
    "captures": ("Captures", "Les captures d'écran de l'app, dans l'ordre du site.", CONTENT,
                 "/admin/captures"),
    "faq": ("FAQ", "Les questions fréquentes, dans l'ordre du site.", CONTENT, "/admin/faq"),
    "installation": ("Installation", "Le bloc « Installer l'APK », à côté des boutons de "
                     "téléchargement.", CONTENT, "/admin/tableaux/installation"),
    "apk": ("APK et notes de version", "Le fichier proposé par le bouton « Télécharger l'APK », "
            "et ses nouveautés.", "", "/admin/apk"),
    "studio": ("Studio", "Le nom et le logo affichés dans le pied de page.", "", "/admin/studio"),
    "confidentialite": ("Confidentialité", "La page {host}/confidentialite.", LEGAL,
                        "/admin/confidentialite"),
    "mentions": ("Mentions légales", "La page {host}/mentions-legales. Obligatoire pour un "
                 "site publié.", LEGAL, "/admin/mentions-legales"),
}

# Menu : groupes dans l'ordre du site (titre vide = sans intertitre).
NAV: list[tuple[str, list[str]]] = [
    ("", ["dashboard", "messages"]),
    ("Contenu de la page", ["textes", "fiche", "arguments", "comparatif", "etapes", "bareme",
                            "captures", "faq", "installation"]),
    ("", ["apk", "studio"]),
    ("Pages légales", ["confidentialite", "mentions"]),
]


# --- Textes de la page (table setting) ------------------------------------------

def _f(label: str, max_len: int, *, area: bool = False, opt: bool = False,
       required: bool = False, help: str = "", kind: str = "text") -> dict:
    return {"label": label, "max": max_len, "area": area, "opt": opt, "required": required,
            "help": help, "kind": kind}


# Réglages modifiables : clé -> champ (libellé, longueur maximale, zone de texte…).
TEXT_FIELDS: dict[str, dict] = {
    # Textes
    "game_name": _f("Nom du jeu", 60, required=True, help="Le grand titre du haut de page."),
    "tagline": _f("Accroche", 300, area=True),
    "hero_note": _f("Mention sous les boutons", 80),
    "download_title": _f("Titre", 80),
    "download_text": _f("Phrase", 300, area=True),
    "notes_title": _f("Titre des notes de version", 60,
                      help="Suivi du numéro de la version proposée : « Nouveautés 1.0.0 »."),
    "play_store_url": _f("Lien Play Store", 500, kind="url",
                         help="Laisse vide pour masquer le bouton Google Play."),
    "contact_email": _f("Adresse de contact", 200, kind="email", opt=True,
                        help="Affichée sur la page Contact, sous le formulaire, pour qui "
                             "préfère écrire directement. Le formulaire marche sans elle."),
    "footer_text": _f("Présentation courte", 300, area=True),
    "footer_note": _f("Mention", 160),
    "footer_trademark": _f("Mention de marque", 160),
    # Fiche technique (haut de page)
    "hero_kicker": _f("Sur-titre", 120),
    "hero_demo_text": _f("Légende de la démo", 300),
    "hero_text": _f("Présentation", 1000, area=True),
    "hero_text_short": _f("Version courte pour mobile", 500, area=True, opt=True,
                          help="Vide = le texte long s'affiche aussi sur mobile."),
    # Arguments
    "features_kicker": _f("Sur-titre", 80),
    "features_title": _f("Titre", 120),
    "features_intro": _f("Introduction", 1000, area=True),
    # Solo / Duel
    "compare_kicker": _f("Sur-titre", 80),
    "compare_title": _f("Titre", 120),
    # Comment jouer, barème
    "steps_title": _f("Titre de la section", 80),
    "scoring_title": _f("Titre", 80),
    # Captures
    "screens_title": _f("Nom de la section", 80,
                        help="En sur-titre, au-dessus de la phrase d'introduction."),
    "screens_intro": _f("Phrase d'introduction", 200,
                        help="Sert de titre à la section. Vide = le nom de la section sert de "
                             "titre."),
    "screens_note": _f("Mention", 120, help="Affichée à côté du titre."),
    # FAQ
    "faq_title": _f("Titre", 80),
    "faq_subtitle": _f("Sous-titre", 120),
    "faq_text": _f("Phrase sous les questions", 300, area=True,
                   help="Suivie d'un lien vers la page Contact."),
    # Installation
    "install_title": _f("Titre du bloc", 80),
    "install_note": _f("Note sur le Play Store", 400, area=True, help="Affichée sous les étapes."),
}

# Groupes de réglages affichés sur chaque page : (titre, aide, clés).
SETTING_GROUPS: dict[str, list[tuple[str, str, list[str]]]] = {
    "textes": [
        ("Haut de page", "", ["game_name", "tagline", "hero_note"]),
        ("Bloc de téléchargement", "", ["download_title", "download_text", "notes_title"]),
        ("Liens", "", ["play_store_url", "contact_email"]),
        ("Pied de page", "Sur toutes les pages du site.",
         ["footer_text", "footer_note", "footer_trademark"]),
    ],
    "fiche": [("Haut de page", "", ["hero_kicker", "hero_demo_text", "hero_text",
                                     "hero_text_short"])],
    "comparatif": [("En-tête du bloc", "", ["compare_kicker", "compare_title"])],
    "bareme": [("En-tête du bloc", "", ["scoring_title"])],
    "installation": [("Titre et note", "", ["install_title", "install_note"])],
    "arguments": [("En-tête de la section", "", ["features_kicker", "features_title",
                                                  "features_intro"])],
    "etapes": [("En-tête de la section", "", ["steps_title"])],
    "captures": [("En-tête de la section", "", ["screens_title", "screens_intro",
                                                 "screens_note"])],
    "faq": [("En-tête de la section", "", ["faq_title", "faq_subtitle", "faq_text"])],
}

ANCHOR_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MAX_ANCHOR = 40
EMAIL_RE = re.compile(r"^[^@\s<>\"']+@[^@\s<>\"']+\.[^@\s<>\"']+$")
INVALID_EMAIL = "Cette adresse e-mail n'est pas valide."
FIX_FIELD = "Rien n'a été enregistré : corrige le champ en rouge."
FIX_FIELDS = "Rien n'a été enregistré : corrige les champs en rouge."


def fix_banner(errors: dict) -> tuple[str, str]:
    return ("error", FIX_FIELDS if len(errors) > 1 else FIX_FIELD)


def valid_date(value: str) -> bool:
    """Date AAAA-MM-JJ (champ <input type="date">)."""
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return len(value) == 10


def validate_settings(values: dict[str, str]) -> dict[str, str]:
    errors = {}
    if "game_name" in values and not values["game_name"]:
        errors["game_name"] = "Le nom du jeu est obligatoire."
    if values.get("play_store_url") and not values["play_store_url"].startswith("https://"):
        errors["play_store_url"] = "Le lien Play Store doit commencer par https://"
    if values.get("contact_email") and not EMAIL_RE.match(values["contact_email"]):
        errors["contact_email"] = INVALID_EMAIL
    return errors


def setting_values(form, keys) -> dict[str, str]:
    """Réglages envoyés (seuls les champs présents dans le formulaire)."""
    return {key: text(form, key, TEXT_FIELDS[key]["max"]) for key in keys if key in form}


def page_keys(page: str) -> list[str]:
    return [key for _, _, keys in SETTING_GROUPS.get(page, []) for key in keys]


def stamp(conn: sqlite3.Connection, page: str) -> None:
    """Horodatage du dernier enregistrement d'une page (réglage interne)."""
    db.set_internal(conn, f"_saved:{page}", db.now_iso())


# --- Mentions légales : présentation des champs de db.LEGAL_FIELDS ---------------

# clé -> (libellé, nom court dans les phrases, aide, exemple, zone de texte, type)
LEGAL_UI: dict[str, tuple[str, str, str, str, bool, str]] = {
    "legal_publisher": ("Nom ou raison sociale", "nom ou raison sociale", "", "", False, "text"),
    "legal_form": ("Forme juridique", "forme juridique", "",
                   "Ex. : Entrepreneur individuel", False, "text"),
    "legal_registration": ("Numéro d'immatriculation", "numéro d'immatriculation", "",
                           "Ex. : SIREN, RCS…", False, "text"),
    "legal_phone": ("Téléphone", "téléphone", "", "", False, "tel"),
    "legal_address": ("Adresse", "adresse", "", "", True, "text"),
    "legal_email": ("E-mail", "e-mail", "", "", False, "email"),
    "legal_director": ("Directeur de la publication", "directeur de la publication",
                       "Le plus souvent, toi.", "", False, "text"),
    "legal_host_name": ("Nom", "nom de l'hébergeur", "", "", False, "text"),
    "legal_host_phone": ("Téléphone", "téléphone de l'hébergeur", "",
                         "Numéro de l'hébergeur", False, "tel"),
    "legal_host_address": ("Adresse", "adresse de l'hébergeur", "", "", True, "text"),
}
LEGAL_GROUPS = [
    ("Éditeur du site", "Pour une personne physique : tes nom et prénom, et « Entrepreneur "
     "individuel » ou « Particulier » comme forme juridique.",
     ["legal_publisher", "legal_form", "legal_registration", "legal_phone", "legal_address",
      "legal_email", "legal_director"]),
    ("Hébergeur", "Le nom est pré-rempli avec l'hébergeur actuel du site. Son adresse et son "
     "téléphone figurent sur son site.",
     ["legal_host_name", "legal_host_phone", "legal_host_address"]),
]
LEGAL_MAX = 300
LEGAL_EXTRA_MAX = 20_000


def legal_missing_keys(site: dict) -> list[str]:
    return [key for key, (_, required) in db.LEGAL_FIELDS.items()
            if required and not site.get(key, "").strip()]


def legal_missing_sentence(keys: list[str]) -> str:
    names = ", ".join(LEGAL_UI[k][1] for k in keys)
    if len(keys) == 1:
        return f"Il manque 1 champ obligatoire : {names}."
    return f"Il manque {len(keys)} champs obligatoires : {names}."


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


def nav_groups(active: str | None, unread: int) -> list[dict]:
    return [{"title": title, "links": [
        {"key": key, "label": PAGES[key][0], "url": PAGES[key][3], "active": key == active,
         "count": unread if key == "messages" and unread else 0}
        for key in keys]} for title, keys in NAV]


def admin_page(request: Request, name: str, context: dict | None = None,
               status_code: int = 200, page: str | None = None):
    """Rend une page d'administration : menu, en-tête de page, bandeau, erreurs."""
    context = dict(context or {})
    context["csrf"] = csrf_token(request)
    host = request.url.netloc
    context["host"] = host
    context.setdefault("errors", {})
    context.setdefault("banner", None)
    if context["errors"] and context["banner"] is None:
        context["banner"] = fix_banner(context["errors"])
    if page:
        title, sub, crumb, url = PAGES[page]
        context.update(page=page, page_title=title, page_sub=sub.format(host=host),
                       page_crumb=crumb, page_url=url)
    conn = db.connect(request.app.state.settings.db_path)
    try:
        site = db.get_settings(conn)
        context.setdefault("studio_name", site.get("studio_name", ""))
        context.setdefault("game_name", site.get("game_name", "") or "Tilto")
        if is_admin(request):
            unread = db.unread_count(conn)
            context["unread_count"] = unread
            context["nav"] = nav_groups(page, unread)
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


def plural(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def image_error(exc: UploadError) -> str:
    """Message sous le champ image (le bandeau reprend le message complet)."""
    if "n'est pas une image" in str(exc):
        return "Format refusé. Utilise PNG, JPEG, WebP ou GIF."
    return str(exc)


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
        return admin_page(request, "admin/login.html", {"locked": True}, status_code=429)
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
                      {"errors": {"password": "Mot de passe incorrect."}, "banner": False},
                      status_code=401)


@router.post("/deconnexion")
async def logout(request: Request):
    await form_with_csrf(request)
    request.session.clear()
    return back("/admin/connexion")


# --- Tableau de bord ----------------------------------------------------------

def site_state(conn: sqlite3.Connection, site: dict) -> dict:
    """Ce qu'il reste à faire et l'état de chaque section, d'après la base."""
    apk = db.current_apk(conn)
    shots = db.list_screenshots(conn)
    with_image = sum(1 for s in shots if s["filename"])
    missing = legal_missing_keys(site)
    notes = release_notes_lines(apk["release_notes"]) if apk else []

    todo = []
    if missing:
        todo.append(("Compléter les mentions légales",
                     plural(len(missing), "champ obligatoire manque.", "champs obligatoires manquent."),
                     "Mentions légales", PAGES["mentions"][3]))
    if apk is None:
        todo.append(("Déposer un APK", "Le bouton « Télécharger l'APK » est masqué sur le site.",
                     "APK", PAGES["apk"][3]))
    elif not notes:
        todo.append((f"Écrire les notes de la version {apk['version']}",
                     "Le bloc « Nouveautés » est masqué sur le site.", "APK", PAGES["apk"][3]))
    if shots and with_image < len(shots):
        todo.append(("Ajouter les images des captures",
                     f"{with_image} sur {len(shots)} captures ont une image.",
                     "Captures", PAGES["captures"][3]))
    if not site.get("contact_email"):
        todo.append(("Renseigner l'adresse de contact",
                     "La page Contact ne propose que le formulaire.", "Textes",
                     PAGES["textes"][3] + "#f-contact_email"))

    def row(label, value, url, action, style=""):
        return {"label": label, "value": value, "url": url, "action": action, "style": style}

    features = db.list_items(conn, "feature")
    steps = db.list_items(conn, "step")
    faq = db.list_faq(conn)
    compare = db.list_rows(conn, "compare")
    play = site.get("play_store_url", "")
    rows = [
        row("Mentions légales",
            f"{plural(len(missing), 'champ obligatoire manquant', 'champs obligatoires manquants')}"
            if missing else "complètes",
            PAGES["mentions"][3], "Compléter" if missing else "Modifier",
            "bad" if missing else ""),
        row("Version au téléchargement",
            f"{apk['version']} · {render.filesize(apk['size_bytes'])} · déposée le "
            f"{render.date_short(apk['uploaded_at'])}" if apk else "aucune",
            PAGES["apk"][3], "Gérer" if apk else "Déposer", "" if apk else "empty"),
        row("Notes de version",
            (f"{plural(len(notes), 'nouveauté', 'nouveautés')} pour la {apk['version']}"
             if notes else f"aucune pour la {apk['version']}") if apk
            else "sans version proposée",
            PAGES["apk"][3], "Modifier", "" if notes else "empty"),
        row("Lien Play Store", re.sub(r"^https://", "", play) if play else "non renseigné",
            PAGES["textes"][3] + "#f-play_store_url", "Modifier" if play else "Renseigner",
            "" if play else "empty"),
        row("Adresse de contact", site.get("contact_email") or "non renseignée",
            PAGES["textes"][3] + "#f-contact_email",
            "Modifier" if site.get("contact_email") else "Renseigner",
            "" if site.get("contact_email") else "empty"),
        row("Captures d'écran",
            f"{with_image} sur {len(shots)} avec image" if shots else "aucune",
            PAGES["captures"][3], "Modifier" if shots else "Ajouter",
            "" if shots and with_image == len(shots) else "empty"),
        row("Contenu de la page",
            " · ".join([plural(len(features), "argument", "arguments"),
                        plural(len(steps), "étape", "étapes"),
                        plural(len(faq), "question", "questions"),
                        plural(len(compare), "ligne Solo / Duel", "lignes Solo / Duel")]),
            PAGES["arguments"][3], "Modifier"),
        row("Studio", f"{site.get('studio_name', '')} · "
            + ("logo présent" if site.get("studio_logo") else "sans logo"),
            PAGES["studio"][3], "Modifier"),
        row("Confidentialité",
            f"mise à jour le {render.date_short(site.get('privacy_updated', ''))}"
            if site.get("privacy_updated") else "date non renseignée",
            PAGES["confidentialite"][3], "Modifier", "" if site.get("privacy_updated") else "empty"),
    ]
    return {"todo": todo, "rows": rows, "legal_missing": missing,
            "legal_sentence": legal_missing_sentence(missing) if missing else ""}


@router.get("")
def dashboard(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    site = db.get_settings(conn)
    state = site_state(conn, site)
    return admin_page(request, "admin/dashboard.html", {
        "site": site, **state, "latest": db.list_messages(conn)[:3],
    }, page="dashboard")


# --- Textes et en-têtes des sections -------------------------------------------

def groups_for(page: str) -> list[dict]:
    return [{"title": title, "help": help_text,
             "fields": [dict(TEXT_FIELDS[key], key=key) for key in keys]}
            for title, help_text, keys in SETTING_GROUPS.get(page, [])]


def texts_view(request: Request, conn: sqlite3.Connection, vals: dict | None = None,
               errors: dict | None = None, status_code: int = 200):
    site = {**db.get_settings(conn), **(vals or {})}
    return admin_page(request, "admin/texts.html", {
        "vals": site, "groups": groups_for("textes"), "errors": errors or {},
        "saved_at": db.get_internal(conn, "_saved:textes"),
    }, status_code=status_code, page="textes")


@router.get("/textes")
def texts_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return texts_view(request, conn)


@router.post("/textes")
def texts_save(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    # Seuls les champs envoyés sont modifiés.
    values = setting_values(form, TEXT_FIELDS)
    errors = validate_settings(values)
    if errors:
        return texts_view(request, conn, values, errors, status_code=400)
    db.set_settings(conn, values)
    stamp(conn, "textes")
    render.flash(request, "Textes enregistrés.")
    return back("/admin/textes")


# En-tête d'une section affichée sous forme de liste (arguments, étapes, captures, FAQ).
HEADER_PAGES = {"arguments", "etapes", "captures", "faq"}


@router.post("/en-tete/{page}")
def header_save(page: str, request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    if page not in HEADER_PAGES:
        raise HTTPException(404)
    values = setting_values(form, page_keys(page))
    errors = validate_settings(values)
    if errors:
        return PAGE_VIEWS[page](request, conn, header_vals=values, errors=errors,
                                status_code=400)
    db.set_settings(conn, values)
    stamp(conn, page)
    render.flash(request, "En-tête enregistré.")
    return back(PAGES[page][3])


# --- Studio -----------------------------------------------------------------------

def studio_view(request: Request, conn: sqlite3.Connection, vals: dict | None = None,
                errors: dict | None = None, banner=None, status_code: int = 200):
    site = {**db.get_settings(conn), **(vals or {})}
    site["studio_logo_url"] = f"/media/{site['studio_logo']}" if site.get("studio_logo") else ""
    return admin_page(request, "admin/studio.html", {
        "vals": site, "errors": errors or {}, "banner": banner,
        "max_image_mb": request.app.state.settings.max_image_mb,
        "saved_at": db.get_internal(conn, "_saved:studio"),
        "year": date.today().year, "apk": db.current_apk(conn),
    }, status_code=status_code, page="studio")


@router.get("/studio")
def studio_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return studio_view(request, conn)


@router.post("/studio")
def studio_save(request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    current = db.get_settings(conn)
    name = text(form, "studio_name", 60)
    if not name:
        return studio_view(request, conn, {"studio_name": ""},
                           {"studio_name": "Le nom du studio est obligatoire."},
                           banner=("error", "Le nom du studio est obligatoire."),
                           status_code=400)
    values = {"studio_name": name}
    old_logo = current.get("studio_logo", "")
    logo = upload(form, "logo")
    if logo:
        try:
            values["studio_logo"] = save_image(logo.file, settings.images_dir,
                                               settings.max_image_bytes, allow_svg=True)
        except UploadError as exc:
            return studio_view(request, conn, {"studio_name": name},
                               {"logo": str(exc)}, banner=("error", str(exc)), status_code=400)
    elif form.get("remove_logo"):
        values["studio_logo"] = ""
    db.set_settings(conn, values)
    if "studio_logo" in values and old_logo:
        delete_file(settings.images_dir, old_logo)
    stamp(conn, "studio")
    if "studio_logo" in values:
        render.flash(request, "Logo remplacé." if values["studio_logo"] else "Logo retiré.")
    else:
        render.flash(request, "Studio enregistré.")
    return back("/admin/studio")


# --- Confidentialité ---------------------------------------------------------

def privacy_view(request: Request, conn: sqlite3.Connection, vals: dict | None = None,
                 errors: dict | None = None, status_code: int = 200):
    saved = db.get_settings(conn)
    return admin_page(request, "admin/privacy.html", {
        "vals": {**saved, **(vals or {})}, "saved": saved, "errors": errors or {},
    }, status_code=status_code, page="confidentialite")


@router.get("/confidentialite")
def privacy_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return privacy_view(request, conn)


@router.post("/confidentialite")
def privacy_save(request: Request, form=Depends(admin_form),
                 conn: sqlite3.Connection = Depends(get_conn)):
    values = {"privacy_policy": text(form, "privacy_policy", 50_000),
              "privacy_updated": text(form, "privacy_updated", 10)}
    if not valid_date(values["privacy_updated"]):
        return privacy_view(request, conn, values,
                            {"privacy_updated": "Date de mise à jour invalide."}, status_code=400)
    db.set_settings(conn, values)
    stamp(conn, "confidentialite")
    render.flash(request, "Politique enregistrée. La page publique est à jour.")
    return back("/admin/confidentialite")


# --- Mentions légales -------------------------------------------------------

def legal_view(request: Request, conn: sqlite3.Connection, vals: dict | None = None,
               errors: dict | None = None, banner=None, status_code: int = 200):
    site = {**db.get_settings(conn), **(vals or {})}
    errors = dict(errors or {})
    missing = legal_missing_keys(db.get_settings(conn))
    if not errors:
        # Champs obligatoires vides : signalés en rouge tant qu'ils manquent.
        errors = {key: "Obligatoire." for key in missing}
        if missing and banner is None:
            banner = ("error", legal_missing_sentence(missing)
                      + " La page est en ligne mais incomplète.")
    groups = [{"title": title, "help": help_text, "fields": [
        {"key": key, "label": LEGAL_UI[key][0], "help": LEGAL_UI[key][2],
         "placeholder": LEGAL_UI[key][3], "area": LEGAL_UI[key][4], "kind": LEGAL_UI[key][5],
         "required": db.LEGAL_FIELDS[key][1], "max": LEGAL_MAX} for key in keys]}
        for title, help_text, keys in LEGAL_GROUPS]
    return admin_page(request, "admin/legal.html", {
        "vals": site, "groups": groups, "errors": errors, "banner": banner,
        "extra_max": LEGAL_EXTRA_MAX,
    }, status_code=status_code, page="mentions")


@router.get("/mentions-legales")
def legal_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return legal_view(request, conn)


@router.post("/mentions-legales")
def legal_save(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    values = {key: text(form, key, LEGAL_MAX) for key in db.LEGAL_FIELDS}
    values["legal_extra"] = text(form, "legal_extra", LEGAL_EXTRA_MAX)
    if values["legal_email"] and not EMAIL_RE.match(values["legal_email"]):
        return legal_view(request, conn, values, {"legal_email": INVALID_EMAIL},
                          status_code=400)
    values["legal_updated"] = date.today().isoformat()
    db.set_settings(conn, values)
    stamp(conn, "mentions")
    missing = legal_missing_keys(values)
    if missing:
        render.flash(request, "Mentions légales enregistrées, mais incomplètes. "
                     + legal_missing_sentence(missing) + " La page est en ligne mais "
                     "incomplète.", "error")
    else:
        render.flash(request, "Mentions légales enregistrées. Tous les champs obligatoires "
                              "sont remplis.")
    return back("/admin/mentions-legales")


# --- Listes : arguments, étapes et FAQ -------------------------------------------

LISTS = {
    "arguments": {
        "kind": "feature", "page": "arguments", "base": "/admin/listes/arguments",
        "list_title": "Arguments",
        "list_help": "Les 4 premiers ont une illustration dessinée sur le site. À partir du "
                     "5ᵉ, l'argument s'affiche en texte seul.",
        "add_label": "Ajouter un argument", "add_button": "Ajouter l'argument",
        "new_title": "Nouvel argument", "saved": "Argument enregistré.",
        "added": "Argument ajouté.", "deleted": "Argument supprimé.",
        "not_added": "L'argument n'a pas été ajouté : il manque le titre.",
        "not_saved": "L'argument n'a pas été enregistré : il manque le titre.",
        "empty_title": "Aucun argument.",
        "empty_text": "La section « Le jeu » est masquée sur le site tant que la liste est vide.",
        "confirm_title": "Supprimer l'argument « {name} » ?",
        "confirm_text": "Il disparaît du site dès la confirmation, avec ses caractéristiques. "
                        "Les arguments suivants remontent d'un rang. Cette action est définitive.",
        "fields": [("kicker", "Sur-titre", 40, False, False, ""),
                   ("title", "Titre", 120, False, True, ""),
                   ("body", "Texte", 1000, True, False, ""),
                   ("short_body", "Texte court pour mobile", 500, True, None,
                    "Vide = le texte long s'affiche aussi sur mobile.")],
        "specs": True,
    },
    "etapes": {
        "kind": "step", "page": "etapes", "base": "/admin/listes/etapes",
        "list_title": "Étapes",
        "list_help": "Le site numérote les étapes dans cet ordre. Trois étapes suffisent en "
                     "général.",
        "add_label": "Ajouter une étape", "add_button": "Ajouter l'étape",
        "new_title": "Nouvelle étape", "saved": "Étape enregistrée.", "added": "Étape ajoutée.",
        "deleted": "Étape supprimée.",
        "not_added": "L'étape n'a pas été ajoutée : il manque le titre.",
        "not_saved": "L'étape n'a pas été enregistrée : il manque le titre.",
        "empty_title": "Aucune étape.",
        "empty_text": "Les étapes disparaissent du site tant que la liste est vide.",
        "confirm_title": "Supprimer l'étape « {name} » ?",
        "confirm_text": "Elle disparaît du site dès la confirmation. Les étapes suivantes "
                        "remontent d'un rang. Cette action est définitive.",
        "fields": [("title", "Titre", 120, False, True, ""),
                   ("body", "Précision", 1000, True, None, "")],
        "specs": False,
    },
    "faq": {
        "kind": "faq", "page": "faq", "base": "/admin/faq",
        "list_title": "Questions",
        "list_help": "Chaque question a une ancre : {host}/#{anchor} ouvre directement la "
                     "réponse, et changer une ancre casse les liens déjà partagés.",
        "add_label": "Ajouter une question", "add_button": "Ajouter la question",
        "new_title": "Nouvelle question", "saved": "Question enregistrée.",
        "added": "Question ajoutée.", "deleted": "Question supprimée.",
        "not_added": "La question n'a pas été ajoutée : corrige le champ en rouge.",
        "not_saved": "La question n'a pas été enregistrée : corrige le champ en rouge.",
        "empty_title": "Aucune question.",
        "empty_text": "La section FAQ est masquée sur le site tant que la liste est vide.",
        "confirm_title": "Supprimer la question « {name} » ?",
        "confirm_text": "Elle disparaît du site dès la confirmation. Les liens déjà partagés "
                        "vers #{anchor} ne mèneront plus à cette réponse.",
        "fields": [("question", "Question", 200, False, True, ""),
                   ("answer", "Réponse", 2000, True, False, ""),
                   ("short_answer", "Réponse courte pour mobile", 500, True, None,
                    "Vide = la réponse longue s'affiche aussi sur mobile."),
                   ("anchor", "Ancre", MAX_ANCHOR, False, False,
                    "Générée depuis la question si tu la laisses vide. Lettres minuscules sans "
                    "accent, chiffres et tirets.")],
        # La colonne faq.footer_label reste en base mais n'est plus ni affichée ni
        # modifiée : le pied de page ne mène plus qu'à de vraies pages.
        "specs": False,
    },
}

SPEC_COLS = [("label", "Libellé", 40), ("value", "Valeur", 120)]


def list_conf(slug: str) -> dict:
    conf = LISTS.get(slug)
    if conf is None or slug == "faq":
        raise HTTPException(404)
    return conf


def _list_rows(conn: sqlite3.Connection, conf: dict) -> list[sqlite3.Row]:
    if conf["kind"] == "faq":
        return db.list_faq(conn)
    return db.list_items(conn, conf["kind"])


def list_view(request: Request, conn: sqlite3.Connection, slug: str, *,
              open_id: int | None = None, item_vals: dict | None = None,
              add_open: bool = False, add_vals: dict | None = None,
              header_vals: dict | None = None, errors: dict | None = None,
              banner=None, new_spec: bool = False, status_code: int = 200):
    """Liste dépliable (arguments, étapes, FAQ). `open_id` : élément ouvert en
    formulaire ; `item_vals` / `add_vals` : valeurs saisies à réafficher."""
    conf = LISTS[slug]
    rows = _list_rows(conn, conf)
    specs = db.rows_by_item(conn, "feature_spec") if conf["specs"] else {}
    title_key = "question" if conf["kind"] == "faq" else "title"
    items = []
    for i, row in enumerate(rows):
        values = dict(row)
        if row["id"] == open_id and item_vals:
            values.update(item_vals)
        item_specs = [dict(s) for s in specs.get(row["id"], [])]
        if row["id"] == open_id and item_vals and item_vals.get("_specs"):
            posted = item_vals["_specs"]
            for s in item_specs:
                s.update(posted.get(s["id"], {}))
        meta = ""
        if conf["kind"] == "feature":
            meta = ("Illustré sur le site" if i < 4 else "Texte seul") + " · " + plural(
                len(item_specs), "caractéristique", "caractéristiques")
        elif conf["kind"] == "faq":
            meta = f"#{row['anchor']}"
        name = (row["kicker"] if conf["kind"] == "feature" and row["kicker"] else row[title_key])
        items.append({
            "id": row["id"], "n": i + 1, "data": values, "specs": item_specs, "meta": meta,
            "sur": row["kicker"] if conf["kind"] == "feature" else "",
            "title": row[title_key], "text": row["answer"] if conf["kind"] == "faq" else row["body"],
            "open": row["id"] == open_id,
            "confirm_title": conf["confirm_title"].format(name=name),
            "confirm_text": conf["confirm_text"].format(
                anchor=row["anchor"] if conf["kind"] == "faq" else ""),
        })
    site = {**db.get_settings(conn), **(header_vals or {})}
    example = rows[0]["anchor"] if conf["kind"] == "faq" and rows else "question"
    return admin_page(request, "admin/items.html", {
        "slug": slug, "conf": conf, "items": items, "groups": groups_for(conf["page"]),
        "vals": site, "header_url": f"/admin/en-tete/{conf['page']}",
        "list_help": conf["list_help"].format(host=request.url.netloc, anchor=example),
        "add_open": add_open or not rows and bool(add_vals),
        "add_vals": add_vals or {}, "new_spec": new_spec, "errors": errors or {},
        "banner": banner, "spec_cols": SPEC_COLS,
    }, status_code=status_code, page=conf["page"])


@router.get("/listes/{slug}")
def list_page(slug: str, request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    list_conf(slug)
    raw = request.query_params.get("ouvert", "")
    return list_view(request, conn, slug, open_id=int(raw) if raw.isdigit() else None,
                     add_open=request.query_params.get("ajout") == "1",
                     new_spec=request.query_params.get("carac") == "1")


def _item_values(form, conf: dict) -> dict[str, str]:
    return {name: text(form, name, max_len) for name, _, max_len, *_ in conf["fields"]}


@router.post("/listes/{slug}/ajouter")
def list_add(slug: str, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    conf = list_conf(slug)
    kind = conf["kind"]
    values = _item_values(form, conf)
    if not values["title"]:
        return list_view(request, conn, slug, add_open=True, add_vals=values,
                         errors={"new-title": "Le titre est obligatoire."},
                         banner=("error", conf["not_added"]), status_code=400)
    with conn:
        conn.execute(
            "INSERT INTO content_item (kind, position, kicker, title, body, short_body)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (kind, db.next_position(conn, "content_item", "kind = ?", (kind,)),
             values.get("kicker", ""), values["title"], values.get("body", ""),
             values.get("short_body", "")),
        )
    render.flash(request, conf["added"])
    return back(conf["base"])


def _spec_values(form, item_id: int, conn: sqlite3.Connection) -> dict[int, dict]:
    """Caractéristiques envoyées avec le formulaire d'un argument (spec-<id>-<col>)."""
    posted = {}
    for row in db.list_rows(conn, "feature_spec", item_id):
        if f"spec-{row['id']}-label" in form:
            posted[row["id"]] = {col: text(form, f"spec-{row['id']}-{col}", max_len)
                                 for col, _, max_len in SPEC_COLS}
    return posted


@router.post("/listes/{slug}/{item_id}/modifier")
def list_edit(slug: str, item_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    """Enregistre l'élément et, pour un argument, ses caractéristiques envoyées
    avec lui ; `action` (spec-up:<id>, spec-down:<id>, spec-delete:<id>,
    spec-add) agit ensuite sur une caractéristique."""
    conf = list_conf(slug)
    exists = conn.execute("SELECT 1 FROM content_item WHERE id = ? AND kind = ?",
                          (item_id, conf["kind"])).fetchone()
    if exists is None:
        raise HTTPException(404)
    values = _item_values(form, conf)
    specs = _spec_values(form, item_id, conn) if conf["specs"] else {}
    new_spec = ({col: text(form, f"spec-new-{col}", max_len) for col, _, max_len in SPEC_COLS}
                if conf["specs"] and "spec-new-label" in form else {})
    errors = {}
    if not values["title"]:
        errors["title"] = "Le titre est obligatoire."
    for spec_id, spec in specs.items():
        if not spec["label"]:
            errors[f"spec-{spec_id}-label"] = "Le libellé est obligatoire."
    if new_spec and new_spec["value"] and not new_spec["label"]:
        errors["spec-new-label"] = "Le libellé est obligatoire."
    if errors:
        banner = (conf["not_saved"] if list(errors) == ["title"] else FIX_FIELD)
        return list_view(request, conn, slug, open_id=item_id,
                         item_vals={**values, "_specs": specs,
                                    "_new_label": new_spec.get("label", ""),
                                    "_new_value": new_spec.get("value", "")}, errors=errors,
                         banner=("error", banner), new_spec=bool(new_spec),
                         status_code=400)
    with conn:
        conn.execute(
            "UPDATE content_item SET kicker = ?, title = ?, body = ?, short_body = ?"
            " WHERE id = ? AND kind = ?",
            (values.get("kicker", ""), values["title"], values.get("body", ""),
             values.get("short_body", ""), item_id, conf["kind"]))
        for spec_id, spec in specs.items():
            conn.execute("UPDATE spec_row SET label = ?, value = ? WHERE id = ?"
                         " AND grp = 'feature_spec' AND item_id = ?",
                         (spec["label"], spec["value"], spec_id, item_id))
        if new_spec and new_spec["label"]:
            where = ("grp = 'feature_spec' AND item_id = ?", (item_id,))
            conn.execute(
                "INSERT INTO spec_row (grp, item_id, position, label, value) VALUES"
                " ('feature_spec', ?, ?, ?, ?)",
                (item_id, db.next_position(conn, "spec_row", *where), new_spec["label"],
                 new_spec["value"]))
    action = form.get("action", "")
    action = action if isinstance(action, str) else ""
    op, _, raw_id = action.partition(":")
    if conf["specs"] and op in ("spec-up", "spec-down", "spec-delete") and raw_id.isdigit():
        spec_id = int(raw_id)
        if op == "spec-delete":
            with conn:
                conn.execute("DELETE FROM spec_row WHERE id = ? AND grp = 'feature_spec'"
                             " AND item_id = ?", (spec_id, item_id))
            render.flash(request, "Caractéristique supprimée.")
        else:
            db.move(conn, "spec_row", spec_id, -1 if op == "spec-up" else 1,
                    "grp = 'feature_spec' AND item_id = ?", (item_id,))
        return back(f"{conf['base']}?ouvert={item_id}#item-{item_id}")
    if conf["specs"] and op == "spec-add":
        return back(f"{conf['base']}?ouvert={item_id}&carac=1#item-{item_id}")
    render.flash(request, conf["saved"])
    return back(f"{conf['base']}#item-{item_id}")


@router.post("/listes/{slug}/{item_id}/supprimer")
def list_delete(slug: str, item_id: int, request: Request, form=Depends(admin_form),
                conn: sqlite3.Connection = Depends(get_conn)):
    conf = list_conf(slug)
    with conn:
        # Les caractéristiques de l'argument partent avec lui (ON DELETE CASCADE).
        conn.execute("DELETE FROM content_item WHERE id = ? AND kind = ?", (item_id, conf["kind"]))
    render.flash(request, conf["deleted"])
    return back(conf["base"])


@router.post("/listes/{slug}/{item_id}/deplacer")
def list_move(slug: str, item_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    kind = list_conf(slug)["kind"]
    direction = -1 if form.get("direction") == "up" else 1
    db.move(conn, "content_item", item_id, direction, "kind = ?", (kind,))
    return back(f"/admin/listes/{slug}#item-{item_id}")


# --- Tableaux : fiche technique, comparatif, barème, installation, caractéristiques

# cols : (colonne, libellé, longueur maximale, zone de texte sur plusieurs lignes).
TABLES = {
    "fiche": {
        "grp": "hero_spec", "page": "fiche", "rows_title": "Fiche technique",
        "rows_help": "Affichée sous les boutons de téléchargement. Sur mobile, seules les trois "
                     "premières lignes s'affichent.",
        "save_note": "Enregistre le haut de page et la fiche ensemble.",
        "saved": "Fiche technique enregistrée.",
        "cols": [("label", "Libellé", 40, False), ("value", "Valeur", 80, False)]},
    "comparatif": {
        "grp": "compare", "page": "comparatif", "rows_title": "Comparatif",
        "rows_help": "Une ligne par critère. Le site affiche Solo en bleu et Duel en vert.",
        "save_note": "", "saved": "Comparatif enregistré.",
        "cols": [("label", "Critère", 60, False), ("value", "Solo", 160, False),
                 ("value2", "Duel", 160, False)]},
    "bareme": {
        "grp": "scoring", "page": "bareme", "rows_title": "Lignes",
        "rows_help": "Chaque valeur s'affiche en face de son libellé : garde des valeurs courtes.",
        "save_note": "", "saved": "Barème enregistré.",
        "cols": [("label", "Libellé", 80, False), ("value", "Valeur", 60, False)]},
    "installation": {
        "grp": "install", "page": "installation", "rows_title": "Étapes",
        "rows_help": "Affichées sous le titre « Installer l'APK », numérotées dans cet ordre. "
                     "Le bloc n'apparaît que si un APK est proposé au téléchargement.",
        "save_note": "", "saved": "Installation enregistrée.",
        "cols": [("label", "Titre", 300, False), ("value", "Précision", 300, True)]},
    # Caractéristiques d'un argument : gérées depuis la page des arguments.
    "caracteristiques": {
        "grp": "feature_spec", "parent": True, "back": "/admin/listes/arguments",
        "cols": [("label", "Libellé", 40, False), ("value", "Valeur", 120, False)]},
}


def table_conf(slug: str) -> dict:
    conf = TABLES.get(slug)
    if conf is None:
        raise HTTPException(404)
    return conf


def table_back(slug: str, conf: dict) -> str:
    return conf.get("back", f"/admin/tableaux/{slug}")


def _required_msg(conf: dict) -> str:
    return f"{conf['cols'][0][1]} : champ obligatoire."


def _row_values(form, conf: dict, prefix: str = "") -> dict[str, str]:
    values = {"label": "", "value": "", "value2": ""}
    for col, _, max_len, _ in conf["cols"]:
        values[col] = text(form, prefix + col, max_len)
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


def table_view(request: Request, conn: sqlite3.Connection, slug: str, *,
               row_vals: dict | None = None, new_vals: dict | None = None,
               header_vals: dict | None = None, errors: dict | None = None,
               add_open: bool = False, status_code: int = 200):
    conf = TABLES[slug]
    rows = []
    for row in db.list_rows(conn, conf["grp"]):
        values = dict(row)
        values.update((row_vals or {}).get(row["id"], {}))
        rows.append(values)
    site = {**db.get_settings(conn), **(header_vals or {})}
    return admin_page(request, "admin/table.html", {
        "slug": slug, "conf": conf, "rows": rows, "groups": groups_for(conf["page"]),
        "vals": site, "errors": errors or {}, "add_open": add_open or bool(new_vals),
        "new_vals": new_vals or {}, "saved_at": db.get_internal(conn, f"_saved:{slug}"),
    }, status_code=status_code, page=conf["page"])


@router.get("/tableaux/{slug}")
def table_page(slug: str, request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    conf = table_conf(slug)
    if conf.get("parent"):
        return back(conf["back"])
    return table_view(request, conn, slug, add_open=request.query_params.get("ajout") == "1")


@router.post("/tableaux/{slug}")
def table_save(slug: str, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    """Enregistre en une fois l'en-tête et toutes les lignes du tableau, puis
    applique `action` : add (nouvelle ligne vide), up:<id>, down:<id>, delete:<id>."""
    conf = table_conf(slug)
    if conf.get("parent"):
        raise HTTPException(404)
    header = setting_values(form, page_keys(conf["page"]))
    errors = validate_settings(header)
    first = conf["cols"][0][1]
    row_vals = {}
    for row in db.list_rows(conn, conf["grp"]):
        if f"row-{row['id']}-label" in form:
            values = _row_values(form, conf, f"row-{row['id']}-")
            row_vals[row["id"]] = values
            if not values["label"]:
                errors[f"row-{row['id']}-label"] = f"{first} : champ obligatoire."
    new_vals = _row_values(form, conf, "new-") if "new-label" in form else {}
    if new_vals and not new_vals["label"] and any(new_vals.values()):
        errors["new-label"] = f"{first} : champ obligatoire."
    if errors:
        return table_view(request, conn, slug, row_vals=row_vals, new_vals=new_vals or None,
                          header_vals=header, errors=errors, status_code=400)
    db.set_settings(conn, header)
    with conn:
        for row_id, values in row_vals.items():
            conn.execute("UPDATE spec_row SET label = ?, value = ?, value2 = ?"
                         " WHERE id = ? AND grp = ?",
                         (values["label"], values["value"], values["value2"], row_id,
                          conf["grp"]))
        if new_vals and new_vals["label"]:
            conn.execute(
                "INSERT INTO spec_row (grp, item_id, position, label, value, value2)"
                " VALUES (?, NULL, ?, ?, ?, ?)",
                (conf["grp"], db.next_position(conn, "spec_row", "grp = ? AND item_id IS NULL",
                                               (conf["grp"],)),
                 new_vals["label"], new_vals["value"], new_vals["value2"]))
    stamp(conn, slug)
    action = form.get("action", "")
    action = action if isinstance(action, str) else ""
    op, _, raw_id = action.partition(":")
    url = f"/admin/tableaux/{slug}"
    if op == "add":
        return back(url + "?ajout=1#nouvelle-ligne")
    if op in ("up", "down", "delete") and raw_id.isdigit():
        row_id = int(raw_id)
        if op == "delete":
            with conn:
                conn.execute("DELETE FROM spec_row WHERE id = ? AND grp = ?", (row_id, conf["grp"]))
            render.flash(request, "Ligne supprimée.")
            return back(url)
        scope = _row_scope(conn, conf, row_id)
        if scope is not None:
            db.move(conn, "spec_row", row_id, -1 if op == "up" else 1, *scope)
        return back(f"{url}#ligne-{row_id}")
    render.flash(request, conf["saved"])
    return back(url)


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
        render.flash(request, _required_msg(conf), "error")
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
        render.flash(request, _required_msg(conf), "error")
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


def _faq_values(form, conn: sqlite3.Connection, faq_id: int | None) -> tuple[dict, dict]:
    values = {
        "question": text(form, "question", 200),
        "answer": text(form, "answer", 2000),
        "short_answer": text(form, "short_answer", 500),
        "anchor": text(form, "anchor", 80).lower(),
    }
    errors = {}
    if not values["question"]:
        errors["question"] = "La question est obligatoire."
    if not values["anchor"]:
        values["anchor"] = slugify(values["question"]) or "question"
    if len(values["anchor"]) > MAX_ANCHOR or not ANCHOR_RE.match(values["anchor"]):
        errors["anchor"] = (f"Identifiant d'ancre invalide : {MAX_ANCHOR} caractères au plus, "
                            "lettres minuscules sans accent, chiffres et tirets "
                            "(ex. duel-connexion).")
    elif values["anchor"] in SECTION_ANCHORS:
        errors["anchor"] = "Ce nom est déjà pris par une section de la page."
    else:
        rows = db.list_faq(conn)
        for n, row in enumerate(rows, 1):
            if row["anchor"] == values["anchor"] and row["id"] != faq_id:
                errors["anchor"] = f"Cette ancre est déjà utilisée par la question {n}."
    return values, errors


def faq_view(request: Request, conn: sqlite3.Connection, **kwargs):
    return list_view(request, conn, "faq", **kwargs)


@router.get("/faq")
def faq_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    raw = request.query_params.get("ouvert", "")
    return faq_view(request, conn, open_id=int(raw) if raw.isdigit() else None,
                    add_open=request.query_params.get("ajout") == "1")


@router.post("/faq/ajouter")
def faq_add(request: Request, form=Depends(admin_form),
            conn: sqlite3.Connection = Depends(get_conn)):
    values, errors = _faq_values(form, conn, None)
    if errors:
        return faq_view(request, conn, add_open=True, add_vals=values,
                        errors={f"new-{k}": v for k, v in errors.items()},
                        banner=("error", LISTS["faq"]["not_added"]), status_code=400)
    with conn:
        conn.execute(
            "INSERT INTO faq (position, anchor, question, answer, short_answer)"
            " VALUES (?, ?, ?, ?, ?)",
            (db.next_position(conn, "faq"), values["anchor"], values["question"],
             values["answer"], values["short_answer"]))
    render.flash(request, LISTS["faq"]["added"])
    return back("/admin/faq")


@router.post("/faq/{faq_id}/modifier")
def faq_edit(faq_id: int, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    if conn.execute("SELECT 1 FROM faq WHERE id = ?", (faq_id,)).fetchone() is None:
        raise HTTPException(404)
    values, errors = _faq_values(form, conn, faq_id)
    if errors:
        return faq_view(request, conn, open_id=faq_id, item_vals=values, errors=errors,
                        banner=("error", LISTS["faq"]["not_saved"]), status_code=400)
    with conn:
        conn.execute(
            "UPDATE faq SET anchor = ?, question = ?, answer = ?, short_answer = ?"
            " WHERE id = ?",
            (values["anchor"], values["question"], values["answer"], values["short_answer"],
             faq_id))
    render.flash(request, LISTS["faq"]["saved"])
    return back(f"/admin/faq#item-{faq_id}")


@router.post("/faq/{faq_id}/supprimer")
def faq_delete(faq_id: int, request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    with conn:
        conn.execute("DELETE FROM faq WHERE id = ?", (faq_id,))
    render.flash(request, LISTS["faq"]["deleted"])
    return back("/admin/faq")


@router.post("/faq/{faq_id}/deplacer")
def faq_move(faq_id: int, request: Request, form=Depends(admin_form),
             conn: sqlite3.Connection = Depends(get_conn)):
    db.move(conn, "faq", faq_id, -1 if form.get("direction") == "up" else 1)
    return back(f"/admin/faq#item-{faq_id}")


# --- Captures d'écran ------------------------------------------------------------

def screens_view(request: Request, conn: sqlite3.Connection, *, header_vals: dict | None = None,
                 shot_vals: dict | None = None, add_vals: dict | None = None,
                 errors: dict | None = None, banner=None, status_code: int = 200):
    shots = []
    for n, row in enumerate(db.list_screenshots(conn), 1):
        values = dict(row)
        values.update((shot_vals or {}).get(row["id"], {}))
        values["n"] = n
        shots.append(values)
    return admin_page(request, "admin/screenshots.html", {
        "shots": shots, "groups": groups_for("captures"),
        "vals": {**db.get_settings(conn), **(header_vals or {})},
        "header_url": "/admin/en-tete/captures", "add_vals": add_vals or {},
        "errors": errors or {}, "banner": banner,
        "max_image_mb": request.app.state.settings.max_image_mb,
    }, status_code=status_code, page="captures")


@router.get("/captures")
def screens_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return screens_view(request, conn)


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
    vals = {"caption": caption, "description": description}
    try:
        name = _screenshot_image(request, form)
    except UploadError as exc:
        return screens_view(request, conn, add_vals=vals, errors={"new-image": image_error(exc)},
                            banner=("error", str(exc)), status_code=400)
    if name is None and not caption:
        return screens_view(request, conn, add_vals=vals,
                            errors={"new-image": "Choisis une image ou écris une légende."},
                            banner=("error", "La capture n'a pas été ajoutée : choisis une "
                                             "image ou écris une légende."), status_code=400)
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
    rows = db.list_screenshots(conn)
    numbers = {r["id"]: n for n, r in enumerate(rows, 1)}
    row = next((r for r in rows if r["id"] == shot_id), None)
    if row is None:
        raise HTTPException(404)
    caption, description = text(form, "caption", 120), text(form, "description", 500)
    try:
        name = _screenshot_image(request, form)
    except UploadError as exc:
        return screens_view(request, conn,
                            shot_vals={shot_id: {"caption": caption, "description": description}},
                            errors={f"image-{shot_id}": image_error(exc)},
                            banner=("error", str(exc)), status_code=400)
    with conn:
        conn.execute("UPDATE screenshot SET caption = ?, description = ?,"
                     " filename = COALESCE(?, filename) WHERE id = ?",
                     (caption, description, name, shot_id))
    if name and row["filename"]:
        delete_file(request.app.state.settings.images_dir, row["filename"])
    n = numbers[shot_id]
    if name:
        render.flash(request, f"Image de la capture {n} "
                              + ("remplacée." if row["filename"] else "ajoutée."))
    else:
        render.flash(request, f"Capture {n} enregistrée.")
    return back(f"/admin/captures#capture-{shot_id}")


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
    return back(f"/admin/captures#capture-{shot_id}")


# --- APK ----------------------------------------------------------------------------

def _release_fields(form) -> tuple[str, str, str | None]:
    """Notes de version et date (facultative) ; renvoie aussi un message d'erreur."""
    notes = text(form, "release_notes", 5000)
    release_date = text(form, "release_date", 10)
    if release_date and not valid_date(release_date):
        return notes, release_date, "Date de version invalide."
    return notes, release_date, None


def apk_view(request: Request, conn: sqlite3.Connection, *, notes_id: int | None = None,
             upload_vals: dict | None = None, notes_vals: dict | None = None,
             errors: dict | None = None, banner=None, status_code: int = 200):
    apks = db.list_apks(conn)
    current = next((a for a in apks if a["is_current"]), None)
    shown = next((a for a in apks if a["id"] == notes_id), None) or current
    site = db.get_settings(conn)
    settings = request.app.state.settings
    return admin_page(request, "admin/apk.html", {
        "apks": apks, "current": current, "notes_apk": shown,
        "notes_vals": notes_vals or ({"release_notes": shown["release_notes"],
                                      "release_date": shown["release_date"]} if shown else {}),
        "upload_vals": upload_vals or {}, "site": site,
        "max_mb": settings.max_apk_mb, "max_bytes": settings.max_apk_bytes,
        # Premier dépôt : notes de la 1.0.0 proposées dans le formulaire.
        "default_notes": "" if apks else db.V2_RELEASE_NOTES_1_0_0,
        "public_url": f"{str(request.base_url).rstrip('/')}/telecharger",
        "download_name": download_name(site.get("game_name", "Tilto"), current["version"])
        if current else "",
        "errors": errors or {}, "banner": banner,
    }, status_code=status_code, page="apk")


@router.get("/apk")
def apk_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    raw = request.query_params.get("version", "")
    return apk_view(request, conn, notes_id=int(raw) if raw.isdigit() else None)


@router.post("/apk/deposer")
def apk_upload(request: Request, form=Depends(admin_form),
               conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    version = text(form, "version", 32)
    notes, release_date, date_error = _release_fields(form)
    make_current = bool(form.get("make_current"))
    vals = {"version": version, "release_notes": notes, "release_date": release_date,
            "make_current": make_current}
    errors = {}
    if not VERSION_RE.match(version):
        errors["version"] = "Numéro de version invalide (exemple : 1.2.0)."
    elif conn.execute("SELECT 1 FROM apk_release WHERE version = ?", (version,)).fetchone():
        errors["version"] = f"La version {version} existe déjà."
    if date_error:
        errors["release_date"] = date_error
    apk_file = upload(form, "apk")
    if apk_file is None:
        errors["apk"] = "Choisis un fichier APK."

    def refused(errs: dict):
        if len(errs) == 1:
            message = next(iter(errs.values()))
        else:
            message = "La version n'a pas été déposée : corrige les champs en rouge."
        return apk_view(request, conn, upload_vals=vals, errors=errs,
                        banner=("error", message), status_code=400)

    if errors:
        return refused(errors)
    try:
        saved = save_apk(apk_file.file, settings.apk_dir, settings.max_apk_bytes)
    except UploadError as exc:
        return refused({"apk": f"{exc} Choisis-le de nouveau."})
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
        return refused({"version": f"La version {version} existe déjà."})
    if make_current:
        render.flash(request, f"Version {version} déposée et publiée : elle est proposée au "
                              "téléchargement." + ("" if notes else
                                                   " Pense à écrire ses notes de version."))
    else:
        render.flash(request, f"Version {version} déposée. Elle n'est pas encore proposée au "
                              "téléchargement.")
    return back("/admin/apk")


@router.post("/apk/{apk_id}/notes")
def apk_notes(apk_id: int, request: Request, form=Depends(admin_form),
              conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT version, is_current FROM apk_release WHERE id = ?",
                       (apk_id,)).fetchone()
    if row is None:
        raise HTTPException(404)
    notes, release_date, error = _release_fields(form)
    if error:
        return apk_view(request, conn, notes_id=apk_id,
                        notes_vals={"release_notes": notes, "release_date": release_date},
                        errors={"release_date": error}, status_code=400)
    with conn:
        conn.execute("UPDATE apk_release SET release_notes = ?, release_date = ? WHERE id = ?",
                     (notes, release_date, apk_id))
    render.flash(request, f"Notes de la version {row['version']} enregistrées.")
    return back("/admin/apk" if row["is_current"] else f"/admin/apk?version={apk_id}#notes")


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
        render.flash(request, "La version proposée ne peut pas être supprimée : propose "
                              "d'abord une autre version.", "error")
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


def messages_view(request: Request, conn: sqlite3.Connection, current: sqlite3.Row | None):
    return admin_page(request, "admin/messages.html", {
        "messages": db.list_messages(conn), "m": current,
        "reply_url": reply_link(current) if current else "",
    }, page="messages")


@router.get("/messages")
def messages_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    require_admin(request)
    return messages_view(request, conn, None)


@router.get("/messages/{message_id}")
def message_page(message_id: int, request: Request,
                 conn: sqlite3.Connection = Depends(get_conn)):
    """Ouvre un message ; l'ouvrir le marque comme lu."""
    require_admin(request)
    message = _message(conn, message_id)
    if not message["is_read"]:
        with conn:
            conn.execute("UPDATE contact_message SET is_read = 1 WHERE id = ?", (message_id,))
        message = _message(conn, message_id)
    return messages_view(request, conn, message)


@router.post("/messages/{message_id}/non-lu")
def message_unread(message_id: int, request: Request, form=Depends(admin_form),
                   conn: sqlite3.Connection = Depends(get_conn)):
    _message(conn, message_id)
    with conn:
        conn.execute("UPDATE contact_message SET is_read = 0 WHERE id = ?", (message_id,))
    render.flash(request, "Message marqué comme non lu.")
    return back("/admin/messages")


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


# Pages réaffichées après un en-tête refusé (POST /admin/en-tete/{page}).
PAGE_VIEWS = {
    "arguments": lambda request, conn, **kw: list_view(request, conn, "arguments", **kw),
    "etapes": lambda request, conn, **kw: list_view(request, conn, "etapes", **kw),
    "faq": lambda request, conn, **kw: list_view(request, conn, "faq", **kw),
    "captures": lambda request, conn, **kw: screens_view(request, conn, **kw),
}
