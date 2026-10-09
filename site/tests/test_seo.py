"""Référencement : robots.txt, sitemap.xml, security.txt, URL canonique,
titres et descriptions, Open Graph, JSON-LD, noindex, polices WOFF2, statiques versionnés."""

import json
import re
import xml.etree.ElementTree as ET
from dataclasses import replace
from html import unescape

from fastapi.testclient import TestClient

from app.config import ConfigError, Settings
from app.main import create_app
from app.seo import HOME_DESCRIPTION

from conftest import admin_csrf, make_apk

SITEMAP_NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"


def meta(html: str, attr: str, name: str) -> str | None:
    match = re.search(rf'<meta {attr}="{re.escape(name)}" content="([^"]*)"', html)
    return unescape(match.group(1)) if match else None


def canonical(html: str) -> str | None:
    match = re.search(r'<link rel="canonical" href="([^"]*)"', html)
    return match.group(1) if match else None


def json_ld(html: str) -> dict:
    match = re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
    assert match, "JSON-LD absent"
    return json.loads(match.group(1))


def graph_node(data: dict, kind: str) -> dict | None:
    return next((n for n in data["@graph"] if n["@type"] == kind), None)


def publish_apk(admin, version="1.4.0"):
    token = admin_csrf(admin, "/admin/apk")
    r = admin.post("/admin/apk/deposer",
                   data={"csrf_token": token, "version": version, "make_current": "1"},
                   files={"apk": ("t.apk", make_apk(version.encode()), "application/octet-stream")})
    assert r.status_code == 200


# --- SITE_URL -----------------------------------------------------------------

def test_site_url_setting(settings):
    env = {"SECRET_KEY": "x" * 40, "ADMIN_PASSWORD_HASH": settings.admin_password_hash}
    assert Settings.from_env(env).site_url == "https://tilto.fun"
    assert Settings.from_env({**env, "SITE_URL": "https://exemple.org/"}).site_url == "https://exemple.org"
    for bad in ("tilto.fun", "https://tilto.fun/chemin", "javascript:alert(1)"):
        try:
            Settings.from_env({**env, "SITE_URL": bad})
        except ConfigError:
            continue
        raise AssertionError(f"SITE_URL accepté : {bad}")


# --- robots.txt -----------------------------------------------------------------

def test_robots_txt(client):
    r = client.get("/robots.txt")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/plain")
    text = r.text
    # Groupe général : tout est permis sauf trois chemins.
    general = text.split("User-agent: *\n", 1)[1].split("\n\n", 1)[0]
    assert general.splitlines() == ["Allow: /", "Disallow: /telecharger",
                                    "Disallow: /contact/merci", "Disallow: /sante"]
    # Robots d'entraînement : un seul groupe, User-agent consécutifs, tout refusé.
    group = re.search(r"((?:User-agent: [^*\n]+\n)+)Disallow: /\n", text)
    assert group
    agents = re.findall(r"User-agent: (.+)", group.group(1))
    assert agents == ["GPTBot", "ClaudeBot", "Google-Extended", "Applebot-Extended",
                      "CCBot", "meta-externalagent", "Bytespider"]
    # Robots de recherche des assistants : pas de règle propre.
    for bot in ("OAI-SearchBot", "ChatGPT-User", "PerplexityBot", "Claude-SearchBot"):
        assert f"User-agent: {bot}" not in text
    assert "/admin" not in text
    assert text.rstrip().endswith("Sitemap: https://tilto.fun/sitemap.xml")


# --- sitemap.xml ----------------------------------------------------------------

def test_sitemap_xml_absolute_urls_on_fixed_base(client):
    r = client.get("/sitemap.xml", headers={"Host": "pirate.example"})
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/xml")
    root = ET.fromstring(r.content)
    urls = {u.find(f"{SITEMAP_NS}loc").text: u.find(f"{SITEMAP_NS}lastmod")
            for u in root.findall(f"{SITEMAP_NS}url")}
    assert list(urls) == ["https://tilto.fun/", "https://tilto.fun/contact",
                          "https://tilto.fun/confidentialite", "https://tilto.fun/mentions-legales"]
    assert "pirate.example" not in r.text
    # Pas d'APK : pas de date pour l'accueil ; confidentialité datée ; mentions vides.
    assert urls["https://tilto.fun/"] is None
    assert urls["https://tilto.fun/confidentialite"].text == "2026-10-09"
    assert urls["https://tilto.fun/mentions-legales"] is None
    assert "priority" not in r.text and "changefreq" not in r.text


def test_sitemap_home_lastmod_from_current_apk(admin):
    publish_apk(admin)
    root = ET.fromstring(admin.get("/sitemap.xml").content)
    home = root.find(f"{SITEMAP_NS}url")
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}", home.find(f"{SITEMAP_NS}lastmod").text)


def test_sitemap_follows_site_url(settings):
    with TestClient(create_app(replace(settings, site_url="https://exemple.org"))) as c:
        assert "<loc>https://exemple.org/contact</loc>" in c.get("/sitemap.xml").text
        assert "Sitemap: https://exemple.org/sitemap.xml" in c.get("/robots.txt").text
        assert canonical(c.get("/").text) == "https://exemple.org/"


# --- security.txt ---------------------------------------------------------------

def test_security_txt(client):
    r = client.get("/.well-known/security.txt")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/plain")
    assert r.text.splitlines() == [
        "Contact: https://tilto.fun/contact",
        "Expires: 2027-10-01T00:00:00.000Z",
        "Preferred-Languages: fr, en",
        "Canonical: https://tilto.fun/.well-known/security.txt",
    ]


# --- Canonique, titres, descriptions, Open Graph ------------------------------------

def test_canonical_fixed_base_without_query(client):
    pages = {"/": "https://tilto.fun/", "/contact": "https://tilto.fun/contact",
             "/confidentialite": "https://tilto.fun/confidentialite",
             "/mentions-legales": "https://tilto.fun/mentions-legales"}
    for path, expected in pages.items():
        html = client.get(path + "?utm_source=x", headers={"Host": "pirate.example"}).text
        assert canonical(html) == expected, path
        assert meta(html, "property", "og:url") == expected
        assert "noindex" not in html


def test_home_title_and_description(client):
    html = client.get("/").text
    title = unescape(re.search(r"<title>(.*?)</title>", html).group(1))
    assert title == "Tilto : le Pong qu'on joue en inclinant son téléphone (Android)"
    assert meta(html, "name", "description") == HOME_DESCRIPTION
    assert HOME_DESCRIPTION == (
        "Jeu de Pong gratuit pour Android : penche ton téléphone pour bouger la raquette. "
        "Seul contre l'ordinateur ou à deux sur le même Wi-Fi, sans Internet ni pub.")


def test_page_descriptions(client):
    for path in ("/contact", "/confidentialite", "/mentions-legales"):
        description = meta(client.get(path).text, "name", "description")
        assert description and 110 <= len(description) <= 160, (path, description)


def test_open_graph_and_twitter(client):
    html = client.get("/").text
    assert meta(html, "property", "og:type") == "website"
    assert meta(html, "property", "og:site_name") == "Tilto"
    assert meta(html, "property", "og:locale") == "fr_FR"
    assert meta(html, "property", "og:title").startswith("Tilto : le Pong")
    assert meta(html, "property", "og:description") == HOME_DESCRIPTION
    image = meta(html, "property", "og:image")
    assert image.startswith("https://tilto.fun/static/img/og-tilto.png")
    assert meta(html, "property", "og:image:width") == "1200"
    assert meta(html, "property", "og:image:height") == "630"
    assert meta(html, "property", "og:image:alt")
    assert meta(html, "name", "twitter:card") == "summary_large_image"
    # L'image existe, au bon format, et reste légère.
    r = client.get(image.removeprefix("https://tilto.fun"))
    assert r.status_code == 200 and r.headers["content-type"] == "image/png"
    assert r.content[16:24] == (1200).to_bytes(4, "big") + (630).to_bytes(4, "big")
    assert len(r.content) < 300 * 1024


def test_noindex_on_thanks_and_error_pages(client):
    thanks = client.get("/contact/merci").text
    assert '<meta name="robots" content="noindex">' in thanks
    assert canonical(thanks) is None and "og:" not in thanks
    missing = client.get("/page-inexistante")
    assert missing.status_code == 404
    assert '<meta name="robots" content="noindex">' in missing.text
    assert canonical(missing.text) is None
    assert meta(missing.text, "name", "description") is None


def test_admin_has_no_canonical(admin):
    html = admin.get("/admin").text
    assert canonical(html) is None and "og:" not in html
    assert '<meta name="robots" content="noindex">' in html


# --- JSON-LD ------------------------------------------------------------------------

def test_json_ld_without_apk(client):
    data = json_ld(client.get("/").text)
    assert data["@context"] == "https://schema.org"
    assert graph_node(data, "WebSite")["url"] == "https://tilto.fun/"
    org = graph_node(data, "Organization")
    assert org["name"] == "Nexora"
    assert org["logo"].startswith("https://tilto.fun/media/")
    app = graph_node(data, "MobileApplication")
    assert app["name"] == "Tilto"
    assert app["operatingSystem"] == "Android 5.0 ou plus"
    assert app["applicationCategory"] == "GameApplication"
    assert app["isAccessibleForFree"] is True
    assert app["offers"] == {"@type": "Offer", "price": "0", "priceCurrency": "EUR"}
    assert "softwareVersion" not in app and "downloadUrl" not in app
    # Les captures du contenu initial n'ont pas d'image.
    assert "screenshot" not in app
    text = json.dumps(data)
    assert "aggregateRating" not in text and "review" not in text.lower()


def test_json_ld_with_apk_and_faq(admin):
    publish_apk(admin, "1.4.0")
    data = json_ld(admin.get("/").text)
    app = graph_node(data, "MobileApplication")
    assert app["softwareVersion"] == "1.4.0"
    assert app["downloadUrl"] == "https://tilto.fun/telecharger"
    faq = graph_node(data, "FAQPage")
    assert faq and faq["mainEntity"]
    first = faq["mainEntity"][0]
    assert first["@type"] == "Question" and first["acceptedAnswer"]["text"]


def test_json_ld_cannot_close_script(admin):
    """Un texte de la base contenant </script> reste dans le bloc de données."""
    token = admin_csrf(admin, "/admin/faq")
    r = admin.post("/admin/faq/ajouter", data={"csrf_token": token, "question": "Test </script><b>",
                                               "answer": "Réponse </script>", "anchor": "test-ld"})
    assert r.status_code in (200, 303)
    html = admin.get("/").text
    assert "Test &lt;/script&gt;" in html  # la question a bien été ajoutée
    block = re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.S).group(1)
    assert "</" not in block
    json.loads(block)


# --- Polices, logo, statiques ---------------------------------------------------------

def test_woff2_fonts_served_and_referenced(client):
    for css in ("site.css", "admin.css"):
        text = client.get(f"/static/css/{css}").text
        assert ".ttf" not in text
        assert text.count('format("woff2")') == 6
    r = client.get("/static/fonts/Archivo-Black.woff2")
    assert r.status_code == 200
    assert r.headers["content-type"] == "font/woff2"
    assert r.content[:4] == b"wOF2"
    assert client.get("/static/fonts/Archivo-Black.ttf").status_code == 404
    html = client.get("/").text
    preloads = re.findall(r'<link rel="preload" href="([^"]+)" as="font"', html)
    assert preloads == ["/static/fonts/Archivo-Black.woff2"]


def test_footer_logo_has_dimensions(client):
    img = re.search(r'<img [^>]*class="studio-logo"[^>]*>', client.get("/").text).group(0)
    width = int(re.search(r'width="(\d+)"', img).group(1))
    height = int(re.search(r'height="(\d+)"', img).group(1))
    assert height == 24
    # Logo initial réduit : 221 × 48, soit 111 × 24 affiché.
    assert 100 <= width <= 120


def test_static_urls_are_versioned(client):
    html = client.get("/").text
    for path in ("css/site.css", "js/nav.js", "js/theme.js", "js/site.js"):
        match = re.search(rf'/static/{re.escape(path)}\?v=([0-9a-f]{{10}})"', html)
        assert match, path
        assert client.get(f"/static/{path}?v={match.group(1)}").status_code == 200
