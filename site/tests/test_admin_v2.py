"""Administration v2 (maquette « Tilto Admin v2 ») : tableau de bord calculé,
messages, erreurs sous les champs, tableaux enregistrés d'un bloc, horodatage,
étapes d'installation en titre + précision."""

import re
import sqlite3
from html import unescape

from app import db
from conftest import PNG_1PX, admin_csrf, csrf_from, make_apk


def add_message(settings, name="Tom", read=0, subject="Question"):
    conn = db.connect(settings.db_path)
    with conn:
        cur = conn.execute(
            "INSERT INTO contact_message (created_at, name, email, subject, message, is_read)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (db.now_iso(), name, "tom@example.com", subject, "Bonjour", read))
    conn.close()
    return cur.lastrowid


def complete_site(admin, settings):
    """Remplit tout ce que le tableau de bord demande."""
    token = admin_csrf(admin, "/admin/mentions-legales")
    admin.post("/admin/mentions-legales", data={
        "csrf_token": token, "legal_publisher": "Jean Dupont", "legal_form": "Particulier",
        "legal_address": "1 rue X", "legal_email": "jean@example.com",
        "legal_director": "Jean Dupont", "legal_host_name": "Hébergeur",
        "legal_host_address": "2 rue Y", "legal_host_phone": "+33 1 00 00 00 00"})
    admin.post("/admin/textes", data={"csrf_token": token, "contact_email": "a@example.com"})
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                           "make_current": "1", "release_notes": "Nouveau"},
               files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    page = admin.get("/admin/captures").text
    for shot_id in dict.fromkeys(re.findall(r"/admin/captures/(\d+)/modifier", page)):
        admin.post(f"/admin/captures/{shot_id}/modifier",
                   data={"csrf_token": token, "caption": "Légende"},
                   files={"image": ("a.png", PNG_1PX, "image/png")})


# --- Tableau de bord ------------------------------------------------------------------

def test_dashboard_todo_from_real_state(admin):
    page = unescape(admin.get("/admin").text)
    assert "À faire pour que le site soit complet" in page
    assert "Compléter les mentions légales" in page
    assert "Déposer un APK" in page
    assert "0 sur 4 captures ont une image." in page
    assert "Renseigner l'adresse de contact" in page
    assert "Mentions légales incomplètes" in page
    assert "non renseigné" in page  # lien Play Store vide
    assert "Le site est complet" not in page


def test_dashboard_complete(admin, settings):
    complete_site(admin, settings)
    page = unescape(admin.get("/admin").text)
    assert "Le site est complet. Rien à faire." in page
    assert "À faire pour que le site soit complet" not in page
    assert "Mentions légales incomplètes" not in page
    assert "4 sur 4 avec image" in page
    assert "1 nouveauté pour la 1.0.0" in page


# --- Messages ---------------------------------------------------------------------------

def test_unread_count_in_menu(admin, settings):
    add_message(settings)
    add_message(settings, name="Léo")
    page = admin.get("/admin/textes").text
    assert 'Messages <strong class="badge">2</strong>' in page
    assert '<span class="topbar__count"> · 2</span>' in page
    assert "Messages · 2 non lus" in unescape(admin.get("/admin").text)


def test_open_marks_read_then_mark_unread(admin, settings):
    msg_id = add_message(settings)
    page = admin.get(f"/admin/messages/{msg_id}").text
    assert "Marquer comme non lu" in page
    assert 'class="badge"' not in page  # ouvert = lu
    token = csrf_from(page)
    assert admin.post(f"/admin/messages/{msg_id}/non-lu").status_code == 403  # sans CSRF
    r = admin.post(f"/admin/messages/{msg_id}/non-lu", data={"csrf_token": token})
    assert "Message marqué comme non lu." in unescape(r.text)
    assert 'Messages <strong class="badge">1</strong>' in r.text
    assert admin.post("/admin/messages/99999/non-lu", data={"csrf_token": token}).status_code == 404


# --- Erreurs sous le champ ----------------------------------------------------------------

def test_field_error_keeps_values(admin, settings):
    token = admin_csrf(admin, "/admin/textes")
    r = admin.post("/admin/textes", data={"csrf_token": token, "tagline": "Accroche gardée",
                                          "contact_email": "contact@tilto"})
    assert r.status_code == 400
    page = unescape(r.text)
    assert "Rien n'a été enregistré : corrige le champ en rouge." in page
    assert 'value="contact@tilto"' in page and "Accroche gardée" in page
    assert re.search(r'id="f-contact_email"[^>]*aria-invalid="true"', page)
    assert '<p class="field__err" id="e-f-contact_email">Cette adresse e-mail n\'est pas valide.</p>' in page
    conn = db.connect(settings.db_path)
    assert db.get_settings(conn)["tagline"] != "Accroche gardée"  # rien d'enregistré
    conn.close()


def test_field_errors_lists_faq_studio_apk(admin):
    token = admin_csrf(admin, "/admin/listes/etapes")
    r = admin.post("/admin/listes/etapes/ajouter",
                   data={"csrf_token": token, "title": "", "body": "Précision gardée"})
    page = unescape(r.text)
    assert r.status_code == 400 and "L'étape n'a pas été ajoutée : il manque le titre." in page
    assert "Le titre est obligatoire." in page and "Précision gardée" in page
    assert re.search(r'<details class="add" id="ajout" open>', page)

    r = admin.post("/admin/faq/ajouter", data={"csrf_token": token, "question": "Q ?",
                                               "anchor": "internet"})
    assert "Cette ancre est déjà utilisée par la question 1." in unescape(r.text)

    r = admin.post("/admin/studio", data={"csrf_token": token, "studio_name": ""})
    assert r.status_code == 400 and "Le nom du studio est obligatoire." in unescape(r.text)

    r = admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "2.1 beta"})
    page = unescape(r.text)
    assert "Numéro de version invalide" in page and "Choisis un fichier APK." in page
    assert 'value="2.1 beta"' in page


def test_screenshot_format_error_under_field(admin):
    token = admin_csrf(admin, "/admin/captures")
    r = admin.post("/admin/captures/ajouter", data={"csrf_token": token, "caption": "Gardée"},
                   files={"image": ("a.heic", b"pas une image", "image/heic")})
    page = unescape(r.text)
    assert "Format refusé. Utilise PNG, JPEG, WebP ou GIF." in page
    assert 'value="Gardée"' in page


# --- Tableaux enregistrés d'un bloc, horodatage ----------------------------------------------

def test_table_bulk_save_and_actions(admin, settings):
    page = admin.get("/admin/tableaux/bareme").text
    token = csrf_from(page)
    ids = re.findall(r'name="row-(\d+)-label"', page)
    data = {"csrf_token": token, "scoring_title": "Points"}
    for i in ids:
        data[f"row-{i}-label"] = f"L{i}"
        data[f"row-{i}-value"] = "v"
    admin.post("/admin/tableaux/bareme", data={**data, "action": "save"})
    home = unescape(admin.get("/").text)
    assert "Points" in home and f"<dt>L{ids[0]}</dt>" in home
    # Libellé vide : rien n'est enregistré, la valeur saisie reste affichée.
    r = admin.post("/admin/tableaux/bareme",
                   data={**data, f"row-{ids[1]}-label": "", f"row-{ids[0]}-label": "Gardé"})
    assert r.status_code == 400 and "Libellé : champ obligatoire." in unescape(r.text)
    assert 'value="Gardé"' in r.text
    # Supprimer une ligne enregistre aussi le reste.
    admin.post("/admin/tableaux/bareme",
               data={**data, f"row-{ids[0]}-label": "Modifié", "action": f"delete:{ids[1]}"})
    home = unescape(admin.get("/").text)
    assert "<dt>Modifié</dt>" in home and f"<dt>L{ids[1]}</dt>" not in home
    # Ajouter une ligne : nouvelle ligne vide, enregistrée si son libellé est rempli.
    r = admin.post("/admin/tableaux/bareme", data={"csrf_token": token, "action": "add"})
    assert 'id="nouvelle-ligne"' in r.text
    admin.post("/admin/tableaux/bareme", data={"csrf_token": token, "new-label": "Bonus",
                                               "new-value": "+10"})
    assert "<dt>Bonus</dt><dd>+10</dd>" in unescape(admin.get("/").text)


def test_saved_timestamp_on_texts(admin, settings):
    page = unescape(admin.get("/admin/textes").text)
    assert "Dernier enregistrement" not in page
    token = csrf_from(page)
    admin.post("/admin/textes", data={"csrf_token": token, "hero_note": "Gratuit"})
    page = unescape(admin.get("/admin/textes").text)
    match = re.search(r'Dernier enregistrement : <time datetime="([^"]+)" data-local="list">'
                      r"aujourd'hui, \d+ h \d\d UTC</time>", page)
    assert match
    conn = db.connect(settings.db_path)
    assert db.get_internal(conn, "_saved:textes") == match.group(1)
    assert "_saved:textes" not in db.get_settings(conn)  # réglage interne, jamais affiché
    conn.close()


# --- Étapes d'installation : titre + précision -------------------------------------------

def test_install_steps_title_and_detail(admin):
    page = admin.get("/admin/tableaux/installation").text
    assert ">Titre<" in page and ">Précision<" in page
    token, ids = csrf_from(page), re.findall(r'name="row-(\d+)-label"', page)
    admin.post("/admin/tableaux/installation", data={
        "csrf_token": token, **{f"row-{i}-label": f"Titre {i}" for i in ids},
        **{f"row-{i}-value": f"Précision {i}" for i in ids}})
    admin.post("/admin/apk/deposer", data={"csrf_token": token, "version": "1.0.0",
                                           "make_current": "1"},
               files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    home = unescape(admin.get("/").text)
    assert (f'<span class="install__step"><strong>Titre {ids[0]}</strong>'
            f"<span>Précision {ids[0]}</span></span>") in home


def test_install_migration_splits_default_text_only(tmp_path):
    path = tmp_path / "old.sqlite3"
    db.init_db(path, tmp_path / "img")
    conn = sqlite3.connect(path)
    with conn:
        conn.execute("DELETE FROM spec_row WHERE grp = 'install'")
        old = list(db.INSTALL_SPLIT)
        for pos, label in enumerate([old[0], "Mon étape à moi.", old[2]]):
            conn.execute("INSERT INTO spec_row (grp, position, label) VALUES ('install', ?, ?)",
                         (pos, label))
    conn.close()
    db.init_db(path, tmp_path / "img")
    conn = db.connect(path)
    rows = [(r["label"], r["value"]) for r in db.list_rows(conn, "install")]
    conn.close()
    assert rows == [db.V2_INSTALL[0], ("Mon étape à moi.", ""), db.V2_INSTALL[2]]


def test_fresh_install_steps_have_detail(admin, settings):
    conn = db.connect(settings.db_path)
    rows = [(r["label"], r["value"]) for r in db.list_rows(conn, "install")]
    conn.close()
    assert rows == list(db.V2_INSTALL)


def test_login_locked_page(client):
    from conftest import login
    for _ in range(3):
        login(client, "mauvais")
    r = login(client)
    assert r.status_code == 429
    assert "Trop de tentatives. Réessaie dans quelques minutes." in unescape(r.text)
