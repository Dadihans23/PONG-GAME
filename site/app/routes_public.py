"""Pages publiques : présentation, confidentialité, mentions légales, contact,
téléchargement, santé.

Chaque page existe en français (racine), en anglais (/en/…) et en espagnol (/es/…),
à une seule adresse par langue (i18n.PAGES) ; la langue d'une requête se lit dans
son adresse. Les variantes d'adresse (/en sans « / », slug d'une autre langue…)
redirigent (301) vers l'adresse canonique. Aucune redirection selon la langue du
navigateur.
"""

from __future__ import annotations

import logging
import re
import sqlite3
from collections.abc import Iterator
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from fastapi.responses import (FileResponse, JSONResponse, PlainTextResponse,
                               RedirectResponse, Response)

from . import contact, db, i18n, render, seo
from .mailer import notify_contact
from .uploads import IMAGE_TYPES, STORED_NAME, image_size

router = APIRouter()
log = logging.getLogger("tilto.contact")

APK_MIME = "application/vnd.android.package-archive"
GET_HEAD = ["GET", "HEAD"]

# Ancres des sections de la page d'accueil (identiques dans les trois langues). Une
# question de la FAQ ne peut pas prendre l'un de ces identifiants.
SECTION_ANCHORS = {
    "contenu", "le-jeu", "solo-duel", "comment-jouer", "bareme", "captures", "faq",
    "telecharger", "installer-apk", "nouveautes",
}


def get_conn(request: Request) -> Iterator[sqlite3.Connection]:
    yield from db.get_db(request.app.state.settings.db_path)


def request_lang(request: Request) -> str:
    return i18n.lang_of_path(request.url.path)


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


def release_info(row: sqlite3.Row | None, game_name: str, conn: sqlite3.Connection | None = None,
                 lang: str = "fr") -> dict | None:
    """APK courant pour les gabarits : colonnes de la table, plus `date`
    (date de version, ou de dépôt), `notes` (liste, traduite si possible) et
    `download_name`."""
    if row is None:
        return None
    info = db.localize(conn, [row], "apk_release", lang)[0] if conn is not None else dict(row)
    info["date"] = row["release_date"] or row["uploaded_at"][:10]
    info["notes"] = release_notes_lines(info["release_notes"])
    info["download_name"] = download_name(game_name, row["version"])
    return info


# Hauteur d'affichage du logo du studio dans le pied de page (CSS .studio-logo).
LOGO_HEIGHT = 24


def lang_context(request: Request, page: str | None = None) -> dict:
    """Variables de langue communes à toutes les pages publiques, y compris les
    pages d'erreur : langue, textes fixes (`t`), adresses des pages dans la langue
    (`urls`), sélecteur (`languages`), bandeau de suggestion (`lang_suggest`)."""
    lang = request_lang(request)
    site_url = request.app.state.settings.site_url
    indexable = page in i18n.INDEXABLE
    return {
        "lang": lang,
        "t": i18n.catalog(lang),
        "urls": {name: paths[lang] for name, paths in i18n.PAGES.items()},
        "languages": i18n.language_links(page, lang),
        "og_locale": i18n.OG_LOCALE[lang],
        "og_locale_alternates": [i18n.OG_LOCALE[c] for c in i18n.LANGS if c != lang],
        "alternates": i18n.alternates(page, site_url) if indexable else [],
        "canonical_path": i18n.path(page, lang) if indexable else None,
        # Bandeau « Cette page existe en … » (lang.js) : texte écrit dans la langue
        # proposée, adresse de la même page dans cette langue.
        "lang_suggest": [
            {"code": link["code"], "href": link["href"],
             "text": i18n.ui("suggest_text", link["code"]),
             "link": i18n.ui("suggest_link", link["code"]),
             "close": i18n.ui("suggest_close", link["code"])}
            for link in i18n.language_links(page, lang) if not link["current"]],
    }


def site_context(request: Request, conn: sqlite3.Connection, page: str | None = None) -> dict:
    """Variables communes à toutes les pages publiques (en-tête et pied de page),
    dans la langue de l'adresse.

    page : clé de i18n.PAGES. Une page indexable (accueil, contact, confidentialité,
    mentions légales) reçoit son URL canonique, ses hreflang et Open Graph ; les
    autres (message envoyé, erreurs) sont en noindex.
    """
    context = lang_context(request, page)
    lang = context["lang"]
    site = db.get_settings(conn, lang)
    logo = site.get("studio_logo", "")
    site["studio_logo_url"] = f"/media/{logo}" if logo else ""
    # Dimensions du logo (attributs width/height : pas de décalage au chargement).
    size = image_size(request.app.state.settings.images_dir / logo) if logo else None
    site["studio_logo_size"] = (
        (max(1, round(LOGO_HEIGHT * size[0] / size[1])), LOGO_HEIGHT)
        if size and size[1] else None)
    apk = release_info(db.current_apk(conn), site.get("game_name", "Tilto"), conn, lang)
    faq = db.localize(conn, db.list_faq(conn), "faq", lang)
    context.update({
        "site": site,
        "year": datetime.now().year,
        # L'APK courant sert au héros, au bloc final, aux notes de version et
        # à la ligne de crédit du pied de page.
        "apk": apk,
        "faq": faq,
    })
    return context


def page_route(page: str, methods: list[str] | None = None):
    """Déclare une route pour l'adresse de la page dans chacune des trois langues."""
    def decorator(func):
        for lang in i18n.LANGS:
            router.add_api_route(i18n.path(page, lang), func, methods=methods or GET_HEAD)
        return func
    return decorator


@page_route("home")
def home(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    context = site_context(request, conn, "home")
    lang = context["lang"]
    specs: dict[int, list[dict]] = {}
    for row in db.localize(conn, conn.execute(
            "SELECT * FROM spec_row WHERE grp = 'feature_spec' AND item_id IS NOT NULL"
            " ORDER BY position, id").fetchall(), "spec_row", lang):
        specs.setdefault(row["item_id"], []).append(row)
    features = []
    for item in db.localize(conn, db.list_items(conn, "feature"), "content_item", lang):
        item["specs"] = specs.get(item["id"], [])
        features.append(item)

    def rows(grp: str) -> list[dict]:
        return db.localize(conn, db.list_rows(conn, grp), "spec_row", lang)

    context.update(
        hero_specs=rows("hero_spec"),
        features=features,
        compare=rows("compare"),
        steps=db.localize(conn, db.list_items(conn, "step"), "content_item", lang),
        scoring=rows("scoring"),
        screenshots=db.localize(conn, db.list_screenshots(conn), "screenshot", lang),
        install_steps=rows("install"),
    )
    context["home_title_suffix"] = seo.HOME_TITLE_SUFFIXES[lang]
    context["home_description"] = seo.HOME_DESCRIPTIONS[lang]
    context["ld"] = seo.home_json_ld(request.app.state.settings.site_url, context, lang)
    return render.page(request, "index.html", context)


@page_route("privacy")
def privacy(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    return render.page(request, "privacy.html", site_context(request, conn, "privacy"))


# --- Mentions légales ----------------------------------------------------------

def legal_sections(site: dict, lang: str = "fr") -> list[dict]:
    """Sections des mentions légales, sans les champs vides. Les valeurs (noms,
    adresses) sont les mêmes dans les trois langues ; seuls les libellés changent."""
    t = i18n.catalog(lang)

    def rows(*pairs):
        return [{"label": label, "value": site.get(key, "").strip()}
                for label, key in pairs if site.get(key, "").strip()]

    sections = [
        {"title": t.legal_publisher, "rows": rows(
            (t.legal_l_name_company, "legal_publisher"), (t.legal_l_form, "legal_form"),
            (t.legal_l_registration, "legal_registration"), (t.legal_l_address, "legal_address"),
            (t.legal_l_email, "legal_email"), (t.legal_l_phone, "legal_phone"))},
        {"title": t.legal_director, "rows": rows((t.legal_l_name, "legal_director"))},
        {"title": t.legal_host, "rows": rows(
            (t.legal_l_name, "legal_host_name"), (t.legal_l_address, "legal_host_address"),
            (t.legal_l_phone, "legal_host_phone"))},
    ]
    return [s for s in sections if s["rows"]]


@page_route("legal")
def legal(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    context = site_context(request, conn, "legal")
    context["legal_sections"] = legal_sections(context["site"], context["lang"])
    return render.page(request, "legal.html", context)


# --- Contact ---------------------------------------------------------------------

def _clock(request: Request) -> float:
    return request.app.state.contact_clock()


def _contact_page(request: Request, conn: sqlite3.Connection, form: contact.ContactForm,
                  nonce: str, status_code: int = 200):
    settings = request.app.state.settings
    context = site_context(request, conn, "contact")
    t = context["t"]
    context.update(
        form=form,
        subjects=[{"value": s, "label": t.subject(s)} for s in contact.SUBJECTS],
        max_message=contact.MAX_MESSAGE,
        honeypot=contact.HONEYPOT_FIELD,
        contact_token=contact.issue_token(settings.secret_key, nonce, _clock(request)),
    )
    response = render.page(request, "contact.html", context, status_code=status_code,
                           headers={"Cache-Control": "no-store"})
    # Cookie limité à la page Contact de la langue (le formulaire y est renvoyé).
    response.set_cookie(
        contact.COOKIE_NAME, nonce, path=i18n.path("contact", context["lang"]), httponly=True,
        samesite="strict", secure=settings.cookie_secure,
    )
    return response


def _cookie_nonce(request: Request) -> str | None:
    value = request.cookies.get(contact.COOKIE_NAME, "")
    return value if re.fullmatch(r"[A-Za-z0-9_-]{20,64}", value) else None


@page_route("contact")
def contact_page(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    nonce = _cookie_nonce(request) or contact.new_nonce()
    return _contact_page(request, conn, contact.ContactForm(), nonce)


@page_route("contact", methods=["POST"])
async def contact_send(request: Request, background: BackgroundTasks,
                       conn: sqlite3.Connection = Depends(get_conn)):
    settings = request.app.state.settings
    lang = request_lang(request)
    thanks = i18n.path("contact_sent", lang)
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
        data.errors = [i18n.ui("err_token", lang)]
        return _contact_page(request, conn, data, nonce, status_code=403)

    if form.get(contact.HONEYPOT_FIELD):
        # Robot : on fait comme si tout s'était bien passé, sans rien enregistrer.
        log.info("Message de contact ignoré (champ piège rempli)")
        return RedirectResponse(thanks, status_code=303)

    if elapsed < settings.contact_min_seconds:
        data.errors = [i18n.ui("err_fast", lang)]
        return _contact_page(request, conn, data, nonce, status_code=400)

    ip = request.client.host if request.client else "inconnu"
    per_ip = request.app.state.contact_limiter
    overall = request.app.state.contact_global_limiter
    if per_ip.blocked(ip) or overall.blocked("*"):
        data.errors = [i18n.ui("err_rate", lang)]
        return _contact_page(request, conn, data, nonce, status_code=429)

    if not data.validate(lang):
        return _contact_page(request, conn, data, nonce, status_code=400)

    with conn:
        conn.execute(
            "INSERT INTO contact_message (created_at, name, email, subject, message, lang)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (db.now_iso(), data.name, data.email, data.subject, data.message, lang))
    per_ip.hit(ip)
    overall.hit("*")

    if settings.smtp is not None:
        site_name = db.get_settings(conn).get("game_name", "Tilto")
        admin_url = str(request.base_url).rstrip("/") + "/admin/messages"
        background.add_task(
            notify_contact, settings.smtp,
            {"name": data.name, "email": data.email, "subject": data.subject,
             "message": data.message, "lang": lang},
            site_name, admin_url)
    return RedirectResponse(thanks, status_code=303)


@page_route("contact_sent")
def contact_thanks(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    return render.page(request, "contact_sent.html", site_context(request, conn, "contact_sent"))


# --- Variantes d'adresse : redirection permanente vers l'adresse canonique ---------

def _redirect_to(target: str):
    def redirect(request: Request):
        query = request.url.query
        return RedirectResponse(target + (f"?{query}" if query else ""), status_code=301)
    return redirect


for _source, _target in i18n.redirects().items():
    router.add_api_route(_source, _redirect_to(_target), methods=GET_HEAD,
                         include_in_schema=False)


# --- Fichiers ----------------------------------------------------------------------

@router.api_route("/telecharger", methods=GET_HEAD)
def download(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    apk = db.current_apk(conn)
    settings = request.app.state.settings
    path = settings.apk_dir / apk["filename"] if apk else None
    if apk is None or not path.is_file():
        raise HTTPException(404, i18n.ui("err_no_apk", "fr"))
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


@router.api_route("/sante", methods=GET_HEAD)
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

@router.api_route("/robots.txt", methods=GET_HEAD)
def robots(request: Request):
    return PlainTextResponse(seo.robots_txt(request.app.state.settings.site_url),
                             headers={"Cache-Control": "public, max-age=86400"})


@router.api_route("/sitemap.xml", methods=GET_HEAD)
def sitemap(request: Request, conn: sqlite3.Connection = Depends(get_conn)):
    site = db.get_settings(conn)
    apk = release_info(db.current_apk(conn), site.get("game_name", "Tilto"))
    body = seo.sitemap_xml(request.app.state.settings.site_url, site, apk)
    return Response(body, media_type="application/xml",
                    headers={"Cache-Control": "public, max-age=3600"})


@router.api_route("/.well-known/security.txt", methods=GET_HEAD)
def security_txt(request: Request):
    return PlainTextResponse(seo.security_txt(request.app.state.settings.site_url),
                             headers={"Cache-Control": "public, max-age=86400"})
