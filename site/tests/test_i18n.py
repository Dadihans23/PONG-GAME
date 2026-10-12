"""Site multilingue : français à la racine, anglais sous /en/, espagnol sous /es/.

Routes et redirections, balises de langue (html lang, hreflang, canonique, Open
Graph, JSON-LD), sitemap, repli sur le français, textes fixes traduits, bandeau de
suggestion, pages d'erreur, formulaire de contact, API ?lang=, onglets de
l'administration et migration reseed_i18n."""

import json
import re
import shutil
import sqlite3
import xml.etree.ElementTree as ET
from html import unescape

import pytest

from app import content_i18n, db, i18n, reseed_i18n
from conftest import admin_csrf, csrf_from, make_apk, visible

PAGES = {
    "home": ("/", "/en/", "/es/"),
    "contact": ("/contact", "/en/contact", "/es/contacto"),
    "privacy": ("/confidentialite", "/en/privacy", "/es/privacidad"),
    "legal": ("/mentions-legales", "/en/legal-notice", "/es/aviso-legal"),
}
LANGS = ("fr", "en", "es")
SITE = "https://tilto.fun"


def html_lang(page: str) -> str:
    return re.search(r'<html lang="([^"]+)"', page).group(1)


def alternates(page: str) -> dict[str, str]:
    return dict(re.findall(r'<link rel="alternate" hreflang="([^"]+)" href="([^"]+)">', page))


def canonical(page: str) -> str | None:
    match = re.search(r'<link rel="canonical" href="([^"]*)"', page)
    return match.group(1) if match else None


def conn_of(settings):
    return db.connect(settings.db_path)


class FakeClock:
    def __init__(self, now=1_800_000_000.0):
        self.now = now

    def __call__(self):
        return self.now


@pytest.fixture
def clock(client):
    c = FakeClock()
    client.app.state.contact_clock = c
    return c


# --- Adresses ---------------------------------------------------------------------

def test_every_page_exists_in_three_languages(client):
    for paths in PAGES.values():
        for lang, path in zip(LANGS, paths):
            r = client.get(path)
            assert r.status_code == 200, path
            assert html_lang(r.text) == lang, path
            assert canonical(r.text) == SITE + path


def test_paths_registry_matches():
    for page, paths in PAGES.items():
        assert tuple(i18n.path(page, lang) for lang in LANGS) == paths
    assert i18n.lang_of_path("/en/privacy") == "en"
    assert i18n.lang_of_path("/es/") == "es"
    assert i18n.lang_of_path("/english") == "fr"
    assert i18n.lang_of_path("/contact") == "fr"


@pytest.mark.parametrize("source,target", [
    ("/en", "/en/"), ("/es", "/es/"), ("/fr", "/"), ("/fr/", "/"),
    ("/en/privacy/", "/en/privacy"), ("/contact/", "/contact"),
    ("/en/confidentialite", "/en/privacy"), ("/es/privacy", "/es/privacidad"),
    ("/es/contact", "/es/contacto"), ("/en/mentions-legales", "/en/legal-notice"),
    ("/fr/contact", "/contact"), ("/privacy", "/confidentialite"),
])
def test_variants_redirect_permanently(client, source, target):
    r = client.get(source, follow_redirects=False)
    assert r.status_code == 301
    assert r.headers["location"] == target


def test_redirect_keeps_query_string(client):
    r = client.get("/en?utm_source=x", follow_redirects=False)
    assert r.headers["location"] == "/en/?utm_source=x"


def test_no_redirect_by_browser_language(client):
    """Aucune redirection selon Accept-Language : la racine reste en français."""
    for header in ("en-US,en;q=0.9", "es-MX,es;q=0.8"):
        r = client.get("/", headers={"Accept-Language": header}, follow_redirects=False)
        assert r.status_code == 200 and html_lang(r.text) == "fr"


# --- Balises de langue ----------------------------------------------------------------

def test_hreflang_reciprocal_with_x_default(client):
    for page, paths in PAGES.items():
        expected = {lang: SITE + path for lang, path in zip(LANGS, paths)}
        expected["x-default"] = SITE + paths[0]
        for path in paths:
            assert alternates(client.get(path).text) == expected, path


def test_open_graph_locale(client):
    locales = {"fr": "fr_FR", "en": "en_US", "es": "es_ES"}
    for lang, path in zip(LANGS, PAGES["home"]):
        page = client.get(path).text
        assert f'<meta property="og:locale" content="{locales[lang]}">' in page
        others = re.findall(r'<meta property="og:locale:alternate" content="([^"]+)">', page)
        assert sorted(others) == sorted(v for k, v in locales.items() if k != lang)
        assert f'<meta property="og:url" content="{SITE + path}">' in page


def test_json_ld_in_page_language(client):
    for lang, path in zip(LANGS, PAGES["home"]):
        page = client.get(path).text
        data = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>',
                                    page, re.S).group(1))
        nodes = {n["@type"]: n for n in data["@graph"]}
        assert nodes["WebSite"]["inLanguage"] == lang
        assert nodes["WebSite"]["url"] == SITE + path
        assert nodes["FAQPage"]["inLanguage"] == lang
        # Le studio est le même partout.
        assert nodes["Organization"]["@id"] == SITE + "/#studio"
    es = client.get("/es/").text
    assert "¿Hace falta internet para jugar?" in unescape(es)


def test_noindex_pages_have_no_hreflang(client):
    for path in ("/contact/merci", "/en/contact/thanks", "/es/contacto/gracias", "/en/xyz"):
        page = client.get(path).text
        assert '<meta name="robots" content="noindex">' in page
        assert "hreflang=\"x-default\"" not in page


def test_sitemap_lists_all_languages_with_alternates(client):
    root = ET.fromstring(client.get("/sitemap.xml").content)
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9", "x": "http://www.w3.org/1999/xhtml"}
    urls = root.findall("s:url", ns)
    assert len(urls) == 12
    for url in urls:
        links = {link.get("hreflang"): link.get("href") for link in url.findall("x:link", ns)}
        assert set(links) == {"fr", "en", "es", "x-default"}
        assert url.find("s:loc", ns).text in links.values()
        assert links["x-default"] == links["fr"]


def test_robots_txt_unchanged_in_substance(client):
    text = client.get("/robots.txt").text
    assert "Disallow: /api/" in text and "User-agent: GPTBot" in text
    assert "Disallow: /en/\n" not in text and "Disallow: /es/\n" not in text


# --- Textes : catalogue fixe et contenu de la base ----------------------------------------

def test_catalog_complete():
    for key, texts in i18n.UI.items():
        assert set(texts) == set(LANGS), key
        for lang in ("en", "es"):
            if texts["fr"]:
                assert texts[lang], (key, lang)
        # Mêmes valeurs à insérer dans les trois langues.
        fields = {lang: sorted(re.findall(r"\{(\w+)\}", texts[lang])) for lang in LANGS}
        assert fields["en"] == fields["es"], key
        if texts["fr"]:
            assert fields["fr"] == fields["en"], key


FRENCH_UI = ["Aller au contenu", "Politique de confidentialité", "Mentions légales",
             "Télécharger", "Retour à l'accueil", "Passer en mode", "Fermer le menu",
             "Revenir en haut", "Comment jouer", "Liens utiles", "Navigation principale",
             "un jeu de Nexora", "Ton adresse e-mail", "Envoyer le message", "caractères"]


@pytest.mark.parametrize("path", ["/en/", "/es/", "/en/contact", "/es/contacto", "/en/privacy",
                                  "/es/aviso-legal", "/en/nope", "/es/nope"])
def test_no_french_interface_text_on_translated_pages(client, path):
    page = unescape(client.get(path).text)
    # Le bandeau de suggestion (modèle inerte) contient volontairement la phrase
    # française : on l'ignore.
    page = re.sub(r"<template id=\"lang-suggest\">.*?</template>", "", page, flags=re.S)
    for text in FRENCH_UI:
        assert text not in page, (path, text)


def test_new_database_is_translated(client):
    en = visible(client.get("/en/").text)
    es = visible(client.get("/es/").text)
    assert "The Pong you play by tilting your phone." in en
    assert "No buttons. You tilt, the paddle follows." in en
    assert "El Pong que se juega inclinando el teléfono." in es
    assert "Toma tu teléfono con las dos manos." in es
    assert "Le Pong qu'on joue" not in en


def test_fallback_to_french_when_translation_missing(client, settings):
    conn = conn_of(settings)
    with conn:
        conn.execute("DELETE FROM translation WHERE lang = 'en' AND field = 'tagline'")
        conn.execute("DELETE FROM translation WHERE lang = 'es' AND tbl = 'faq'")
    conn.close()
    en = visible(client.get("/en/").text)
    assert "Le Pong qu'on joue en inclinant son téléphone." in en
    assert "Skip to content" in en  # l'interface reste en anglais
    es = unescape(client.get("/es/").text)
    assert "Faut-il Internet pour jouer" in es
    assert "Saltar" not in es and "Ir al contenido" in es


def test_existing_database_without_translations_falls_back(client, settings):
    conn = conn_of(settings)
    with conn:
        conn.execute("DELETE FROM translation")
    conn.close()
    page = visible(client.get("/es/").text)
    assert "Le Pong qu'on joue en inclinant son téléphone." in page
    assert "Ir al contenido" in page and "Política de privacidad" in page


def test_dates_and_sizes_in_page_language(admin):
    token = admin_csrf(admin, "/admin/apk")
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                           "release_date": "2026-10-09", "make_current": "1",
                                           "release_notes": db.V2_RELEASE_NOTES_1_0_0},
               files={"apk": ("a.apk", make_apk(b"x" * 3000), "application/octet-stream")})
    assert "9 oct. 2026" in admin.get("/").text
    en = unescape(admin.get("/en/").text)
    assert "Oct 9, 2026" in en and "What's new in 1.0.0" in en
    es = unescape(admin.get("/es/").text)
    assert "9 oct 2026" in es and "Novedades 1.0.0" in es
    # Notes de version : une nouvelle version n'est pas traduite d'office (repli).
    assert "Solo contre l'ordinateur" in en


def test_legal_pages_say_french_prevails(client):
    fr = unescape(client.get("/confidentialite").text)
    assert "fait foi" not in fr and "page__official" not in fr
    en = unescape(client.get("/en/privacy").text)
    assert "the French version prevails" in en and 'href="/confidentialite"' in en
    assert "Last updated: October 12, 2026" in en
    es = unescape(client.get("/es/aviso-legal").text)
    assert "prevalece la versión en francés" in es and 'href="/mentions-legales"' in es
    # Libellés des mentions légales traduits, valeurs communes.
    assert "Proveedor de alojamiento" in es and "Contabo GmbH" in es


def test_language_selector_points_to_same_page(client):
    page = client.get("/en/privacy").text
    links = re.findall(r'<a class="lang__item" href="([^"]+)" hreflang="([^"]+)"', page)
    assert ("/confidentialite", "fr") in links and ("/es/privacidad", "es") in links
    assert 'href="/en/privacy" hreflang="en" lang="en" title="English" data-set-lang="en" ' \
           'aria-current="true"' in page


def test_language_suggestion_banner_is_inert(client):
    page = client.get("/en/contact").text
    template = re.search(r'<template id="lang-suggest">(.*?)</template>', page, re.S).group(1)
    # Les deux autres langues, chacune écrite dans sa langue, vers la même page.
    assert 'data-suggest="fr"' in template and 'data-suggest="es"' in template
    assert 'data-suggest="en"' not in template
    assert "Ce site existe aussi en français." in unescape(template)
    assert 'href="/es/contacto"' in template
    assert template.count("data-nosnippet") == 2
    main = page.split('<main id="contenu"', 1)[1]
    assert "lang-suggest" not in main  # hors du contenu principal
    js = client.get("/static/js/lang.js").text
    assert "localStorage" in js and "try {" in js
    assert "location" not in js  # aucune redirection


# --- Pages d'erreur -------------------------------------------------------------------

@pytest.mark.parametrize("path,lang,text", [
    ("/nexiste-pas", "fr", "Cette page n'existe pas."),
    ("/en/xyz", "en", "This page doesn't exist."),
    ("/es/xyz", "es", "Esta página no existe."),
])
def test_404_in_prefix_language(client, path, lang, text):
    r = client.get(path)
    assert r.status_code == 404
    assert html_lang(r.text) == lang
    assert text in unescape(r.text)
    home = {"fr": "/", "en": "/en/", "es": "/es/"}[lang]
    assert f'class="btn btn--primary" href="{home}"' in r.text


def test_405_in_prefix_language(client):
    r = client.post("/es/privacidad")
    assert r.status_code == 405
    assert "Método no permitido." in unescape(r.text)


# --- Formulaire de contact ---------------------------------------------------------------

def contact_token(client, path):
    r = client.get(path)
    cookie = r.headers["set-cookie"].lower()
    assert f"path={path}" in cookie
    return csrf_from(r.text)


@pytest.mark.parametrize("path,thanks,lang", [
    ("/contact", "/contact/merci", "fr"),
    ("/en/contact", "/en/contact/thanks", "en"),
    ("/es/contacto", "/es/contacto/gracias", "es"),
])
def test_contact_in_three_languages(client, clock, settings, path, thanks, lang):
    token = contact_token(client, path)
    clock.now += 5
    r = client.post(path, data={"csrf_token": token, "email": "ana@example.com",
                                "subject": "Problème technique", "message": "Hola", "website": ""},
                    follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == thanks
    assert client.get(thanks).status_code == 200
    conn = conn_of(settings)
    row = conn.execute("SELECT subject, lang FROM contact_message").fetchone()
    conn.close()
    # Le sujet est enregistré en français (l'administration est en français).
    assert (row["subject"], row["lang"]) == ("Problème technique", lang)


def test_contact_errors_in_page_language(client, clock):
    token = contact_token(client, "/es/contacto")
    clock.now += 5
    r = client.post("/es/contacto", data={"csrf_token": token, "email": "", "subject": "Autre",
                                          "message": "", "website": ""})
    assert r.status_code == 400
    page = unescape(r.text)
    assert "Escribe tu correo electrónico" in page and "Escribe tu mensaje." in page
    assert "Hay 2 campos que corregir:" in page
    assert '<option value="Autre" selected>Otro</option>' in page
    r = client.post("/en/contact", data={"csrf_token": "faux", "email": "a@b.co",
                                         "message": "x"})
    assert r.status_code == 403
    assert "The form has expired" in unescape(r.text)


def test_contact_counter_texts_translated(client):
    page = unescape(client.get("/en/contact").text)
    assert 'data-live="{used} / {max} characters"' in page
    assert "2000 characters maximum." in page


def test_admin_messages_show_language(admin, clock, settings):
    clock.now += 0
    token = contact_token(admin, "/en/contact")
    clock.now += 5
    admin.post("/en/contact", data={"csrf_token": token, "email": "joe@example.com",
                                    "subject": "Question", "message": "Hi!", "website": ""})
    page = unescape(admin.get("/admin/messages").text)
    assert 'class="lang-badge"' in page and ">EN<" in page
    conn = conn_of(settings)
    msg_id = conn.execute("SELECT id FROM contact_message").fetchone()[0]
    conn.close()
    assert "page en anglais" in unescape(admin.get(f"/admin/messages/{msg_id}").text)


# --- API de l'app ---------------------------------------------------------------------------

API = "/api/app/studio"


def set_about(admin, lang, text):
    token = admin_csrf(admin, "/admin/studio" + ("" if lang == "fr" else f"?lang={lang}"))
    data = {"csrf_token": token, "lang": lang, "studio_about": text}
    if lang == "fr":
        data["studio_name"] = "Nexora"
    r = admin.post("/admin/studio", data=data, follow_redirects=False)
    assert r.status_code == 303


def test_api_language_with_french_fallback(admin):
    set_about(admin, "fr", "Studio indépendant.")
    set_about(admin, "en", "Independent studio.")
    fr = admin.get(API).json()
    assert fr["studio"]["about"] == "Studio indépendant."
    assert fr["studio"]["website"] == SITE and fr["studio"]["contact_url"] == SITE + "/contact"
    en = admin.get(API + "?lang=en").json()
    assert en["studio"]["about"] == "Independent studio."
    assert en["studio"]["website"] == SITE + "/en/"
    assert en["studio"]["contact_url"] == SITE + "/en/contact"
    es = admin.get(API + "?lang=es").json()
    assert es["studio"]["about"] == "Studio indépendant."  # pas de traduction : français
    assert es["studio"]["contact_url"] == SITE + "/es/contacto"
    for unknown in ("de", "", "EN-us", "../x"):
        assert admin.get(API + f"?lang={unknown}").json()["studio"]["about"] == \
            "Studio indépendant."
    assert set(en) == {"schema", "studio", "logo", "updated_at"} and en["schema"] == 1


def test_api_etag_depends_on_language(client):
    fr = client.get(API).headers["etag"]
    en = client.get(API + "?lang=en").headers["etag"]
    es = client.get(API + "?lang=es").headers["etag"]
    assert len({fr, en, es}) == 3
    assert client.get(API + "?lang=en", headers={"If-None-Match": en}).status_code == 304
    assert client.get(API + "?lang=en", headers={"If-None-Match": fr}).status_code == 200
    # Langue inconnue = français, même ETag.
    assert client.get(API + "?lang=de").headers["etag"] == fr


# --- Administration : onglets de langue -----------------------------------------------------

def test_admin_tabs_on_text_screens(admin):
    for url in ("/admin/textes", "/admin/tableaux/fiche", "/admin/tableaux/comparatif",
                "/admin/tableaux/bareme", "/admin/tableaux/installation",
                "/admin/listes/arguments", "/admin/listes/etapes", "/admin/faq",
                "/admin/captures", "/admin/confidentialite", "/admin/mentions-legales",
                "/admin/studio"):
        for lang in LANGS:
            page = admin.get(url + ("" if lang == "fr" else f"?lang={lang}")).text
            assert 'class="langtabs"' in page, url
            assert f'<input type="hidden" name="lang" value="{lang}">' in page, (url, lang)
            assert re.search(r'aria-current="page" lang="' + lang + '"', page), (url, lang)
    # L'administration reste en français.
    assert '<html lang="fr">' in admin.get("/admin/textes?lang=es").text


def test_admin_texts_translation_saved_without_touching_french(admin, settings):
    page = admin.get("/admin/textes?lang=en").text
    assert 'name="game_name"' not in page and 'name="play_store_url"' not in page
    assert 'name="tagline"' in page
    token = csrf_from(page)
    r = admin.post("/admin/textes", data={"csrf_token": token, "lang": "en",
                                          "tagline": "Tilt to play Pong.", "game_name": "Pirate"},
                   follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == "/admin/textes?lang=en"
    conn = conn_of(settings)
    site = db.get_settings(conn)
    conn.close()
    assert site["tagline"] == "Le Pong qu'on joue en inclinant son téléphone."
    assert site["game_name"] == "Tilto"  # non traduisible : ignoré
    assert "Tilt to play Pong." in visible(admin.get("/en/").text)
    # Vide = non traduit, le site affiche le français ; l'administration le signale.
    admin.post("/admin/textes", data={"csrf_token": token, "lang": "en", "tagline": ""})
    page = unescape(admin.get("/admin/textes?lang=en").text)
    assert "Non traduit" in page and "1 non traduit" in page
    assert "Le Pong qu'on joue en inclinant son téléphone." in visible(admin.get("/en/").text)


def test_admin_list_table_capture_translations(admin, settings):
    conn = conn_of(settings)
    feature = conn.execute("SELECT id FROM content_item WHERE kind = 'feature'"
                           " ORDER BY position LIMIT 1").fetchone()[0]
    spec = conn.execute("SELECT id FROM spec_row WHERE item_id = ? ORDER BY position LIMIT 1",
                        (feature,)).fetchone()[0]
    faq = conn.execute("SELECT id, anchor FROM faq ORDER BY position LIMIT 1").fetchone()
    row = conn.execute("SELECT id FROM spec_row WHERE grp = 'compare' ORDER BY position"
                       " LIMIT 1").fetchone()[0]
    shot = conn.execute("SELECT id FROM screenshot ORDER BY position LIMIT 1").fetchone()[0]
    before = conn.execute("SELECT title FROM content_item WHERE id = ?", (feature,)).fetchone()[0]
    conn.close()

    token = admin_csrf(admin, "/admin/listes/arguments?lang=es")
    page = admin.get("/admin/listes/arguments?lang=es").text
    assert "/deplacer" not in page and "/supprimer" not in page and "/ajouter" not in page
    admin.post(f"/admin/listes/arguments/{feature}/modifier",
               data={"csrf_token": token, "lang": "es", "title": "Título nuevo",
                     f"spec-{spec}-label": "Agarre firme", "action": "spec-delete:" + str(spec)})
    admin.post(f"/admin/faq/{faq['id']}/modifier",
               data={"csrf_token": token, "lang": "es", "question": "¿Pregunta?",
                     "anchor": "pirate"})
    admin.post("/admin/tableaux/comparatif",
               data={"csrf_token": token, "lang": "es", f"row-{row}-label": "Contrincante",
                     "action": "delete:" + str(row)})
    admin.post(f"/admin/captures/{shot}/modifier",
               data={"csrf_token": token, "lang": "es", "caption": "La portada"})
    es = visible(admin.get("/es/").text)
    for text in ("Título nuevo", "Agarre firme", "¿Pregunta?", "Contrincante", "La portada"):
        assert text in es, text
    conn = conn_of(settings)
    # Le français, l'ancre et la structure n'ont pas bougé (pas de suppression).
    assert conn.execute("SELECT title FROM content_item WHERE id = ?",
                        (feature,)).fetchone()[0] == before
    assert conn.execute("SELECT 1 FROM spec_row WHERE id = ?", (spec,)).fetchone()
    assert conn.execute("SELECT 1 FROM spec_row WHERE id = ?", (row,)).fetchone()
    assert conn.execute("SELECT anchor FROM faq WHERE id = ?",
                        (faq["id"],)).fetchone()[0] == faq["anchor"]
    conn.close()
    assert "Título nuevo" not in visible(admin.get("/").text)


def test_admin_privacy_legal_apk_translations(admin, settings):
    token = admin_csrf(admin, "/admin/confidentialite?lang=en")
    admin.post("/admin/confidentialite", data={"csrf_token": token, "lang": "en",
                                               "privacy_policy": "## Short\n\nNothing.",
                                               "privacy_updated": "2001-01-01"})
    admin.post("/admin/mentions-legales", data={"csrf_token": token, "lang": "en",
                                                "legal_extra": "## Credits\n\nFonts.",
                                                "legal_publisher": "Pirate"})
    en = unescape(admin.get("/en/privacy").text)
    assert "<h2>Short</h2>" in en and "October 12, 2026" in en  # date commune inchangée
    assert "<h2>Credits</h2>" in unescape(admin.get("/en/legal-notice").text)
    conn = conn_of(settings)
    site = db.get_settings(conn)
    conn.close()
    assert site["privacy_updated"] == "2026-10-12" and site["legal_publisher"] == ""
    assert "Pirate" not in admin.get("/mentions-legales").text

    token = admin_csrf(admin, "/admin/apk")
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "2.0.0",
                                           "make_current": "1", "release_notes": "Nouveau."},
               files={"apk": ("a.apk", make_apk(b"2"), "application/octet-stream")})
    conn = conn_of(settings)
    apk_id = conn.execute("SELECT id FROM apk_release").fetchone()[0]
    conn.close()
    page = unescape(admin.get("/admin/apk?lang=es").text)
    assert "Non traduit" in page and 'id="f-release_date"' not in page
    admin.post(f"/admin/apk/{apk_id}/notes", data={"csrf_token": token, "lang": "es",
                                                   "release_notes": "Nuevo.",
                                                   "release_date": "1999-01-01"})
    assert "Nuevo." in admin.get("/es/").text and "Nouveau." in admin.get("/").text


def test_deleting_text_deletes_its_translations(admin, settings):
    conn = conn_of(settings)
    feature = conn.execute("SELECT id FROM content_item WHERE kind = 'feature'"
                           " ORDER BY position LIMIT 1").fetchone()[0]
    assert conn.execute("SELECT COUNT(*) FROM translation WHERE tbl = 'content_item'"
                        " AND row_id = ?", (feature,)).fetchone()[0] > 0
    conn.close()
    token = admin_csrf(admin, "/admin/listes/arguments")
    admin.post(f"/admin/listes/arguments/{feature}/supprimer", data={"csrf_token": token})
    conn = conn_of(settings)
    assert conn.execute("SELECT COUNT(*) FROM translation WHERE tbl = 'content_item'"
                        " AND row_id = ?", (feature,)).fetchone()[0] == 0
    # Les caractéristiques supprimées en cascade emportent aussi leurs traductions.
    orphans = conn.execute("SELECT COUNT(*) FROM translation t WHERE t.tbl = 'spec_row' AND"
                           " NOT EXISTS (SELECT 1 FROM spec_row s WHERE s.id = t.row_id)")
    assert orphans.fetchone()[0] == 0
    conn.close()


def test_dashboard_shows_translation_state(admin, settings):
    assert "tout est traduit" in unescape(admin.get("/admin").text)
    conn = conn_of(settings)
    with conn:
        conn.execute("DELETE FROM translation WHERE lang = 'es' AND tbl = 'faq'")
    conn.close()
    assert "espagnol : " in unescape(admin.get("/admin").text)
    assert "textes affichés en français" in unescape(admin.get("/admin").text)


# --- Migration reseed_i18n --------------------------------------------------------------------

def snapshot(conn):
    """Tout le français de la base (réglages et tables de textes)."""
    return {
        "setting": conn.execute("SELECT key, value FROM setting WHERE key NOT LIKE '\\_%'"
                                " ESCAPE '\\' ORDER BY key").fetchall(),
        **{tbl: conn.execute(f"SELECT * FROM {tbl} ORDER BY id").fetchall()
           for tbl in ("content_item", "spec_row", "faq", "screenshot", "apk_release")},
    }


@pytest.fixture
def prod_db(tmp_path):
    """Base « en ligne » : française seulement, avec des textes modifiés par le
    propriétaire (relevés sur tilto.fun) et un texte réécrit sans traduction connue."""
    path = tmp_path / "data" / "tilto.sqlite3"
    db.init_db(path, tmp_path / "data" / "uploads" / "images")
    conn = db.connect(path)
    with conn:
        conn.execute("DELETE FROM translation")
        conn.execute("UPDATE setting SET value = ? WHERE key = 'hero_kicker'",
                     ("JEU DE PONG GRATUIT · ANDROID · SOLO ET DUEL LOCAL",))
        conn.execute("UPDATE setting SET value = ? WHERE key = 'footer_note'",
                     ("Le jeu ne collecte aucune donnée personnelle · tout reste sur ton téléphone",))
        conn.execute("UPDATE setting SET value = ? WHERE key = 'faq_subtitle'",
                     ("Un texte réécrit par le propriétaire.",))
        policy = conn.execute("SELECT value FROM setting WHERE key = 'privacy_policy'").fetchone()[0]
        policy = policy.replace(
            "Écris-nous avec le formulaire de la page Contact (lien en bas de chaque page).",
            "Écris-nous avec le lien Contact en bas de cette page.")
        conn.execute("UPDATE setting SET value = ? WHERE key = 'privacy_policy'", (policy,))
        # Une traduction déjà saisie dans l'administration : jamais remplacée.
        conn.execute("INSERT INTO translation (lang, tbl, row_id, field, value)"
                     " VALUES ('en', 'setting', 0, 'tagline', 'Owner wrote this.')")
    conn.close()
    return path


def test_reseed_i18n_simulation_changes_nothing(prod_db, capsys):
    conn = db.connect(prod_db)
    before = snapshot(conn), conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0]
    conn.close()
    assert reseed_i18n.main(["--db", str(prod_db)]) == 0
    out = capsys.readouterr().out
    assert "Aucune modification faite" in out
    assert "Un texte réécrit par le propriétaire." in out  # signalé, pas traduit
    conn = db.connect(prod_db)
    assert (snapshot(conn), conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0]) == before
    conn.close()


def test_reseed_i18n_apply_is_safe_and_idempotent(prod_db, capsys):
    conn = db.connect(prod_db)
    french = snapshot(conn)
    conn.close()
    assert reseed_i18n.main(["--db", str(prod_db), "--apply", "--yes"]) == 0
    conn = db.connect(prod_db)
    assert snapshot(conn) == french  # aucun texte français touché
    en = db.get_settings(conn, "en")
    es = db.get_settings(conn, "es")
    assert en["hero_kicker"] == "FREE PONG GAME · ANDROID · SOLO AND LOCAL DUEL"
    assert es["footer_note"].startswith("El juego no recopila")
    assert en["tagline"] == "Owner wrote this."  # traduction existante gardée
    assert en["faq_subtitle"] == "Un texte réécrit par le propriétaire."  # repli
    assert "Write to us using the Contact link at the bottom of this page." in en["privacy_policy"]
    assert "## What Tilto keeps on your phone" in en["privacy_policy"]
    count = conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0]
    conn.close()
    capsys.readouterr()
    # Deuxième passage : rien à ajouter.
    assert reseed_i18n.main(["--db", str(prod_db), "--apply", "--yes"]) == 0
    assert "Rien à ajouter" in capsys.readouterr().out
    conn = db.connect(prod_db)
    assert conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0] == count
    assert snapshot(conn) == french
    conn.close()


def test_reseed_i18n_asks_for_confirmation(prod_db, monkeypatch):
    monkeypatch.setattr("builtins.input", lambda prompt: "non")
    assert reseed_i18n.main(["--db", str(prod_db), "--apply"]) == 1
    conn = db.connect(prod_db)
    assert conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0] == 1
    conn.close()


def test_schema_migration_on_existing_v2_database(tmp_path):
    """Une base d'avant le multilingue (sans table translation ni colonne lang)
    démarre sans erreur et garde ses messages."""
    path = tmp_path / "data" / "tilto.sqlite3"
    db.init_db(path, tmp_path / "img")
    conn = sqlite3.connect(path)
    conn.execute("DROP TABLE translation")
    for trigger in ("content_item", "spec_row", "faq", "screenshot", "apk_release"):
        conn.execute(f"DROP TRIGGER translation_{trigger}")
    conn.execute("CREATE TABLE m AS SELECT id, created_at, name, email, subject, message, is_read"
                 " FROM contact_message")
    conn.execute("DROP TABLE contact_message")
    conn.execute("ALTER TABLE m RENAME TO contact_message")
    conn.execute("INSERT INTO contact_message (id, created_at, name, email, subject, message,"
                 " is_read) VALUES (1, '2026-10-10T10:00:00+00:00', '', 'a@b.fr', 'Question',"
                 " 'Salut', 0)")
    conn.commit()
    conn.close()
    shutil.copy(path, tmp_path / "copie.sqlite3")
    db.init_db(path, tmp_path / "img")
    conn = db.connect(path)
    assert conn.execute("SELECT lang FROM contact_message").fetchone()[0] == "fr"
    assert conn.execute("SELECT COUNT(*) FROM translation").fetchone()[0] == 0  # base existante
    conn.close()


def test_content_translations_cover_defaults():
    """Chaque texte français du contenu initial a sa traduction."""
    texts = [v for k, v in db.DEFAULT_SETTINGS.items()
             if k in db.TRANSLATABLE_SETTINGS and v.strip()]
    for f in db.V2_FEATURES:
        texts += [f["kicker"], f["title"], f["body"], f["short_body"]]
        texts += [x for pair in f["specs"] for x in pair]
    texts += [x for pair in db.V2_STEPS + db.V2_SCREENSHOTS + db.V2_INSTALL for x in pair]
    texts += [x for row in db.V2_HERO_SPECS + db.V2_COMPARE + db.V2_SCORING for x in row]
    texts += [x for f in db.V2_FAQ for x in (f["question"], f["answer"], f["short_answer"]) if x]
    texts.append(db.V2_RELEASE_NOTES_1_0_0)
    for text in texts:
        for lang in ("en", "es"):
            assert content_i18n.translate(text, lang), (lang, text[:60])
