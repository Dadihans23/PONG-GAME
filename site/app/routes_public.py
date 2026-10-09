"""Pages publiques : présentation, confidentialité, mentions légales, contact,
téléchargement, santé."""

from __future__ import annotations

import logging
import re
import sqlite3
from collections.abc import Iterator
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from fastapi.responses import (FileResponse, JSONResponse, PlainTextResponse,
                               RedirectResponse, Response)

from . import contact, db, render, seo
from .mailer import notify_contact
from .uploads import IMAGE_TYPES, STORED_NAME, image_size

router = APIRouter()
log = logging.getLogger("tilto.contact")

APK_MIME = "application/vnd.android.package-archive"

# Ancres des sections de la page d'accueil. Une question de la FAQ ne peut pas
# prendre l'un de ces identifiants.
SECTION_ANCHORS = {
    "contenu", "le-jeu", "solo-duel", "comment-jouer", "bareme", "captures", "faq",
    "telecharger", "installer-apk", "nouveautes",
}


def get_conn(request: Request) -> Iterator[sqlite3.Connection]:
    yield from db.get_db(request.app.state.settings.db_path)


def download_name(game_name: str, version: str) -> str:
    base = re.sub(r"[^A-Za-z0-9_-]", "", game_name) or "Tilto"
    return f"{base}-{version}.apk"


def release_notes_lines(text: str) -> list[str]:
    """Une nouveauté par ligne ; les puces saisies (-, —, •) sont retirées."""
    lines = []
    for line in (text or "").splitlines():
        line = re.sub(r"^\s*[-—–•*]\s*", "", line).strip()
        if line:
            lines.append(line)
    return lines


def release_info(row: sqlite3.Row | None, game_name: str) -> dict | None:
    """APK courant pour les gabarits : colonnes de la table, plus `date`
    (date de version, ou de dépôt), `notes` (liste) et `download_name`."""
    if row is None:
        return None
    info = dict(row)
    info["date"] = row["release_date"] or row["uploaded_at"][:10]
    info["notes"] = release_notes_lines(row["release_notes"])
    info["download_name"] = download_name(game_name, row["version"])
    return info


def footer_links(site: dict, apk: dict | None) -> list[dict]:
    """Liens du pied de page : seulement de vraies destinations, jamais d'ancre
    de l'accueil (la navigation du haut s'en charge). Téléchargements d'abord,
    s'ils existent, puis les pages du studio. [{label, href, external}]."""
    def link(label: str, href: str, external: bool = False) -> dict:
        return {"label": label, "href": href, "external": external}

    links = []
    if site.get("play_store_url"):
        links.append(link("Google Play", site["play_store_url"], external=True))
    if apk:
        links.append(link(f"Télécharger l'APK v{apk['version']}", "/telecharger"))
    links += [link("Contact", "/contact"),
              link("Politique de confidentialité", "/confidentialite"),
              link("Mentions légales", "/mentions-legales")]
    return links


# Hauteur d'affichage du logo du studio dans le pied de page (CSS .studio-logo).
LOGO_HEIGHT = 24


def site_context(request: Request, conn: sqlite3.Connection,
                 canonical_path: str | None = None) -> dict:
    """Variables communes à toutes les pages publiques (en-tête et pied de page).

    canonical_path : chemin de la page indexable (« / », « /contact »…), pour
    l'URL canonique et Open Graph ; None pour une page à ne pas indexer.
    """
    site = db.get_settings(conn)
    logo = site.get("studio_logo", "")
    site["studio_logo_url"] = f"/media/{logo}" if logo else ""
    # Dimensions du logo (attributs width/height : pas de décalage au chargement).
    size = image_size(request.app.state.settings.images_dir / logo) if logo else None
    site["studio_logo_size"] = (
        (max(1, round(LOGO_HEIGHT * size[0] / size[1])), LOGO_HEIGHT)
        if size and size[1] else None)
    apk = release_info(db.current_apk(conn), site.get("game_name", "Tilto"))
    faq = db.list_faq(conn)
    return {
        "site": site,
        "year": datetime.now().year,
        # L'APK courant sert au héros, au bloc final, aux notes de version et
        # au pied de page.
        "apk": apk,
        "faq": faq,
        "footer_links": footer_links(site, apk),
        "canonical_path": canonical_path,
    }


@router.api_route("/", methods=["GET", "HEAD"])
def home(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    context = site_context(request, conn, "/")
    specs = db.rows_by_item(conn, "feature_spec")
    features = []
    for item in db.list_items(conn, "feature"):
        feature = dict(item)
        feature["specs"] = specs.get(item["id"], [])
        features.append(feature)
    context.update(
        hero_specs=db.list_rows(conn, "hero_spec"),
        features=features,
        compare=db.list_rows(conn, "compare"),
        steps=db.list_items(conn, "step"),
        scoring=db.list_rows(conn, "scoring"),
        screenshots=db.list_screenshots(conn),
        install_steps=db.list_rows(conn, "install"),
    )
    context["home_title_suffix"] = seo.HOME_TITLE_SUFFIX
    context["home_description"] = seo.HOME_DESCRIPTION
    context["ld"] = seo.home_json_ld(request.app.state.settings.site_url, context)
    return render.page(request, "index.html", context)


@router.api_route("/confidentialite", methods=["GET", "HEAD"])
def privacy(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    return render.page(request, "privacy.html",
                       site_context(request, conn, "/confidentialite"))


# --- Mentions légales ----------------------------------------------------------

def legal_sections(site: dict) -> list[dict]:
    """Sections des mentions légales, sans les champs vides."""
    def rows(*pairs):
        return [{"label": label, "value": site.get(key, "").strip()}
                for label, key in pairs if site.get(key, "").strip()]

    sections = [
        {"title": "Éditeur du site", "rows": rows(
            ("Nom ou raison sociale", "legal_publisher"), ("Forme juridique", "legal_form"),
            ("Immatriculation", "legal_registration"), ("Adresse", "legal_address"),
            ("E-mail", "legal_email"), ("Téléphone", "legal_phone"))},
        {"title": "Directeur de la publication", "rows": rows(("Nom", "legal_director"))},
        {"title": "Hébergeur", "rows": rows(
            ("Nom", "legal_host_name"), ("Adresse", "legal_host_address"),
            ("Téléphone", "legal_host_phone"))},
    ]
    return [s for s in sections if s["rows"]]


@router.api_route("/mentions-legales", methods=["GET", "HEAD"])
def legal(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    context = site_context(request, conn, "/mentions-legales")
    context["legal_sections"] = legal_sections(context["site"])
    return render.page(request, "legal.html", context)


# --- Contact ---------------------------------------------------------------------

def _clock(request: Request) -> float:
    return request.app.state.contact_clock()


def _contact_page(request: Request, conn: sqlite3.Connection, form: contact.ContactForm,
                  nonce: str, status_code: int = 200):
    settings = request.app.state.settings
    context = site_context(request, conn, "/contact")
    context.update(
        form=form,
        subjects=contact.SUBJECTS,
        max_message=contact.MAX_MESSAGE,
        honeypot=contact.HONEYPOT_FIELD,
        contact_token=contact.issue_token(settings.secret_key, nonce, _clock(request)),
    )
    response = render.page(request, "contact.html", context, status_code=status_code,
                           headers={"Cache-Control": "no-store"})
    response.set_cookie(
        contact.COOKIE_NAME, nonce, path=contact.COOKIE_PATH, httponly=True,
        samesite="strict", secure=settings.cookie_secure,
    )
    return response


def _cookie_nonce(request: Request) -> str | None:
    value = request.cookies.get(contact.COOKIE_NAME, "")
    return value if re.fullmatch(r"[A-Za-z0-9_-]{20,64}", value) else None


@router.api_route("/contact", methods=["GET", "HEAD"])
def contact_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    nonce = _cookie_nonce(request) or contact.new_nonce()
    return _contact_page(request, conn, contact.ContactForm(), nonce)


@router.post("/contact")
async def contact_send(request: Request, background: BackgroundTasks,
                       conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    form = await request.form()
    data = contact.ContactForm.from_form(form)
    cookie_nonce = _cookie_nonce(request)
    nonce = cookie_nonce or contact.new_nonce()
    token = form.get("csrf_token")
    try:
        elapsed = contact.check_token(settings.secret_key,
                                      token if isinstance(token, str) else None,
                                      cookie_nonce, _clock(request))
    except contact.TokenError:
        data.errors = ["Le formulaire a expiré ou n'est plus valide. "
                       "Vérifie ton message et renvoie-le."]
        return _contact_page(request, conn, data, nonce, status_code=403)

    if form.get(contact.HONEYPOT_FIELD):
        # Robot : on fait comme si tout s'était bien passé, sans rien enregistrer.
        log.info("Message de contact ignoré (champ piège rempli)")
        return RedirectResponse("/contact/merci", status_code=303)

    if elapsed < settings.contact_min_seconds:
        data.errors = ["Le formulaire a été envoyé trop vite. "
                       "Attends quelques secondes, puis renvoie-le."]
        return _contact_page(request, conn, data, nonce, status_code=400)

    ip = request.client.host if request.client else "inconnu"
    per_ip = request.app.state.contact_limiter
    overall = request.app.state.contact_global_limiter
    if per_ip.blocked(ip) or overall.blocked("*"):
        data.errors = ["Trop de messages envoyés depuis cette connexion. "
                       "Réessaie dans une heure."]
        return _contact_page(request, conn, data, nonce, status_code=429)

    if not data.validate():
        return _contact_page(request, conn, data, nonce, status_code=400)

    with conn:
        conn.execute(
            "INSERT INTO contact_message (created_at, name, email, subject, message)"
            " VALUES (?, ?, ?, ?, ?)",
            (db.now_iso(), data.name, data.email, data.subject, data.message))
    per_ip.hit(ip)
    overall.hit("*")

    if settings.smtp is not None:
        site_name = db.get_settings(conn).get("game_name", "Tilto")
        admin_url = str(request.base_url).rstrip("/") + "/admin/messages"
        background.add_task(
            notify_contact, settings.smtp,
            {"name": data.name, "email": data.email, "subject": data.subject,
             "message": data.message},
            site_name, admin_url)
    return RedirectResponse("/contact/merci", status_code=303)


@router.api_route("/contact/merci", methods=["GET", "HEAD"])
def contact_thanks(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    return render.page(request, "contact_sent.html", site_context(request, conn))


# --- Fichiers ----------------------------------------------------------------------

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


# --- Référencement : robots.txt, sitemap.xml, security.txt -------------------------

@router.api_route("/robots.txt", methods=["GET", "HEAD"])
def robots(request: Request):
    return PlainTextResponse(seo.robots_txt(request.app.state.settings.site_url),
                             headers={"Cache-Control": "public, max-age=86400"})


@router.api_route("/sitemap.xml", methods=["GET", "HEAD"])
def sitemap(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    site = db.get_settings(conn)
    apk = release_info(db.current_apk(conn), site.get("game_name", "Tilto"))
    body = seo.sitemap_xml(request.app.state.settings.site_url, site, apk)
    return Response(body, media_type="application/xml",
                    headers={"Cache-Control": "public, max-age=3600"})


@router.api_route("/.well-known/security.txt", methods=["GET", "HEAD"])
def security_txt(request: Request):
    return PlainTextResponse(seo.security_txt(request.app.state.settings.site_url),
                             headers={"Cache-Control": "public, max-age=86400"})
