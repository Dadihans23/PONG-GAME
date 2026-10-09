from html import unescape

from app.config import ConfigError, Settings
from app.render import rich_text
from app.security import hash_password, verify_password


def test_home_shows_initial_content(client):
    r = client.get("/")
    assert r.status_code == 200
    page = unescape(r.text)
    # Contenu initial aligné sur la maquette (planche 3a).
    assert "<h1>TILTO</h1>" in page
    assert "Le Pong qu'on joue en inclinant son téléphone." in page
    assert "Gratuit · Android" in page
    for nav in ('href="/#le-jeu"', 'href="/#comment-jouer"', 'href="/#captures"',
                'href="/#telecharger"'):
        assert nav in page
    for kicker in ("INCLINE", "À DEUX", "SENSIBILITÉ", "RECORDS"):
        assert f'<p class="kicker">{kicker}</p>' in page
    assert "Pas de bouton. Tu penches, la raquette suit." in page
    assert "Prends ton téléphone à deux mains." in page
    for caption in ("L'accueil", "En solo", "En duel", "Fin du duel"):
        assert f"<figcaption>{caption}</figcaption>" in page
    assert "Télécharge Tilto" in page
    assert "L'APK sert si tu n'as pas le Play Store" in page
    assert "Un jeu de Nexora · ©" in page
    assert 'alt="Nexora" class="studio-logo"' in page  # logo initial copié dans les données
    assert "/confidentialite" in page
    assert "set-cookie" not in r.headers  # aucun cookie sur les pages publiques


def test_security_headers(client):
    r = client.get("/")
    assert r.headers["x-content-type-options"] == "nosniff"
    assert r.headers["x-frame-options"] == "DENY"
    assert "frame-ancestors 'none'" in r.headers["content-security-policy"]


def test_privacy_page(client):
    r = client.get("/confidentialite")
    assert r.status_code == 200
    page = unescape(r.text)
    assert "Dernière mise à jour : 9 octobre 2026" in page
    assert "Tilto ne collecte aucune donnée personnelle." in page
    for section in ("Ce que Tilto garde sur ton téléphone", "Pendant un duel",
                    "Ce que Tilto n'utilise pas", "Autorisations demandées",
                    "Effacer tes données", "Une question ?"):
        assert f"<h2>{section}</h2>" in page
    # Chaque intertitre ouvre une section (mise en page en colonnes) ; l'introduction
    # reste hors des sections.
    assert page.count('<section class="policy__section">') == 8
    assert '<div class="page__intro"><p>Tilto ne collecte' in page


def test_seed_logo_served(client):
    import re
    src = re.search(r'src="(/media/[a-f0-9]{32}\.png)" alt="Nexora"', client.get("/").text).group(1)
    r = client.get(src)
    assert r.status_code == 200 and r.content.startswith(b"\x89PNG")


def test_existing_db_is_migrated(tmp_path, settings):
    import sqlite3

    from app import db
    path = tmp_path / "old.sqlite3"
    conn = sqlite3.connect(path)
    conn.executescript("""
        CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        INSERT INTO setting VALUES ('game_name', 'Ancien nom');
        CREATE TABLE content_item (id INTEGER PRIMARY KEY, kind TEXT NOT NULL,
            position INTEGER NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '');
    """)
    conn.close()
    db.init_db(path, tmp_path / "img")
    conn = db.connect(path)
    cols = {r["name"] for r in conn.execute("PRAGMA table_info(content_item)")}
    values = db.get_settings(conn)
    conn.close()
    assert "kicker" in cols
    assert values["game_name"] == "Ancien nom"  # valeur existante conservée
    assert values["hero_note"] == "Gratuit · Android"  # nouveau réglage ajouté


def test_health(client):
    r = client.get("/sante")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_download_without_apk_is_404(client):
    r = client.get("/telecharger")
    assert r.status_code == 404
    assert "Aucune version" in unescape(r.text)


def test_unknown_page_is_french_404(client):
    r = client.get("/nexiste-pas")
    assert r.status_code == 404
    assert "Cette page n'existe pas" in unescape(r.text)


def test_media_rejects_bad_names(client):
    assert client.get("/media/..%2Ftilto.sqlite3").status_code == 404
    assert client.get("/media/abc.png").status_code == 404


def test_docs_are_disabled(client):
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_rich_text_escapes_html():
    html = str(rich_text("## Titre\n\n<script>alert(1)</script>\n\n- a\n- b"))
    assert "<h2>Titre</h2>" in html
    assert "<script>" not in html and "&lt;script&gt;" in html
    assert "<ul><li>a</li><li>b</li></ul>" in html


def test_password_hash_roundtrip():
    encoded = hash_password("secret-tres-long", log_n=10)
    assert "$" not in encoded
    assert verify_password("secret-tres-long", encoded)
    assert not verify_password("autre", encoded)
    assert not verify_password("x", "n'importe quoi")


def test_settings_require_secrets(tmp_path):
    import pytest
    with pytest.raises(ConfigError):
        Settings.from_env({"DATA_DIR": str(tmp_path)})
    with pytest.raises(ConfigError):
        Settings.from_env({"SECRET_KEY": "x" * 40, "DATA_DIR": str(tmp_path)})
    s = Settings.from_env({"SECRET_KEY": "x" * 40, "ADMIN_PASSWORD_HASH": hash_password("a", log_n=10),
                           "DATA_DIR": str(tmp_path), "MAX_APK_MB": "300"})
    assert s.max_apk_mb == 300 and not s.cookie_secure
