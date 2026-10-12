"""Accueil « Néon magenta » : nouveaux réglages, bouton Google Play en attente,
scène Face-à-face, bulle de l'accueil, aucune ressource externe."""

import re
import sqlite3
from html import unescape

from conftest import admin_csrf, make_apk, visible

from app import db

NEW_SETTINGS = {
    "hero_badge": "1 vs 1",
    "play_soon_text": "Bientôt disponible",
    "duel_kicker": "FACE-À-FACE · DUEL · PREMIER À 5",
    "duel_title": "Chacun son téléphone,",
    "duel_title_accent": "chacun sa raquette en bas.",
    "duel_left_label": "TÉLÉPHONE DE LÉA",
    "duel_left_name": "Léa",
    "duel_left_score": "2",
    "duel_left_text": "Léa se voit en bas, en bleu. Tom est en haut, en vert.",
    "duel_right_label": "TÉLÉPHONE DE TOM",
    "duel_right_name": "Tom",
    "duel_right_score": "3",
    "duel_right_text": "Sur son écran, c'est Tom qui est en bas, en bleu. Le premier à 5 gagne.",
    "duel_chip_1": "Même Wi-Fi ou partage de connexion",
    "duel_chip_2": "Les deux « Prêt », puis 3-2-1",
    "duel_chip_3": "Revanche en un bouton",
}


def soon_button(page: str) -> bool:
    return bool(re.search(r'<a class="btn btn--soon" role="link" aria-disabled="true">', page))


def test_new_settings_have_defaults(client, settings):
    for key, value in NEW_SETTINGS.items():
        assert db.DEFAULT_SETTINGS[key] == value, key
    conn = db.connect(settings.db_path)
    try:
        stored = db.get_settings(conn)
    finally:
        conn.close()
    for key, value in NEW_SETTINGS.items():
        assert stored[key] == value, key


def test_new_settings_added_to_existing_db(tmp_path, settings):
    # Une base d'avant la maquette Néon reçoit les nouveaux réglages, sans perdre les autres.
    db.init_db(settings.db_path, settings.images_dir)
    conn = sqlite3.connect(settings.db_path)
    with conn:
        conn.execute("DELETE FROM setting WHERE key LIKE 'duel_%' OR key IN ('hero_badge', 'play_soon_text')")
        conn.execute("UPDATE setting SET value = 'Mon accroche' WHERE key = 'tagline'")
    conn.close()
    db.init_db(settings.db_path, settings.images_dir)
    conn = db.connect(settings.db_path)
    try:
        stored = db.get_settings(conn)
    finally:
        conn.close()
    assert stored["tagline"] == "Mon accroche"
    assert stored["duel_title"] == "Chacun son téléphone,"
    assert stored["hero_badge"] == "1 vs 1"


def test_home_shows_neon_defaults(client):
    page = visible(client.get("/").text)
    assert '<span class="hero__badge">1 vs 1</span>' in page
    assert 'id="solo-duel" aria-labelledby="titre-duel"' in page
    assert "FACE-À-FACE · DUEL · PREMIER À 5" in page
    assert '<span class="duel__accent">chacun sa raquette en bas.</span>' in page
    for key in ("duel_left_label", "duel_left_text", "duel_right_label", "duel_right_text"):
        assert NEW_SETTINGS[key] in page
    assert '<p class="duel__score">2</p>' in page and '<p class="duel__score">3</p>' in page
    for chip in ("duel_chip_1", "duel_chip_2", "duel_chip_3"):
        assert f"<li>{NEW_SETTINGS[chip]}</li>" in page
    # Le tableau Solo ou Duel est dans la même section.
    section = page[page.index('id="solo-duel"'):page.index('id="comment-jouer"')]
    assert '<table class="compare__table"' in section


def test_duel_phones_follow_blue_is_me(client):
    # Chaque téléphone dessiné montre son propriétaire en bas (bleu), l'autre en haut (vert).
    page = unescape(client.get("/").text)
    phones = re.findall(
        r'scr__duel--them"><span class="scr__who">(\w+)<.*?<b>(\d)</b>.*?'
        r'scr__duel--me"><b>(\d)</b><span class="scr__who">(\w+)<', page, re.S)
    # 02 (deux téléphones) puis Face-à-face (deux téléphones).
    assert phones == [("TOM", "3", "2", "LÉA"), ("LÉA", "2", "3", "TOM")] * 2


def test_duel_scene_editable_in_admin(admin):
    page = admin.get("/admin/tableaux/comparatif").text
    for key in NEW_SETTINGS:
        if key.startswith("duel_"):
            assert f'name="{key}"' in page, key
    token = admin_csrf(admin, "/admin/tableaux/comparatif")
    r = admin.post("/admin/tableaux/comparatif", data={
        "csrf_token": token, "duel_title": "Deux téléphones,", "duel_left_name": "Zoé",
        "duel_left_label": "TÉLÉPHONE DE ZOÉ", "duel_left_score": "4", "duel_chip_2": "",
        "duel_right_text": "Texte <b>libre</b>"}, follow_redirects=False)
    assert r.status_code == 303
    home = admin.get("/").text
    assert "Deux téléphones," in home and "TÉLÉPHONE DE ZOÉ" in unescape(home)
    assert '<p class="duel__score">4</p>' in home
    assert "Texte &lt;b&gt;libre&lt;/b&gt;" in home  # échappé
    assert "<li>Les deux « Prêt », puis 3-2-1</li>" not in unescape(home)  # pastille vide masquée
    assert unescape(home).count('<span class="scr__who">ZOÉ') == 4


def test_duel_score_validation(admin):
    token = admin_csrf(admin, "/admin/tableaux/comparatif")
    r = admin.post("/admin/tableaux/comparatif", data={
        "csrf_token": token, "duel_left_score": "7"})
    assert r.status_code == 400
    assert "Un chiffre de 0 à 5" in unescape(r.text)


def test_duel_scene_hidden_without_title(admin):
    token = admin_csrf(admin, "/admin/tableaux/comparatif")
    admin.post("/admin/tableaux/comparatif", data={
        "csrf_token": token, "duel_title": "", "duel_title_accent": ""})
    home = admin.get("/").text
    assert "duel__scene" not in home
    assert 'id="solo-duel" aria-labelledby="titre-solo-duel"' in home  # le tableau reste


def test_badge_and_soon_text_editable(admin):
    assert 'name="hero_badge"' in admin.get("/admin/tableaux/fiche").text
    assert 'name="play_soon_text"' in admin.get("/admin/textes").text
    token = admin_csrf(admin, "/admin/textes")
    admin.post("/admin/textes", data={"csrf_token": token, "play_soon_text": "En route"})
    token = admin_csrf(admin, "/admin/tableaux/fiche")
    admin.post("/admin/tableaux/fiche", data={"csrf_token": token, "hero_badge": ""})
    home = unescape(admin.get("/").text)
    assert "En route" in home
    assert "hero__badge" not in home


def test_soon_button_only_without_play_store_url(admin):
    home = admin.get("/").text
    assert soon_button(home)
    assert home.count("btn--soon") == 2  # héros et bloc final
    assert "href" not in re.search(r'<a class="btn btn--soon"[^>]*>', home).group(0)
    token = admin_csrf(admin, "/admin/textes")
    admin.post("/admin/textes", data={
        "csrf_token": token, "play_store_url": "https://play.google.com/store/apps/details?id=x"})
    home = admin.get("/").text
    assert not soon_button(home) and "btn--soon" not in home
    assert 'href="https://play.google.com/store/apps/details?id=x" rel="noopener">Télécharger sur Google Play</a>' in home


def test_no_external_resources(admin):
    token = admin_csrf(admin, "/admin/apk")
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                           "make_current": "1"},
               files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    for path in ("/", "/contact", "/mentions-legales", "/confidentialite"):
        page = admin.get(path).text
        for tag in re.findall(r"<(?:script|img|link)\b[^>]*>", page):
            url = re.search(r'(?:src|href)="([^"]*)"', tag)
            if not url or 'rel="canonical"' in tag or 'rel="alternate"' in tag:
                continue  # URL absolues sur SITE_URL (canonique, hreflang)
            assert url.group(1).startswith("/"), (path, tag)
        assert "fonts.googleapis" not in page and "Material Symbols" not in page
        assert " style=" not in page  # CSP « style-src 'self' » : aucun style en ligne
    css = admin.get("/static/css/site.css").text
    assert "@import" not in css and "http" not in css


def test_language_selector_on_every_page(client):
    for path in ("/", "/contact", "/en/", "/es/contacto"):
        page = client.get(path).text
        assert 'class="lang lang--bar"' in page and 'class="lang lang--menu"' in page


def test_hero_bubble_uses_first_real_screenshot(client, settings):
    assert "hero__bubble" not in client.get("/").text  # captures initiales sans image
    conn = db.connect(settings.db_path)
    with conn:
        ids = [r["id"] for r in db.list_screenshots(conn)]
        conn.execute("UPDATE screenshot SET filename = ? WHERE id = ?",
                     ("a" * 32 + ".png", ids[1]))
    conn.close()
    page = client.get("/").text
    assert '<span class="hero__bubble"><img src="/media/' + "a" * 32 + '.png" alt=""' in page


def test_nav_points_to_sections(client):
    page = client.get("/").text
    for anchor in ("le-jeu", "solo-duel", "comment-jouer", "captures", "faq", "telecharger"):
        assert f'id="{anchor}"' in page
    assert 'href="/#solo-duel" data-section="solo-duel"' in page
