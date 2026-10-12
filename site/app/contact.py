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

from .i18n import ui

COOKIE_NAME = "tilto_contact"
# Chemin du cookie : la page Contact de la langue (/contact, /en/contact, /es/contacto).
COOKIE_PATH = "/contact"
TOKEN_MAX_AGE = 2 * 3600  # un formulaire affiché depuis plus longtemps a expiré
MAX_BODY_BYTES = 32 * 1024

# Valeurs envoyées et enregistrées (en français : l'administration est en français) ;
# le libellé affiché est traduit (i18n, clés subject_…).
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
    # Erreurs qui ne visent aucun champ (formulaire expiré, envoi trop rapide…).
    errors: list[str] = field(default_factory=list)
    # Erreurs par champ (email, subject, message), dans la langue de la page.
    field_errors: dict[str, str] = field(default_factory=dict)

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

    @property
    def has_errors(self) -> bool:
        return bool(self.errors or self.field_errors)

    def validate(self, lang: str = "fr") -> bool:
        errors = {}
        if not self.email:
            errors["email"] = ui("err_email_missing", lang)
        elif not valid_email(self.email):
            errors["email"] = ui("err_email_invalid", lang)
        if self.subject not in SUBJECTS:
            errors["subject"] = ui("err_subject", lang)
        if not self.message:
            errors["message"] = ui("err_message_missing", lang)
        elif len(self.message) > MAX_MESSAGE:
            errors["message"] = ui("err_message_long", lang, n=len(self.message),
                                   max=MAX_MESSAGE)
        self.field_errors = errors
        return not errors
