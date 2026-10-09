"""Mot de passe, session d'administration, CSRF, limitation des tentatives,
limite de taille des requêtes et en-têtes de sécurité."""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import threading
import time
from collections import deque

from starlette.requests import Request
from starlette.responses import PlainTextResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

# --- Mot de passe (scrypt, bibliothèque standard) -----------------------------
# Format : scrypt:<log2 N>:<r>:<p>:<sel base64>:<hachage base64>
# Ni « $ » ni espace : la valeur se colle telle quelle dans .env sans être
# interprétée par docker compose.

SCRYPT_LOG_N = 16  # N = 65 536, r = 8 : 64 Mo de mémoire par vérification
SCRYPT_R = 8
SCRYPT_P = 1


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def _scrypt(password: str, salt: bytes, log_n: int, r: int, p: int) -> bytes:
    n = 1 << log_n
    return hashlib.scrypt(
        password.encode("utf-8"), salt=salt, n=n, r=r, p=p,
        maxmem=256 * n * r + 1024 * 1024, dklen=32,
    )


def hash_password(password: str, log_n: int = SCRYPT_LOG_N, r: int = SCRYPT_R,
                  p: int = SCRYPT_P) -> str:
    salt = secrets.token_bytes(16)
    digest = _scrypt(password, salt, log_n, r, p)
    return f"scrypt:{log_n}:{r}:{p}:{_b64(salt)}:{_b64(digest)}"


def verify_password(password: str, encoded: str) -> bool:
    try:
        algo, log_n, r, p, salt, digest = encoded.split(":")
        if algo != "scrypt":
            return False
        log_n_i, r_i, p_i = int(log_n), int(r), int(p)
        if not (10 <= log_n_i <= 20 and 1 <= r_i <= 32 and 1 <= p_i <= 16):
            return False
        expected = _unb64(digest)
        actual = _scrypt(password, _unb64(salt), log_n_i, r_i, p_i)
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(actual, expected)


def password_fingerprint(encoded: str) -> str:
    """Empreinte courte du hachage : changer le mot de passe invalide les sessions."""
    return hashlib.sha256(encoded.encode()).hexdigest()[:16]


# --- CSRF --------------------------------------------------------------------

def csrf_token(request: Request) -> str:
    token = request.session.get("csrf")
    if not token:
        token = secrets.token_urlsafe(32)
        request.session["csrf"] = token
    return token


def csrf_valid(request: Request, submitted: str | None) -> bool:
    expected = request.session.get("csrf")
    if not expected or not submitted:
        return False
    return hmac.compare_digest(expected.encode(), submitted.encode())


# --- Limitation des tentatives de connexion ----------------------------------

class LoginLimiter:
    """Compte les événements (échecs de connexion, messages de contact) par clé
    (adresse IP) sur une fenêtre glissante, en mémoire."""

    def __init__(self, max_attempts: int, window_seconds: int, clock=time.monotonic):
        self.max_attempts = max_attempts
        self.window = window_seconds
        self.clock = clock
        self._failures: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def _prune(self, key: str) -> deque[float]:
        now = self.clock()
        q = self._failures.setdefault(key, deque())
        while q and now - q[0] > self.window:
            q.popleft()
        return q

    def blocked(self, key: str) -> bool:
        with self._lock:
            return len(self._prune(key)) >= self.max_attempts

    def fail(self, key: str) -> None:
        with self._lock:
            if len(self._failures) > 10_000:  # borne la mémoire
                self._failures.clear()
            self._prune(key).append(self.clock())

    # Même mécanisme pour le formulaire de contact : chaque envoi accepté compte.
    hit = fail

    def reset(self, key: str) -> None:
        with self._lock:
            self._failures.pop(key, None)


# --- Taille maximale des requêtes --------------------------------------------

class _TooLarge(Exception):
    pass


class BodySizeLimitMiddleware:
    """Refuse (413) un corps de requête plus gros que la limite du chemin,
    avant que le formulaire ne soit lu et copié sur le disque."""

    def __init__(self, app: ASGIApp, default_limit: int, path_limits: dict[str, int]):
        self.app = app
        self.default_limit = default_limit
        self.path_limits = path_limits

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["method"] in {"GET", "HEAD", "OPTIONS"}:
            await self.app(scope, receive, send)
            return
        limit = self.path_limits.get(scope["path"], self.default_limit)
        for name, value in scope.get("headers", []):
            if name == b"content-length":
                try:
                    if int(value) > limit:
                        await self._reject(scope, receive, send)
                        return
                except ValueError:
                    pass
        received = 0
        exceeded = False
        started = False

        async def limited_receive() -> Message:
            nonlocal received, exceeded
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    exceeded = True
                    raise _TooLarge
            return message

        async def guarded_send(message: Message) -> None:
            # Si l'application a transformé le dépassement en autre erreur
            # (FastAPI répond 400 quand la lecture du formulaire échoue), on
            # remplace sa réponse par un 413.
            nonlocal started
            if exceeded:
                if not started:
                    started = True
                    await self._reject(scope, receive, send)
                return
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, guarded_send)
        except _TooLarge:
            if not started:
                await self._reject(scope, receive, send)

    @staticmethod
    async def _reject(scope: Scope, receive: Receive, send: Send) -> None:
        response = PlainTextResponse("Fichier trop volumineux.", status_code=413)
        await response(scope, receive, send)


# --- En-têtes de sécurité ----------------------------------------------------

SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=(), interest-cohort=()",
    "Content-Security-Policy": (
        "default-src 'self'; img-src 'self' data:; style-src 'self'; "
        "script-src 'self'; font-src 'self'; object-src 'none'; "
        "base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
    ),
    "Cross-Origin-Opener-Policy": "same-origin",
}


class SecurityHeadersMiddleware:
    def __init__(self, app: ASGIApp, hsts: bool = False):
        self.app = app
        self.hsts = hsts

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_headers(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = list(message.get("headers", []))
                present = {k.lower() for k, _ in headers}
                for key, value in SECURITY_HEADERS.items():
                    if key.lower().encode() not in present:
                        headers.append((key.lower().encode(), value.encode()))
                if self.hsts:
                    headers.append((b"strict-transport-security", b"max-age=31536000"))
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive, send_with_headers)
