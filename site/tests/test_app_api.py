"""API de l'app (GET /api/app/studio), présentation du studio dans
l'administration et mise à jour de la politique de confidentialité
(python -m app.reseed_studio)."""

import hashlib
import json
import re
import struct
import zlib
from dataclasses import replace
from html import unescape

from fastapi.testclient import TestClient

from app import db, reseed_studio
from app.main import create_app
from conftest import admin_csrf

API = "/api/app/studio"


def make_png(width: int, height: int) -> bytes:
    """PNG RGBA valide de la taille demandée."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    raw = b"".join(b"\x00" + b"\xff\xff\xff\xff" * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def post_studio(admin, files=None, **fields):
    token = admin_csrf(admin, "/admin/studio")
    data = {"csrf_token": token, "studio_name": "Nexora", **fields}
    return admin.post("/admin/studio", data=data, files=files)


# --- API ------------------------------------------------------------------------

def test_contract_shape(client, settings):
    r = client.get(API)
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/json; charset=utf-8"
    body = r.json()
    assert list(body) == ["schema", "studio", "logo", "updated_at"]
    assert body["schema"] == 1
    assert body["studio"] == {"name": "Nexora", "about": "",
                              "website": "https://tilto.fun",
                              "contact_url": "https://tilto.fun/contact"}
    # Base neuve : logo initial du studio (PNG 221 × 48), copié dans les données.
    logo = body["logo"]
    assert list(logo) == ["url", "sha256", "width", "height", "content_type"]
    name = logo["url"].removeprefix("https://tilto.fun/media/")
    assert re.fullmatch(r"[a-f0-9]{32}\.png", name)
    assert (logo["width"], logo["height"], logo["content_type"]) == (221, 48, "image/png")
    data = (settings.images_dir / name).read_bytes()
    assert logo["sha256"] == hashlib.sha256(data).hexdigest()
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00", body["updated_at"])
    # Le logo annoncé est bien servi.
    assert client.get(f"/media/{name}").content == data


def test_headers_cache_etag_no_cookie(client):
    r = client.get(API)
    assert r.headers["cache-control"] == "public, max-age=3600"
    assert r.headers["x-robots-tag"] == "noindex"
    assert "set-cookie" not in r.headers
    assert "access-control-allow-origin" not in r.headers
    etag = r.headers["etag"]
    assert etag == '"' + hashlib.sha256(r.content).hexdigest()[:32] + '"'
    again = client.get(API, headers={"If-None-Match": etag})
    assert again.status_code == 304 and again.content == b""
    assert again.headers["etag"] == etag
    assert again.headers["cache-control"] == "public, max-age=3600"
    assert client.get(API, headers={"If-None-Match": f'"autre", W/{etag}'}).status_code == 304
    assert client.get(API, headers={"If-None-Match": '"autre"'}).status_code == 200
    # Lecture seule : réponse identique d'un appel à l'autre (pas d'horodatage « maintenant »).
    assert client.get(API).content == r.content
    assert client.head(API).status_code == 200


def test_absolute_urls_ignore_host_header(client):
    body = client.get(API, headers={"Host": "pirate.example"}).json()
    assert body["studio"]["website"] == "https://tilto.fun"
    assert body["logo"]["url"].startswith("https://tilto.fun/media/")
    assert "pirate" not in json.dumps(body)


def test_urls_follow_site_url(settings):
    with TestClient(create_app(replace(settings, site_url="https://exemple.org"))) as c:
        body = c.get(API).json()
    assert body["studio"]["website"] == "https://exemple.org"
    assert body["studio"]["contact_url"] == "https://exemple.org/contact"
    assert body["logo"]["url"].startswith("https://exemple.org/media/")


def test_logo_null_without_logo(admin):
    post_studio(admin, remove_logo="1")
    assert admin.get(API).json()["logo"] is None


def test_logo_null_with_svg(admin):
    svg = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>'
    post_studio(admin, files={"logo": ("logo.svg", svg, "image/svg+xml")})
    assert admin.get(API).json()["logo"] is None
    page = unescape(admin.get("/admin/studio").text)
    assert "ce logo est en SVG" in page
    assert "pas affiché dans l'app" in unescape(admin.get("/admin").text)


def test_logo_png_uploaded(admin, settings):
    png = make_png(120, 30)
    post_studio(admin, files={"logo": ("logo.png", png, "image/png")})
    logo = admin.get(API).json()["logo"]
    assert (logo["width"], logo["height"]) == (120, 30)
    assert logo["content_type"] == "image/png"
    assert logo["sha256"] == hashlib.sha256(png).hexdigest()
    name = logo["url"].rsplit("/", 1)[1]
    assert (settings.images_dir / name).read_bytes() == png


def test_about_and_name_reflected_and_updated_at_follows_save(admin):
    before = admin.get(API)
    post_studio(admin, studio_name="Nexora Games",
                studio_about="Premier paragraphe.\r\n\r\nSecond paragraphe.")
    r = admin.get(API)
    body = r.json()
    assert body["studio"]["name"] == "Nexora Games"
    assert body["studio"]["about"] == "Premier paragraphe.\n\nSecond paragraphe."
    with _conn(admin) as conn:
        assert body["updated_at"] == db.get_internal(conn, "_saved:studio")
    # Contenu changé : nouvel ETag, l'ancien ne donne plus 304.
    assert r.headers["etag"] != before.headers["etag"]
    assert admin.get(API, headers={"If-None-Match": before.headers["etag"]}).status_code == 200


class _conn:
    """Connexion directe à la base de l'application du client de test."""
    def __init__(self, client):
        self.path = client.app.state.settings.db_path

    def __enter__(self):
        self.conn = db.connect(self.path)
        return self.conn

    def __exit__(self, *exc):
        self.conn.close()


def test_api_not_in_sitemap_and_disallowed(client):
    assert "/api/" not in client.get("/sitemap.xml").text
    assert "Disallow: /api/" in client.get("/robots.txt").text.splitlines()


# --- Administration ------------------------------------------------------------

def test_admin_about_saved_escaped_and_limited(admin):
    page = unescape(admin.get("/admin/studio").text)
    assert "Présentation du studio" in page
    assert "Laisse vide pour ne montrer que le nom et le logo." in page
    assert "pas en SVG ni en GIF" in page and "au plus tard le lendemain" in page
    post_studio(admin, studio_about='<script>alert("x")</script> Studio & co')
    html = admin.get("/admin/studio").text
    assert "<script>alert" not in html
    assert "&lt;script&gt;alert(&#34;x&#34;)&lt;/script&gt; Studio &amp; co" in html
    assert admin.get(API).json()["studio"]["about"] == '<script>alert("x")</script> Studio & co'
    # 800 caractères au plus : le reste est coupé.
    post_studio(admin, studio_about="a" * 900)
    assert admin.get(API).json()["studio"]["about"] == "a" * 800
    assert 'maxlength="800"' in admin.get("/admin/studio").text


def test_admin_about_kept_when_field_absent_and_on_error(admin):
    post_studio(admin, studio_about="Texte gardé.")
    post_studio(admin)  # formulaire sans le champ : la présentation ne change pas
    assert admin.get(API).json()["studio"]["about"] == "Texte gardé."
    r = post_studio(admin, studio_name="", studio_about="Brouillon")
    assert r.status_code == 400
    assert "Brouillon" in r.text  # saisie réaffichée
    assert admin.get(API).json()["studio"]["about"] == "Texte gardé."


# --- Politique de confidentialité ----------------------------------------------

def old_default_policy() -> str:
    """Politique par défaut d'avant l'appel de l'app au site."""
    text = db.PRIVACY_DEFAULT.replace(db.PRIVACY_STUDIO_SECTION + "\n", "")
    text = text.replace(db.PRIVACY_PERMISSIONS_NEW, db.PRIVACY_PERMISSIONS_OLD)
    assert "Nom et logo du studio" not in text
    return text


def test_default_policy_mentions_studio_request():
    text = db.PRIVACY_DEFAULT
    pos = text.index
    assert pos("## Pendant un duel") < pos("## Nom et logo du studio") \
        < pos("## Ce que Tilto n'utilise pas")
    assert "aucune donnée personnelle et rien sur ta façon de jouer" in text
    assert db.PRIVACY_PERMISSIONS_OLD not in text


def test_reseed_policy_from_old_default_gives_new_default():
    new, changes = reseed_studio.updated_policy(old_default_policy())
    assert new == db.PRIVACY_DEFAULT
    assert len(changes) == 2
    assert reseed_studio.updated_policy(new) == (new, [])  # idempotent


def test_reseed_policy_insertion_points():
    section = db.PRIVACY_STUDIO_SECTION.strip()
    new, _ = reseed_studio.updated_policy("Intro.\n\n## Ce site\n\nJournaux.\n")
    assert new == f"Intro.\n\n{section}\n\n## Ce site\n\nJournaux.\n"
    new, _ = reseed_studio.updated_policy("Intro.\n\n## Effacer\n\nDésinstalle.\n")
    assert new == f"Intro.\n\n## Effacer\n\nDésinstalle.\n\n{section}\n"


def test_reseed_keeps_text_modified_otherwise():
    custom = old_default_policy().replace(
        db.PRIVACY_PERMISSIONS_OLD, "Le réseau, pour le duel (texte du propriétaire).")
    new, changes = reseed_studio.updated_policy(custom)
    assert "Le réseau, pour le duel (texte du propriétaire)." in new
    assert db.PRIVACY_PERMISSIONS_NEW not in new
    assert len(changes) == 1  # seulement la section ajoutée
    assert new.replace(db.PRIVACY_STUDIO_SECTION.strip() + "\n\n", "") == custom


def test_reseed_command(tmp_path, capsys, monkeypatch):
    path = tmp_path / "prod.sqlite3"
    db.init_db(path, tmp_path / "img")
    conn = db.connect(path)
    db.set_settings(conn, {"privacy_policy": old_default_policy(),
                           "privacy_updated": "2026-10-09"})
    conn.close()

    assert reseed_studio.main(["--db", str(path)]) == 0  # simulation
    out = capsys.readouterr().out
    assert "Aucune modification faite" in out and "Nom et logo du studio" in out
    conn = db.connect(path)
    assert db.get_settings(conn)["privacy_updated"] == "2026-10-09"
    conn.close()

    monkeypatch.setattr("builtins.input", lambda prompt: "non")
    assert reseed_studio.main(["--db", str(path), "--apply"]) == 1
    monkeypatch.setattr("builtins.input", lambda prompt: "oui")
    assert reseed_studio.main(["--db", str(path), "--apply"]) == 0
    conn = db.connect(path)
    site = db.get_settings(conn)
    conn.close()
    assert site["privacy_policy"] == db.PRIVACY_DEFAULT
    from datetime import date
    assert site["privacy_updated"] == date.today().isoformat()

    capsys.readouterr()
    assert reseed_studio.main(["--db", str(path), "--apply", "--yes"]) == 0
    assert "Rien à changer" in capsys.readouterr().out
