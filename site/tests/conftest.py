import io
import re
import sys
import zipfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402
from app.security import hash_password  # noqa: E402

PASSWORD = "mot-de-passe-de-test"
PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c63000100000500010d0a2db40000000049454e44ae426082"
)


@pytest.fixture
def settings(tmp_path):
    return Settings(
        secret_key="x" * 40,
        admin_password_hash=hash_password(PASSWORD, log_n=10),  # rapide pour les tests
        data_dir=tmp_path / "data",
        max_apk_mb=1,
        max_image_mb=1,
        login_max_attempts=3,
    )


@pytest.fixture
def client(settings):
    with TestClient(create_app(settings)) as c:
        yield c


def csrf_from(html: str) -> str:
    match = re.search(r'name="csrf_token" value="([^"]+)"', html)
    assert match, "jeton CSRF absent du formulaire"
    return match.group(1)


def login(client, password=PASSWORD):
    token = csrf_from(client.get("/admin/connexion").text)
    return client.post("/admin/connexion", data={"csrf_token": token, "password": password},
                       follow_redirects=False)


@pytest.fixture
def admin(client):
    response = login(client)
    assert response.status_code == 303
    return client


def admin_csrf(client, page="/admin") -> str:
    return csrf_from(client.get(page).text)


def make_apk(extra: bytes = b"") -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("AndroidManifest.xml", b"\x03\x00\x08\x00" + extra)
        z.writestr("classes.dex", b"dex\n035\x00")
    return buf.getvalue()
