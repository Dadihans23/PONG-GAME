"""Génère les secrets du fichier .env.

    python -m app.hashpw            -> demande le mot de passe, affiche ADMIN_PASSWORD_HASH
    python -m app.hashpw --secret   -> affiche une SECRET_KEY aléatoire
"""

from __future__ import annotations

import getpass
import secrets
import sys

from .security import hash_password


def main(argv: list[str]) -> int:
    if "--secret" in argv:
        print(f"SECRET_KEY={secrets.token_urlsafe(48)}")
        return 0
    if sys.stdin.isatty():
        password = getpass.getpass("Mot de passe d'administration : ")
        if password != getpass.getpass("Confirmez : "):
            print("Les deux saisies sont différentes.", file=sys.stderr)
            return 1
    else:  # mot de passe passé par un tube : echo ... | python -m app.hashpw
        password = sys.stdin.readline().rstrip("\n")
    if len(password) < 12:
        print("Choisissez au moins 12 caractères.", file=sys.stderr)
        return 1
    print(f"ADMIN_PASSWORD_HASH={hash_password(password)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
