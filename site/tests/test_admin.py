from html import unescape

from conftest import PNG_1PX, admin_csrf, csrf_from, login, make_apk


# --- Connexion -------------------------------------------------------------------

def test_admin_requires_login(client):
    r = client.get("/admin", follow_redirects=False)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/connexion"
    assert client.get("/admin/apk", follow_redirects=False).status_code == 303


def test_login_ok_sets_secure_cookie(client):
    r = login(client)
    assert r.status_code == 303 and r.headers["location"] == "/admin"
    cookie = r.headers["set-cookie"].lower()
    assert "httponly" in cookie and "samesite=lax" in cookie and "path=/admin" in cookie
    assert client.get("/admin").status_code == 200


def test_login_wrong_password(client):
    r = login(client, "mauvais")
    assert r.status_code == 401
    assert "Mot de passe incorrect" in unescape(r.text)
    assert client.get("/admin", follow_redirects=False).status_code == 303


def test_login_rate_limited(client):
    for _ in range(3):
        assert login(client, "mauvais").status_code == 401
    r = login(client)  # même le bon mot de passe est refusé pendant le blocage
    assert r.status_code == 429


def test_login_without_csrf_refused(client):
    client.get("/admin/connexion")
    r = client.post("/admin/connexion", data={"password": "mot-de-passe-de-test"})
    assert r.status_code == 403


def test_logout(admin):
    token = admin_csrf(admin)
    r = admin.post("/admin/deconnexion", data={"csrf_token": token}, follow_redirects=False)
    assert r.status_code == 303
    assert admin.get("/admin", follow_redirects=False).status_code == 303


# --- CSRF et contenu --------------------------------------------------------------

def test_post_without_csrf_refused(admin):
    r = admin.post("/admin/textes", data={"game_name": "Pirate"})
    assert r.status_code == 403
    r = admin.post("/admin/textes", data={"game_name": "Pirate", "csrf_token": "faux"})
    assert r.status_code == 403
    assert "Pirate" not in admin.get("/").text


def test_unauthenticated_post_redirects(client):
    r = client.post("/admin/textes", data={"game_name": "X"}, follow_redirects=False)
    assert r.status_code == 303


def test_edit_texts_reflected_on_home(admin):
    token = admin_csrf(admin, "/admin/textes")
    r = admin.post("/admin/textes", data={
        "csrf_token": token, "game_name": "Tilto Pro", "tagline": "Nouvelle <b>accroche</b>",
        "hero_note": "Gratuit · Android 8+", "download_title": "Récupère Tilto",
        "download_text": "Phrase finale modifiée.",
        "play_store_url": "https://play.google.com/store/apps/details?id=x",
        "contact_email": "contact@example.com",
    }, follow_redirects=False)
    assert r.status_code == 303
    home = admin.get("/").text
    assert "TILTO PRO" in home
    assert "Nouvelle &lt;b&gt;accroche&lt;/b&gt;" in home  # échappé
    assert "https://play.google.com/store/apps/details?id=x" in home
    assert "mailto:contact@example.com" in home
    for expected in ("Gratuit · Android 8+", "Récupère Tilto", "Phrase finale modifiée."):
        assert expected in unescape(home)


def test_edit_texts_validation(admin):
    token = admin_csrf(admin, "/admin/textes")
    r = admin.post("/admin/textes", data={
        "csrf_token": token, "game_name": "Tilto", "play_store_url": "javascript:alert(1)",
    })
    assert r.status_code == 400
    assert "https://" in unescape(r.text)


def test_studio_name_and_lists(admin):
    token = admin_csrf(admin, "/admin/studio")
    admin.post("/admin/studio", data={"csrf_token": token, "studio_name": "Nouveau Studio"})
    admin.post("/admin/listes/arguments/ajouter",
               data={"csrf_token": token, "kicker": "TURBO", "title": "Mode turbo",
                     "body": "Ça va vite."})
    home = unescape(admin.get("/").text)
    assert 'alt="Nouveau Studio"' in home
    assert "Un jeu de Nouveau Studio · ©" in home
    assert "TURBO" in home and "Mode turbo" in home


def test_remove_studio_logo(admin, settings):
    token = admin_csrf(admin, "/admin/studio")
    admin.post("/admin/studio", data={"csrf_token": token, "studio_name": "Nexora",
                                      "remove_logo": "1"})
    home = admin.get("/").text
    assert 'class="studio-logo"' not in home
    assert list(settings.images_dir.iterdir()) == []  # fichier du logo supprimé


def test_privacy_edit(admin):
    token = admin_csrf(admin, "/admin/confidentialite")
    admin.post("/admin/confidentialite",
               data={"csrf_token": token, "privacy_updated": "2027-01-15",
                     "privacy_policy": "## Nouveau\n\nTexte à jour."})
    page = unescape(admin.get("/confidentialite").text)
    assert "<h2>Nouveau</h2>" in page and "Texte à jour." in page
    assert "Dernière mise à jour : 15 janvier 2027" in page
    r = admin.post("/admin/confidentialite",
                   data={"csrf_token": token, "privacy_updated": "2027-13-45",
                         "privacy_policy": "x"})
    assert "Date de mise à jour invalide" in unescape(r.text)


def test_list_move_and_delete(admin):
    page = admin.get("/admin/listes/etapes").text
    token = csrf_from(page)
    # Fait monter la deuxième étape en première position.
    import re
    ids = re.findall(r"/admin/listes/etapes/(\d+)/modifier", page)
    admin.post(f"/admin/listes/etapes/{ids[1]}/deplacer", data={"csrf_token": token, "direction": "up"})
    home = unescape(admin.get("/").text)
    assert home.index("Tape l'écran.") < home.index("Prends ton téléphone à deux mains.")
    admin.post(f"/admin/listes/etapes/{ids[1]}/supprimer", data={"csrf_token": token})
    assert "Tape l'écran." not in unescape(admin.get("/").text)


# --- Images --------------------------------------------------------------------------

def test_screenshot_png_accepted(admin):
    token = admin_csrf(admin, "/admin/captures")
    admin.post("/admin/captures/ajouter", data={"csrf_token": token, "caption": "Partie en cours"},
               files={"image": ("photo.png", PNG_1PX, "image/png")})
    home = admin.get("/").text
    import re
    src = re.search(r'src="(/media/[a-f0-9]{32}\.png)" alt="Partie en cours"', home).group(1)
    assert "<figcaption>Partie en cours</figcaption>" in home
    r = admin.get(src)
    assert r.status_code == 200 and r.headers["content-type"] == "image/png"


def test_screenshot_placeholder_gets_image(admin):
    import re
    page = admin.get("/admin/captures").text
    token = csrf_from(page)
    first_id = re.search(r"/admin/captures/(\d+)/modifier", page).group(1)
    admin.post(f"/admin/captures/{first_id}/modifier",
               data={"csrf_token": token, "caption": "Choisis ton mode"},
               files={"image": ("mode.png", PNG_1PX, "image/png")})
    home = admin.get("/").text
    assert re.search(r'src="/media/[a-f0-9]{32}\.png" alt="Choisis ton mode"', home)
    assert home.count('class="shot-placeholder"') == 2


def test_screenshot_not_image_refused(admin, settings):
    before = set(settings.images_dir.iterdir())
    token = admin_csrf(admin, "/admin/captures")
    r = admin.post("/admin/captures/ajouter", data={"csrf_token": token},
                   files={"image": ("photo.png", b"<?php echo 'hello'; ?>", "image/png")})
    assert "n'est pas une image" in unescape(r.text)
    assert set(settings.images_dir.iterdir()) == before


def test_screenshot_svg_refused(admin):
    token = admin_csrf(admin, "/admin/captures")
    svg = b'<svg xmlns="http://www.w3.org/2000/svg"></svg>'
    r = admin.post("/admin/captures/ajouter", data={"csrf_token": token},
                   files={"image": ("a.svg", svg, "image/svg+xml")})
    assert "n'est pas une image" in unescape(r.text)


def test_logo_svg_accepted_but_script_refused(admin):
    token = admin_csrf(admin, "/admin/studio")
    bad = b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'
    r = admin.post("/admin/studio", data={"csrf_token": token, "studio_name": "Nexora"},
                   files={"logo": ("logo.svg", bad, "image/svg+xml")})
    assert "n'est pas une image" in unescape(r.text)
    good = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>'
    admin.post("/admin/studio", data={"csrf_token": token, "studio_name": "Nexora"},
               files={"logo": ("logo.svg", good, "image/svg+xml")})
    import re
    src = re.search(r'src="(/media/[a-f0-9]{32}\.svg)"', admin.get("/").text).group(1)
    r = admin.get(src)
    assert r.headers["content-type"].startswith("image/svg+xml")
    assert "sandbox" in r.headers["content-security-policy"]


def test_image_too_large_refused(admin):
    token = admin_csrf(admin, "/admin/captures")
    big = PNG_1PX + b"\x00" * (3 * 1024 * 1024)
    r = admin.post("/admin/captures/ajouter", data={"csrf_token": token},
                   files={"image": ("big.png", big, "image/png")})
    assert r.status_code == 413


# --- APK -------------------------------------------------------------------------------

def test_fake_apk_refused(admin, settings):
    token = admin_csrf(admin, "/admin/apk")
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                               "make_current": "1"},
                   files={"apk": ("tilto.apk", b"pas un apk", "application/octet-stream")})
    assert "n'est pas un APK" in unescape(r.text)
    assert client_download_status(admin) == 404
    assert list(settings.apk_dir.iterdir()) == []


def test_zip_without_manifest_refused(admin):
    import io
    import zipfile
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("readme.txt", "bonjour")
    token = admin_csrf(admin, "/admin/apk")
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0"},
                   files={"apk": ("tilto.apk", buf.getvalue(), "application/zip")})
    assert "AndroidManifest.xml absent" in unescape(r.text)


def test_real_apk_accepted_and_downloadable(admin):
    token = admin_csrf(admin, "/admin/apk")
    apk = make_apk()
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.2.0",
                                               "make_current": "1"},
                   files={"apk": ("whatever name.apk", apk, "application/octet-stream")})
    assert "Version 1.2.0 déposée et publiée" in unescape(r.text)
    home = admin.get("/").text
    assert "Version 1.2.0" in home
    d = admin.get("/telecharger")
    assert d.status_code == 200
    assert d.headers["content-type"] == "application/vnd.android.package-archive"
    assert 'filename="Tilto-1.2.0.apk"' in d.headers["content-disposition"]
    assert d.content == apk


def test_apk_history_and_current(admin):
    token = admin_csrf(admin, "/admin/apk")
    for version in ("1.0.0", "1.1.0"):
        admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": version,
                                               "make_current": "1"},
                   files={"apk": ("a.apk", make_apk(version.encode()), "application/octet-stream")})
    # Version en double refusée.
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.1.0"},
                   files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    assert "existe déjà" in unescape(r.text)
    assert "Tilto-1.1.0.apk" in admin.get("/telecharger").headers["content-disposition"]
    import re
    page = admin.get("/admin/apk").text
    first_id = re.search(r"/admin/apk/(\d+)/courante", page).group(1)
    admin.post(f"/admin/apk/{first_id}/courante", data={"csrf_token": token})
    assert "Tilto-1.0.0.apk" in admin.get("/telecharger").headers["content-disposition"]


def test_invalid_version_refused(admin):
    token = admin_csrf(admin, "/admin/apk")
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "../../x"},
                   files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    assert "Numéro de version invalide" in unescape(r.text)


def test_apk_too_large_refused(admin):
    token = admin_csrf(admin, "/admin/apk")
    big = make_apk(b"\x00" * (3 * 1024 * 1024))
    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "9.0.0"},
                   files={"apk": ("a.apk", big, "application/octet-stream")})
    assert r.status_code == 413


def client_download_status(client) -> int:
    return client.get("/telecharger").status_code
