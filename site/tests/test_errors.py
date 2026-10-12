"""Pages d'erreur : même pied de page que les autres pages (logo du studio, phrase
du jeu), dans les trois langues ; erreurs en JSON sous /api/."""

from html import unescape

import pytest


@pytest.mark.parametrize("path,footer", [
    ("/nexiste-pas", "Le Pong qu'on joue en inclinant son téléphone, seul ou à deux"),
    ("/en/nope", "The Pong you play by tilting your phone, alone or with a friend"),
    ("/es/nada", "El Pong que se juega inclinando el teléfono, solo o entre dos"),
])
def test_error_page_footer_like_home(client, path, footer):
    r = client.get(path)
    assert r.status_code == 404
    page = unescape(r.text)
    brand = page.split('<div class="footer__brand">', 1)[1].split("</div>", 1)[0]
    assert 'class="studio-logo"' in brand and 'alt="Nexora"' in brand
    assert footer in brand
    # Bas du pied de page et en-tête complets, comme sur l'accueil.
    assert 'class="footer__credit"' in page and 'class="brand__by"' in page
    assert '<meta name="robots" content="noindex">' in page


def test_other_error_codes_keep_footer(client):
    r = client.post("/en/privacy")
    assert r.status_code == 405
    assert 'class="studio-logo"' in r.text and "Method not allowed." in unescape(r.text)
    r = client.get("/telecharger")  # pas d'APK : message de l'application
    assert r.status_code == 404 and 'class="footer__about"' in r.text


@pytest.mark.parametrize("path", ["/api/", "/api/inconnu", "/api/app/nope", "/api"])
def test_api_unknown_path_is_json(client, path):
    r = client.get(path)
    assert r.status_code == 404
    assert r.headers["content-type"].startswith("application/json")
    assert r.json() == {"error": "not_found"}


def test_api_other_errors_are_json(client):
    r = client.post("/api/app/studio")
    assert r.status_code == 405
    assert r.headers["content-type"].startswith("application/json")
    assert r.json() == {"error": "method_not_allowed"}
    assert "allow" in r.headers  # en-tête de la réponse 405 conservé


def test_non_api_paths_keep_html(client):
    for path in ("/apis", "/api-doc", "/en/api/x"):
        r = client.get(path)
        assert r.status_code == 404 and r.headers["content-type"].startswith("text/html")
