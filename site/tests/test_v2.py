"""Site v2 : nouvelles données (fiche technique, caractéristiques, comparatif,
barème, FAQ, installation, notes de version, mentions légales), formulaire de
contact, page Messages, notification SMTP et migration des bases existantes."""

import re
import sqlite3
from dataclasses import replace
from html import unescape

import pytest
from fastapi.testclient import TestClient

from app import db, reseed_v2
from app.config import Settings, SmtpConfig
from app.main import create_app
from app.render import date_short
from conftest import admin_csrf, csrf_from, make_apk


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


# --- Page d'accueil : contenu initial v2 --------------------------------------------

def test_home_v2_initial_content(client):
    page = unescape(client.get("/").text)
    assert '<p class="kicker">PONG VERTICAL · ANDROID · SOLO ET DUEL LOCAL</p>' in page
    assert "Ta raquette est en bas, celle de l'adversaire en haut." in page
    for label, value in [("MODES", "Solo · Duel"), ("JOUEURS", "1 ou 2"),
                         ("INTERNET", "Jamais requis"), ("ANDROID", "5.0 et plus"),
                         ("PRIX", "Gratuit")]:
        assert f"<dt>{label}</dt><dd>{value}</dd>" in page
    assert "Quatre idées, poussées jusqu'au bout." in page
    assert "<dt>Format</dt><dd>Premier à 5 points</dd>" in page
    assert "<dt>Où</dt><dd>Accueil › Réglages</dd>" in page
    assert 'id="solo-duel"' in page
    assert ("<th scope=\"row\">Pause</th><td>Oui, avec musique</td>"
            "<td>Non, le duel ne s'arrête pas</td>") in page
    assert "<dt>Chaque renvoi</dt><dd>+50</dd>" in page
    assert "<dt>La balle accélère</dt><dd>tous les 4 renvois</dd>" in page
    assert "Le score reste discret, la balle en vedette." in page
    for anchor in ("internet", "iphone", "duel-connexion", "petit-telephone",
                   "pubs-achats", "sensibilite"):
        assert f'id="{anchor}"' in page
    # Pied de page généré
    assert 'href="/#duel-connexion">Le duel ne se connecte pas</a>' in page
    assert 'href="/#sensibilite">Régler la sensibilité</a>' in page
    assert 'href="/contact">Contact</a>' in page
    assert 'href="/mentions-legales">Mentions légales</a>' in page
    assert "Android est une marque de Google LLC." in page
    assert "mailto:" not in page


def test_wrong_mockup_claims_are_absent(client):
    page = unescape(client.get("/").text) + unescape(client.get("/confidentialite").text)
    for wrong in ("7.0 et plus", "18 Mo", "2.0.0", "Tes scores restent", "coque magnétique",
                  "sous deux jours", "Nouvel accueil", "avec les flèches", "NOUVEAU",
                  "Versions précédentes", "Presse"):
        assert wrong not in page, wrong
    assert "il faudra désinstaller Tilto" not in page  # pas d'APK : bloc d'installation masqué


def test_date_short():
    assert date_short("2026-10-09") == "9 oct. 2026"
    assert date_short("2026-02-01T10:00:00+00:00") == "1 févr. 2026"


# --- Administration → page publique ----------------------------------------------------

def test_admin_texts_sections_reflected(admin):
    token = admin_csrf(admin, "/admin/textes")
    r = admin.post("/admin/textes", data={
        "csrf_token": token, "hero_kicker": "SUR-TITRE TEST", "faq_title": "Vos questions",
        "compare_title": "Comparer les modes", "footer_text": "Pied de page test.",
        "install_note": "Phrase Play Store test."}, follow_redirects=False)
    assert r.status_code == 303
    page = unescape(admin.get("/").text)
    for expected in ("SUR-TITRE TEST", "Vos questions", "Comparer les modes", "Pied de page test."):
        assert expected in page
    # Les champs non envoyés ne sont pas vidés.
    assert "<h1>TILTO</h1>" in page and "Quatre idées" in page


def table_ids(client, slug):
    page = client.get(f"/admin/tableaux/{slug}").text
    return csrf_from(page), re.findall(rf"/admin/tableaux/{slug}/(\d+)/modifier", page)


def test_compare_table_crud(admin):
    token, ids = table_ids(admin, "comparatif")
    assert len(ids) == 7
    admin.post("/admin/tableaux/comparatif/ajouter",
               data={"csrf_token": token, "label": "Durée", "value": "Illimitée",
                     "value2": "Quelques minutes"})
    page = unescape(admin.get("/").text)
    assert '<th scope="row">Durée</th><td>Illimitée</td><td>Quelques minutes</td>' in page
    admin.post(f"/admin/tableaux/comparatif/{ids[0]}/modifier",
               data={"csrf_token": token, "label": "Contre", "value": "L'IA", "value2": "Un ami"})
    admin.post(f"/admin/tableaux/comparatif/{ids[0]}/deplacer",
               data={"csrf_token": token, "direction": "down"})
    page = unescape(admin.get("/").text)
    assert page.index('scope="row">Niveaux<') < page.index('scope="row">Contre<')
    admin.post(f"/admin/tableaux/comparatif/{ids[0]}/supprimer", data={"csrf_token": token})
    assert 'scope="row">Contre<' not in unescape(admin.get("/").text)
    # Libellé obligatoire
    r = admin.post("/admin/tableaux/comparatif/ajouter",
                   data={"csrf_token": token, "label": "", "value": "x"})
    assert "champ obligatoire" in unescape(r.text)


def test_hero_specs_scoring_install_tables(admin):
    token, ids = table_ids(admin, "fiche")
    admin.post(f"/admin/tableaux/fiche/{ids[3]}/modifier",
               data={"csrf_token": token, "label": "ANDROID", "value": "6.0 et plus"})
    token, _ = table_ids(admin, "bareme")
    admin.post("/admin/tableaux/bareme/ajouter",
               data={"csrf_token": token, "label": "Nouveau record", "value": "or"})
    page = unescape(admin.get("/").text)
    assert "<dt>ANDROID</dt><dd>6.0 et plus</dd>" in page
    assert "<dt>Nouveau record</dt><dd>or</dd>" in page
    assert admin.get("/admin/tableaux/installation").status_code == 200
    assert admin.get("/admin/tableaux/inconnu").status_code == 404
    # Les caractéristiques se gèrent depuis la page des arguments.
    r = admin.get("/admin/tableaux/caracteristiques", follow_redirects=False)
    assert r.headers["location"] == "/admin/listes/arguments"


def test_feature_specs_and_short_body(admin):
    page = admin.get("/admin/listes/arguments").text
    token = csrf_from(page)
    first = re.findall(r"/admin/listes/arguments/(\d+)/modifier", page)[0]
    admin.post("/admin/tableaux/caracteristiques/ajouter",
               data={"csrf_token": token, "item_id": first, "label": "Calibrage",
                     "value": "Aucun"})
    admin.post(f"/admin/listes/arguments/{first}/modifier",
               data={"csrf_token": token, "kicker": "INCLINE", "title": "Titre modifié",
                     "body": "Texte.", "short_body": "Court mobile."})
    home = unescape(admin.get("/").text)
    assert "<dt>Calibrage</dt><dd>Aucun</dd>" in home and "Titre modifié" in home
    # Argument inconnu : refusé
    r = admin.post("/admin/tableaux/caracteristiques/ajouter",
                   data={"csrf_token": token, "item_id": "99999", "label": "X"})
    assert r.status_code == 404
    # Supprimer l'argument supprime ses caractéristiques
    admin.post(f"/admin/listes/arguments/{first}/supprimer", data={"csrf_token": token})
    assert "Calibrage" not in unescape(admin.get("/").text)


def test_feature_short_body_stored(admin, settings):
    conn = db.connect(settings.db_path)
    rows = conn.execute("SELECT kicker, short_body FROM content_item WHERE kind = 'feature'"
                        " ORDER BY position").fetchall()
    conn.close()
    assert rows[0]["short_body"].startswith("Plus tu penches")


def test_faq_admin(admin):
    page = admin.get("/admin/faq").text
    token = csrf_from(page)
    ids = re.findall(r"/admin/faq/(\d+)/modifier", page)
    assert len(ids) == 6
    admin.post("/admin/faq/ajouter", data={
        "csrf_token": token, "question": "Ça vide la batterie ?", "answer": "Très peu.",
        "anchor": "", "footer_label": "Batterie"})
    home = unescape(admin.get("/").text)
    assert 'id="ca-vide-la-batterie"' in home  # ancre tirée de la question
    assert 'href="/#ca-vide-la-batterie">Batterie</a>' in home
    for bad, message in [("Pas Valide", "Identifiant d'ancre invalide"),
                         ("faq", "déjà pris par une section"),
                         ("internet", "déjà utilisé")]:
        r = admin.post("/admin/faq/ajouter", data={"csrf_token": token, "question": "Q ?",
                                                    "anchor": bad})
        assert message in unescape(r.text), bad
    # Modifier une question en gardant son ancre
    admin.post(f"/admin/faq/{ids[0]}/modifier", data={
        "csrf_token": token, "question": "Internet est-il nécessaire ?", "answer": "Non.",
        "anchor": "internet"})
    home = unescape(admin.get("/").text)
    assert "Internet est-il nécessaire ?" in home and 'id="internet"' in home
    admin.post(f"/admin/faq/{ids[0]}/deplacer", data={"csrf_token": token, "direction": "down"})
    home = unescape(admin.get("/").text)
    assert home.index('id="iphone"') < home.index('id="internet"')
    admin.post(f"/admin/faq/{ids[0]}/supprimer", data={"csrf_token": token})
    assert 'id="internet"' not in admin.get("/").text


def test_screenshot_description(admin):
    page = admin.get("/admin/captures").text
    token = csrf_from(page)
    first = re.search(r"/admin/captures/(\d+)/modifier", page).group(1)
    admin.post(f"/admin/captures/{first}/modifier",
               data={"csrf_token": token, "caption": "Accueil", "description": "Desc <b>x</b>"})
    home = admin.get("/").text
    assert '<p class="capture__text">Desc &lt;b&gt;x&lt;/b&gt;</p>' in home


# --- APK : notes de version, date, empreinte ------------------------------------------

def test_release_notes_and_sha(admin):
    page = admin.get("/admin/apk").text
    assert "Mode Duel : deux téléphones" in unescape(page)  # notes 1.0.0 proposées
    token = csrf_from(page)
    admin.post("/admin/apk/deposer", data={
        "csrf_token": token, "version": "1.0.0", "make_current": "1",
        "release_notes": "- Première nouveauté\n\n— Deuxième nouveauté",
        "release_date": "2026-10-09"},
        files={"apk": ("a.apk", make_apk(), "application/octet-stream")})
    home = unescape(admin.get("/").text)
    assert "Nouveautés 1.0.0 · <time datetime=\"2026-10-09\">9 oct. 2026</time>" in home
    assert "<li>Première nouveauté</li><li>Deuxième nouveauté</li>" in home
    sha = admin.get("/telecharger").headers["x-checksum-sha256"]
    assert f"<code>{sha}</code>" in home
    assert 'id="installer-apk"' in home and "il faudra désinstaller Tilto" in home
    assert 'href="/#nouveautes">Nouveautés 1.0.0</a>' in home
    assert "APK v1.0.0 ·" in home
    # Modifier les notes
    apk_id = re.search(r"/admin/apk/(\d+)/notes", admin.get("/admin/apk").text).group(1)
    admin.post(f"/admin/apk/{apk_id}/notes", data={"csrf_token": token,
                                                  "release_notes": "Autre note",
                                                  "release_date": ""})
    home = unescape(admin.get("/").text)
    assert "<li>Autre note</li>" in home and "Première nouveauté" not in home
    r = admin.post(f"/admin/apk/{apk_id}/notes", data={"csrf_token": token,
                                                      "release_notes": "x",
                                                      "release_date": "2026-99-99"})
    assert "Date de version invalide" in unescape(r.text)


# --- Mentions légales -------------------------------------------------------------------

def test_legal_incomplete_then_complete(admin):
    assert "Mentions légales incomplètes" in unescape(admin.get("/admin").text)
    public = unescape(admin.get("/mentions-legales").text)
    assert "<h1>Mentions légales</h1>" in public
    assert "Contabo GmbH" in public
    assert "Éditeur du site" not in public  # aucun champ éditeur rempli
    token = admin_csrf(admin, "/admin/mentions-legales")
    data = {"csrf_token": token, "legal_publisher": "Jean Dupont",
            "legal_form": "Entrepreneur individuel", "legal_registration": "",
            "legal_address": "1 rue de la Paix\n75000 Paris", "legal_email": "jean@example.com",
            "legal_phone": "", "legal_director": "Jean Dupont",
            "legal_host_name": "Contabo GmbH", "legal_host_address": "",
            "legal_host_phone": "", "legal_extra": "## Crédits\n\nPolices Archivo (OFL)."}
    r = admin.post("/admin/mentions-legales", data=data)
    assert "incomplètes" in unescape(r.text)
    data.update(legal_host_address="Aschauer Straße 32a, 81549 München, Allemagne",
                legal_host_phone="+49 89 3564717 70")
    r = admin.post("/admin/mentions-legales", data=data)
    assert "Mentions légales enregistrées." in unescape(r.text)
    assert "Mentions légales incomplètes" not in unescape(admin.get("/admin").text)
    public = unescape(admin.get("/mentions-legales").text)
    for expected in ("Jean Dupont", "Entrepreneur individuel", "1 rue de la Paix<br>75000 Paris",
                     "jean@example.com", "Aschauer Straße", "<h2>Crédits</h2>"):
        assert expected in public, expected
    assert "Immatriculation" not in public  # champ facultatif vide
    data["legal_email"] = "pas-un-email"
    r = admin.post("/admin/mentions-legales", data=data)
    assert "n'est pas valide" in unescape(r.text)


# --- Formulaire de contact ----------------------------------------------------------------

def contact_token(client) -> str:
    r = client.get("/contact")
    assert r.status_code == 200
    assert r.headers["cache-control"] == "no-store"
    cookie = r.headers["set-cookie"].lower()
    assert "tilto_contact=" in cookie and "path=/contact" in cookie
    assert "httponly" in cookie and "samesite=strict" in cookie
    return csrf_from(r.text)


def send(client, clock, wait=5, **fields):
    token = contact_token(client)
    clock.now += wait
    data = {"csrf_token": token, "name": "Léa", "email": "lea@example.com",
            "subject": "Question", "message": "Bonjour, le duel marche en 4G ?", "website": ""}
    data.update(fields)
    return client.post("/contact", data=data, follow_redirects=False)


def stored_messages(settings):
    conn = db.connect(settings.db_path)
    rows = conn.execute("SELECT * FROM contact_message").fetchall()
    conn.close()
    return rows


def test_contact_success(client, clock, settings):
    r = send(client, clock)
    assert r.status_code == 303 and r.headers["location"] == "/contact/merci"
    assert "Message envoyé" in unescape(client.get("/contact/merci").text)
    rows = stored_messages(settings)
    assert len(rows) == 1
    assert (rows[0]["name"], rows[0]["email"], rows[0]["subject"]) == \
        ("Léa", "lea@example.com", "Question")
    assert rows[0]["is_read"] == 0
    assert "set-cookie" not in client.get("/").headers  # seul /contact dépose un cookie


@pytest.mark.parametrize("email", ["", "pas-un-email", "a@b", "x@exemple.com\nBcc: y@z.fr",
                                   "a b@exemple.com"])
def test_contact_invalid_email(client, clock, settings, email):
    r = send(client, clock, email=email)
    assert r.status_code == 400
    page = unescape(r.text)
    assert "adresse e-mail" in page
    assert "Bonjour, le duel marche en 4G ?" in page  # le message saisi est conservé
    assert stored_messages(settings) == []


def test_contact_other_validation(client, clock, settings):
    assert send(client, clock, message="").status_code == 400
    r = send(client, clock, message="x" * 2001)
    assert r.status_code == 400 and "trop long" in unescape(r.text)
    r = send(client, clock, subject="Spam")
    assert r.status_code == 400 and "Choisis un sujet" in unescape(r.text)
    assert stored_messages(settings) == []


def test_contact_honeypot(client, clock, settings):
    r = send(client, clock, website="http://spam.example")
    assert r.status_code == 303 and r.headers["location"] == "/contact/merci"
    assert stored_messages(settings) == []


def test_contact_too_fast(client, clock, settings):
    r = send(client, clock, wait=1)
    assert r.status_code == 400
    assert "trop vite" in unescape(r.text)
    assert stored_messages(settings) == []


def test_contact_rate_limited(client, clock, settings):
    for _ in range(3):
        assert send(client, clock).status_code == 303
    r = send(client, clock)
    assert r.status_code == 429
    assert "Réessaie dans une heure" in unescape(r.text)
    assert len(stored_messages(settings)) == 3


def test_contact_csrf(client, clock, settings):
    token = contact_token(client)
    clock.now += 5
    data = {"name": "", "email": "a@example.com", "subject": "Autre", "message": "Salut"}
    # Sans jeton
    assert client.post("/contact", data=data).status_code == 403
    # Jeton falsifié
    assert client.post("/contact", data={**data, "csrf_token": token + "x"}).status_code == 403
    # Jeton valide mais sans le cookie (requête venue d'un autre site)
    client.cookies.clear()
    r = client.post("/contact", data={**data, "csrf_token": token})
    assert r.status_code == 403 and "a expiré" in unescape(r.text)
    # Formulaire trop ancien
    token = contact_token(client)
    clock.now += 3 * 3600
    assert client.post("/contact", data={**data, "csrf_token": token}).status_code == 403
    assert stored_messages(settings) == []


def test_contact_body_too_large(client, clock):
    token = contact_token(client)
    clock.now += 5
    r = client.post("/contact", data={"csrf_token": token, "email": "a@example.com",
                                      "subject": "Autre", "message": "x" * 40_000})
    assert r.status_code == 413


def test_messages_admin(client, clock, settings):
    send(client, clock, name="Tom", email="tom@example.com", subject="Problème technique",
         message="Ligne 1\nLigne <2>")
    from conftest import login
    login(client)
    dashboard = unescape(client.get("/admin").text)
    assert "1 message non lu" in dashboard
    assert 'Messages <strong class="badge">1</strong>' in dashboard
    listing = client.get("/admin/messages").text
    token = csrf_from(listing)
    msg_id = re.search(r"/admin/messages/(\d+)\"", listing).group(1)
    page = client.get(f"/admin/messages/{msg_id}").text
    assert "Ligne 1<br>Ligne &lt;2&gt;" in page
    assert 'href="mailto:tom@example.com?subject=Re%3A%20Probl%C3%A8me%20technique"' in page
    client.post(f"/admin/messages/{msg_id}/lu", data={"csrf_token": token, "read": "1"})
    assert "non lu" not in unescape(client.get("/admin").text).split("Messages de contact")[0]
    assert stored_messages(settings)[0]["is_read"] == 1
    client.post(f"/admin/messages/{msg_id}/lu", data={"csrf_token": token, "read": "0"})
    assert stored_messages(settings)[0]["is_read"] == 0
    # Sans jeton CSRF : refusé
    assert client.post(f"/admin/messages/{msg_id}/supprimer").status_code == 403
    client.post(f"/admin/messages/{msg_id}/supprimer", data={"csrf_token": token})
    assert stored_messages(settings) == []
    assert client.get(f"/admin/messages/{msg_id}").status_code == 404


def test_messages_require_login(client):
    assert client.get("/admin/messages", follow_redirects=False).status_code == 303


# --- Notification SMTP (simulée) ------------------------------------------------------------

class FakeSMTP:
    sent: list = []
    fail = False

    def __init__(self, host, port, timeout=None, **kwargs):
        self.host, self.port = host, port
        self.calls = []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def starttls(self, context=None):
        self.calls.append("starttls")

    def login(self, user, password):
        self.calls.append(("login", user, password))

    def send_message(self, mail):
        if FakeSMTP.fail:
            raise OSError("connexion refusée")
        FakeSMTP.sent.append((self.calls, mail))


@pytest.fixture
def smtp_client(settings, monkeypatch):
    import app.mailer as mailer
    FakeSMTP.sent = []
    FakeSMTP.fail = False
    monkeypatch.setattr(mailer.smtplib, "SMTP", FakeSMTP)
    monkeypatch.setattr(mailer.smtplib, "SMTP_SSL", FakeSMTP)
    smtp = SmtpConfig(host="smtp.example.com", port=587, user="bot", password="pw",
                      sender="site@tilto.fun", notify_to="owner@example.com",
                      security="starttls")
    with TestClient(create_app(replace(settings, smtp=smtp))) as c:
        yield c


def test_smtp_notification_sent(smtp_client, settings):
    clock = FakeClock()
    smtp_client.app.state.contact_clock = clock
    assert send(smtp_client, clock, name="Léa").status_code == 303
    assert len(FakeSMTP.sent) == 1
    calls, mail = FakeSMTP.sent[0]
    assert calls == ["starttls", ("login", "bot", "pw")]
    assert mail["To"] == "owner@example.com"
    assert "lea@example.com" in mail["Reply-To"]
    assert "Question" in mail["Subject"]
    assert "Bonjour, le duel marche en 4G ?" in mail.get_content()
    assert "/admin/messages" in mail.get_content()


def test_smtp_failure_keeps_message(smtp_client, settings, caplog):
    FakeSMTP.fail = True
    clock = FakeClock()
    smtp_client.app.state.contact_clock = clock
    with caplog.at_level("ERROR", logger="tilto.mailer"):
        assert send(smtp_client, clock).status_code == 303
    assert len(stored_messages(settings)) == 1
    assert "Notification du message de contact impossible" in caplog.text


def test_no_smtp_without_config(client, clock, monkeypatch):
    import app.mailer as mailer
    called = []
    monkeypatch.setattr(mailer, "send", lambda *a: called.append(a))
    assert send(client, clock).status_code == 303
    assert called == []


def test_smtp_config_from_env():
    assert SmtpConfig.from_env({}) is None
    assert SmtpConfig.from_env({"SMTP_HOST": "h"}) is None  # incomplet : désactivé
    cfg = SmtpConfig.from_env({"SMTP_HOST": "h", "SMTP_PORT": "465", "SMTP_FROM": "a@b.fr",
                               "CONTACT_NOTIFY_TO": "c@d.fr"})
    assert cfg.security == "ssl" and cfg.port == 465
    cfg = SmtpConfig.from_env({"SMTP_HOST": "h", "SMTP_FROM": "a@b.fr",
                               "CONTACT_NOTIFY_TO": "c@d.fr"})
    assert cfg.security == "starttls" and cfg.port == 587
    from app.config import ConfigError
    with pytest.raises(ConfigError):
        SmtpConfig.from_env({"SMTP_HOST": "h", "SMTP_FROM": "a@b.fr",
                             "CONTACT_NOTIFY_TO": "c@d.fr", "SMTP_SECURITY": "aucune"})


# --- Migration d'une base au schéma actuel (v1) -----------------------------------------------

V1_SCHEMA = """
CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE content_item (
    id INTEGER PRIMARY KEY, kind TEXT NOT NULL CHECK (kind IN ('feature', 'step')),
    position INTEGER NOT NULL, kicker TEXT NOT NULL DEFAULT '', title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '');
CREATE TABLE screenshot (
    id INTEGER PRIMARY KEY, filename TEXT UNIQUE, caption TEXT NOT NULL DEFAULT '',
    position INTEGER NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE apk_release (
    id INTEGER PRIMARY KEY, version TEXT NOT NULL UNIQUE, filename TEXT NOT NULL UNIQUE,
    size_bytes INTEGER NOT NULL, sha256 TEXT NOT NULL, uploaded_at TEXT NOT NULL,
    is_current INTEGER NOT NULL DEFAULT 0);
CREATE UNIQUE INDEX apk_one_current ON apk_release (is_current) WHERE is_current = 1;
"""

V1_TAGLINE = ("Le Pong qu'on joue en inclinant son téléphone. "
              "Seul contre l'ordinateur, ou à deux sur le même Wi-Fi.")


def make_v1_db(path):
    conn = sqlite3.connect(path)
    conn.executescript(V1_SCHEMA)
    settings = {"game_name": "Tilto", "tagline": V1_TAGLINE, "hero_note": "Gratuit · Android",
                "download_title": "Télécharge Tilto",
                "download_text": "Pour téléphones Android. L'APK s'installe sans le Play Store.",
                "play_store_url": "", "contact_email": "moi@example.com",
                "studio_name": "Nexora", "studio_logo": "", "privacy_updated": "2026-10-09",
                "privacy_policy": "Intro.\n\n## Effacer tes données\n\nDésinstalle."}
    conn.executemany("INSERT INTO setting VALUES (?, ?)", settings.items())
    for pos, (k, t) in enumerate([("INCLINE", "Titre v1 incline"), ("À DEUX", "Titre v1 duo"),
                                  ("SENSIBILITÉ", "Titre v1 sens"), ("RECORDS", "Titre v1 rec")]):
        conn.execute("INSERT INTO content_item (kind, position, kicker, title, body)"
                     " VALUES ('feature', ?, ?, ?, 'corps v1')", (pos, k, t))
    for pos, t in enumerate(["Étape v1 a", "Tape l'écran.", "Étape v1 c"]):
        conn.execute("INSERT INTO content_item (kind, position, title, body)"
                     " VALUES ('step', ?, ?, '')", (pos, t))
    conn.execute("INSERT INTO screenshot VALUES (1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png',"
                 " 'Choisis ton mode', 0, '2026-10-09T00:00:00+00:00')")
    conn.execute("INSERT INTO screenshot VALUES (2, NULL, 'Renvoie, accélère', 1,"
                 " '2026-10-09T00:00:00+00:00')")
    conn.execute("INSERT INTO apk_release VALUES (1, '1.0.0', 'bbbb.apk', 1234, 'ff', "
                 "'2026-10-09T12:00:00+00:00', 1)")
    conn.commit()
    conn.close()


def test_migration_from_v1(tmp_path):
    path = tmp_path / "prod.sqlite3"
    make_v1_db(path)
    db.init_db(path, tmp_path / "img")
    db.init_db(path, tmp_path / "img")  # deuxième démarrage : aucun doublon
    conn = db.connect(path)
    try:
        cols = {t: {r["name"] for r in conn.execute(f"PRAGMA table_info({t})")}
                for t in ("content_item", "screenshot", "apk_release")}
        assert "short_body" in cols["content_item"]
        assert "description" in cols["screenshot"]
        assert {"release_notes", "release_date"} <= cols["apk_release"]
        site = db.get_settings(conn)
        # Valeurs existantes conservées
        assert site["tagline"] == V1_TAGLINE
        assert site["contact_email"] == "moi@example.com"
        assert site["download_text"].startswith("Pour téléphones Android.")
        assert site["privacy_policy"].startswith("Intro.")
        # Nouveaux réglages ajoutés
        assert site["hero_kicker"].startswith("PONG VERTICAL")
        assert site["legal_host_name"] == "Contabo GmbH" and site["legal_host_address"] == ""
        features = db.list_items(conn, "feature")
        assert [f["title"] for f in features][0] == "Titre v1 incline"  # pas écrasé
        assert features[0]["short_body"].startswith("Plus tu penches")
        assert len(db.list_rows(conn, "feature_spec", features[1]["id"])) == 4
        assert db.list_items(conn, "step")[1]["title"] == "Tape l'écran."
        shots = db.list_screenshots(conn)
        assert len(shots) == 2 and shots[0]["filename"].startswith("aaaa")
        assert shots[0]["description"] == ""
        # Nouveaux contenus, une seule fois
        assert len(db.list_rows(conn, "hero_spec")) == 5
        assert len(db.list_rows(conn, "compare")) == 7
        assert len(db.list_rows(conn, "scoring")) == 3
        assert len(db.list_rows(conn, "install")) == 3
        assert len(db.list_faq(conn)) == 6
        apk = db.current_apk(conn)
        assert apk["release_notes"] == db.V2_RELEASE_NOTES_1_0_0 and apk["sha256"] == "ff"
        # Un tableau vidé volontairement n'est pas recréé au démarrage suivant.
        with conn:
            conn.execute("DELETE FROM spec_row WHERE grp = 'compare'")
    finally:
        conn.close()
    db.init_db(path, tmp_path / "img")
    conn = db.connect(path)
    assert db.list_rows(conn, "compare") == []
    conn.close()


def test_reseed_v2(tmp_path, capsys):
    path = tmp_path / "prod.sqlite3"
    make_v1_db(path)
    assert reseed_v2.main(["--db", str(path)]) == 0  # simulation
    out = capsys.readouterr().out
    assert "Argument 1" in out and "Capture 3 ajoutée" in out and "Confidentialité" in out
    conn = db.connect(path)
    assert db.get_settings(conn)["tagline"] == V1_TAGLINE  # rien n'a changé
    conn.close()

    assert reseed_v2.main(["--db", str(path), "--apply", "--yes"]) == 0
    conn = db.connect(path)
    try:
        site = db.get_settings(conn)
        assert site["tagline"] == db.DEFAULT_SETTINGS["tagline"]
        assert "## Formulaire de contact" in site["privacy_policy"]
        assert site["privacy_policy"].index("Formulaire de contact") < \
            site["privacy_policy"].index("Effacer tes données")
        features = db.list_items(conn, "feature")
        assert [f["title"] for f in features] == [f["title"] for f in db.V2_FEATURES]
        assert [s["title"] for s in db.list_items(conn, "step")] == [t for t, _ in db.V2_STEPS]
        shots = db.list_screenshots(conn)
        assert [s["caption"] for s in shots] == [c for c, _ in db.V2_SCREENSHOTS]
        assert shots[0]["filename"].startswith("aaaa")  # image conservée
        assert site["contact_email"] == "moi@example.com"
    finally:
        conn.close()
    assert reseed_v2.main(["--db", str(path)]) == 0
    assert "Rien à changer" in capsys.readouterr().out


def test_settings_contact_env(tmp_path):
    from app.security import hash_password
    s = Settings.from_env({"SECRET_KEY": "x" * 40, "ADMIN_PASSWORD_HASH": hash_password("a", log_n=10),
                           "DATA_DIR": str(tmp_path), "CONTACT_MAX_PER_HOUR": "5"})
    assert s.contact_max_per_hour == 5 and s.contact_min_seconds == 3 and s.smtp is None
