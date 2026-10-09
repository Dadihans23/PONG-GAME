"""Formulaire de contact : jeton anti-CSRF, délai minimal, validation.

Les pages publiques n'ont pas de session. Le jeton suit le principe du
« double envoi » : un cookie technique aléatoire (`tilto_contact`, limité au
chemin /contact, HttpOnly, SameSite=Strict) et, dans le formulaire, un jeton
signé avec SECRET_KEY qui contient la même valeur et l'heure d'affichage.
Un autre site ne peut ni lire le cookie ni fabriquer le jeton.
"""

from __future__ import annotations

import hmac
import re
import secrets
from dataclasses import dataclass, field

from itsdangerous import BadSignature, URLSafeSerializer

COOKIE_NAME = "tilto_contact"
COOKIE_PATH = "/contact"
TOKEN_MAX_AGE = 2 * 3600  # un formulaire affiché depuis plus longtemps a expiré
MAX_BODY_BYTES = 32 * 1024

SUBJECTS = ["Question", "Problème technique", "Suggestion", "Autre"]
MAX_NAME = 80
MAX_EMAIL = 254
MAX_MESSAGE = 2000
HONEYPOT_FIELD = "website"  # champ invisible : un humain le laisse vide

EMAIL_RE = re.compile(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"
)
_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def _serializer(secret_key: str) -> URLSafeSerializer:
    return URLSafeSerializer(secret_key, salt="tilto-contact-form")


def new_nonce() -> str:
    return secrets.token_urlsafe(24)


def issue_token(secret_key: str, nonce: str, now: float) -> str:
    return _serializer(secret_key).dumps({"n": nonce, "t": int(now)})


class TokenError(ValueError):
    pass


def check_token(secret_key: str, token: str | None, cookie_nonce: str | None,
                now: float) -> float:
    """Vérifie le jeton ; renvoie le nombre de secondes depuis l'affichage du formulaire."""
    if not token or not cookie_nonce:
        raise TokenError("absent")
    try:
        data = _serializer(secret_key).loads(token)
    except BadSignature as exc:
        raise TokenError("signature") from exc
    if not isinstance(data, dict) or not isinstance(data.get("n"), str) \
            or not isinstance(data.get("t"), int):
        raise TokenError("format")
    if not hmac.compare_digest(data["n"].encode(), cookie_nonce.encode()):
        raise TokenError("cookie")
    elapsed = now - data["t"]
    if elapsed > TOKEN_MAX_AGE or elapsed < -60:
        raise TokenError("expiré")
    return elapsed


def valid_email(value: str) -> bool:
    return len(value) <= MAX_EMAIL and bool(EMAIL_RE.match(value))


@dataclass
class ContactForm:
    name: str = ""
    email: str = ""
    subject: str = SUBJECTS[0]
    message: str = ""
    errors: list[str] = field(default_factory=list)

    @classmethod
    def from_form(cls, form) -> "ContactForm":
        def get(key: str) -> str:
            value = form.get(key, "")
            return value if isinstance(value, str) else ""

        # Nom, e-mail et sujet tiennent sur une ligne (ils vont dans les en-têtes
        # de l'e-mail de notification) : retours à la ligne et caractères de
        # contrôle sont retirés.
        name = _CONTROL.sub("", re.sub(r"[\r\n\t]+", " ", get("name"))).strip()[:MAX_NAME]
        email = get("email").strip()
        message = _CONTROL.sub("", get("message").replace("\r\n", "\n")).strip()
        return cls(name=name, email=email, subject=get("subject").strip(), message=message)

    def validate(self) -> bool:
        self.errors = []
        if not self.email:
            self.errors.append("Indique ton adresse e-mail, pour qu'on puisse te répondre.")
        elif not valid_email(self.email):
            self.errors.append("L'adresse e-mail n'est pas valide.")
        if self.subject not in SUBJECTS:
            self.errors.append("Choisis un sujet dans la liste.")
        if not self.message:
            self.errors.append("Écris ton message.")
        elif len(self.message) > MAX_MESSAGE:
            self.errors.append(
                f"Ton message est trop long ({len(self.message)} caractères, "
                f"{MAX_MESSAGE} au maximum).")
        return not self.errors
