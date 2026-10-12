"""Retouches de l'accueil « Néon magenta » : « Installer l'APK » une seule fois,
bouton de retour en haut."""

import re

from conftest import admin_csrf, make_apk, visible


def with_apk(admin):
    token = admin_csrf(admin, "/admin/apk")
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                           "make_current": "1"},
               files={"apk": ("a.apk", make_apk(), "application/octet-stream")})


def section(page: str, start: str, end: str) -> str:
    return page[page.index(start):page.index(end, page.index(start))]


def test_install_apk_only_once_in_download_section(admin):
    with_apk(admin)
    page = visible(admin.get("/").text)
    assert page.count("Installer l'APK") == 1
    download = section(page, 'id="telecharger"', "</section>")
    assert "Installer l'APK" in download and 'id="installer-apk"' in download
    # Ni dans l'en-tête (barre et menu mobile), ni dans le pied de page.
    header = section(page, '<header class="masthead">', "</header>")
    footer = section(page, '<footer class="footer">', "</footer>")
    assert "Installer" not in header and "Installer" not in footer
    assert 'href="/#installer-apk"' not in page


def test_menus_point_only_to_existing_sections(admin):
    with_apk(admin)
    page = admin.get("/").text
    for section_id in re.findall(r'data-section="([^"]+)"', page):
        assert f'id="{section_id}"' in page, section_id
    for anchor in re.findall(r'href="/#([^"]+)"', page):
        assert f'id="{anchor}"' in page, anchor


def test_back_to_top_button(client):
    for path in ("/", "/contact", "/mentions-legales", "/nexiste-pas"):
        page = client.get(path).text
        assert '<body id="haut"' in page, path
        button = re.search(r'<a class="to-top"[^>]*>', page).group(0)
        assert 'href="#haut"' in button
        assert 'aria-label="Revenir en haut de la page"' in button
        assert " hidden" in button  # affiché par nav.js seulement
    js = client.get("/static/js/nav.js").text
    assert ".to-top" in js and "prefers-reduced-motion" in js
    css = client.get("/static/css/site.css").text
    assert ".to-top" in css and "safe-area-inset-bottom" in css
