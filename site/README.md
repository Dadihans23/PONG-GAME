# Site de présentation de Tilto

Petit site FastAPI (rendu serveur Jinja2, SQLite, fichiers sur disque) qui présente le jeu, propose l'APK en téléchargement et le lien Play Store, publie la politique de confidentialité, et offre une administration protégée par mot de passe pour tout modifier sans toucher au code.

## Organisation

```
site/
├── app/
│   ├── main.py            création de l'application (uvicorn --factory app.main:create_app)
│   ├── config.py          variables d'environnement
│   ├── db.py              schéma SQLite, contenu initial, requêtes
│   ├── security.py        mot de passe scrypt, CSRF, limitation, taille des requêtes, en-têtes
│   ├── uploads.py         vérification et enregistrement des images et des APK
│   ├── render.py          gabarits et filtres (taille, date, texte enrichi)
│   ├── routes_public.py   /, /confidentialite, /telecharger, /media/…, /sante
│   ├── routes_admin.py    /admin/…
│   ├── hashpw.py          génération du hachage du mot de passe et de la clé secrète
│   ├── templates/         gabarits HTML (publics, et admin/)
│   ├── seed/              logo initial du studio, copié dans les données au premier démarrage
│   └── static/            css/site.css, js/admin.js, fonts/ (Archivo)
├── tests/                 pytest
├── Dockerfile, docker-compose.yml, .env.example
└── requirements.txt (production), requirements-dev.txt (tests)
```

Les données (base `tilto.sqlite3`, `uploads/images`, `uploads/apk`) vivent dans `DATA_DIR` : le volume Docker `tilto-data` en production, `./data` en local. Rien n'est écrit dans le dossier du code.

## Lancer en local sans Docker

```bash
cd site
python -m venv .venv
.venv/bin/pip install -r requirements-dev.txt        # Windows : .venv\Scripts\pip
cp .env.example .env
.venv/bin/python -m app.hashpw --secret               # copier la ligne SECRET_KEY=… dans .env
.venv/bin/python -m app.hashpw                        # copier la ligne ADMIN_PASSWORD_HASH=… dans .env
set -a; . ./.env; set +a                              # charger .env dans le shell
.venv/bin/uvicorn app.main:create_app --factory --port 8085
```

Le site répond sur http://127.0.0.1:8085, l'administration sur http://127.0.0.1:8085/admin.

Tests : `.venv/bin/python -m pytest`

## Lancer avec Docker

```bash
cd site
cp .env.example .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret   # -> SECRET_KEY dans .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw            # -> ADMIN_PASSWORD_HASH dans .env
docker compose up -d --build
```

Au premier démarrage, la base et le contenu initial sont créés automatiquement : textes de la maquette « Tilto Site » (héros, 4 arguments, 3 étapes, 3 légendes de captures, bloc de téléchargement, politique de confidentialité de la planche 3c), studio Nexora et son logo clair. Restent à saisir dans l'administration : le lien Play Store, l'adresse de contact, les images des captures et l'APK.

## Installation sur le VPS

Docker est déjà installé ; le site n'utilise que le port choisi dans `HOST_PORT` (8085 par défaut) et ne touche ni à 80 ni à 443.

```bash
# 1. Récupérer le dossier (clone du dépôt, ou copie du seul dossier site/)
git clone <url-du-depot> tilto && cd tilto/site
#   ou depuis le poste : scp -r site/ utilisateur@vps:~/tilto-site && ssh utilisateur@vps && cd ~/tilto-site

# 2. Créer .env
cp .env.example .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret
docker compose run --rm --no-deps tilto-site python -m app.hashpw
nano .env          # coller SECRET_KEY et ADMIN_PASSWORD_HASH, ajuster HOST_PORT si 8085 est pris
chmod 600 .env

# 3. Démarrer
docker compose up -d --build

# 4. Vérifier
docker compose ps                         # STATUS doit afficher (healthy)
curl -s http://127.0.0.1:8085/sante       # {"status":"ok"}
docker compose logs --tail 50
```

Le site est alors visible sur `http://<ip-du-vps>:8085` (ouvrir ce port dans le pare-feu si besoin, par exemple `ufw allow 8085/tcp`).

### Mettre à jour

```bash
git pull                   # ou recopier le dossier site/
docker compose up -d --build
```

La base et les fichiers sont dans le volume `tilto-data` : la reconstruction de l'image ne les touche pas. Le schéma est créé avec `CREATE TABLE IF NOT EXISTS` et le contenu initial n'est inséré que s'il manque.

### Sauvegarder et restaurer le volume

```bash
# Sauvegarde (archive datée dans le dossier courant)
docker run --rm -v tilto-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/tilto-data-$(date +%F).tar.gz -C /data .

# Restauration (site arrêté)
docker compose down
docker run --rm -v tilto-data:/data -v "$PWD":/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/tilto-data-AAAA-MM-JJ.tar.gz -C /data"
docker compose up -d
```

Pour une copie cohérente de la base pendant que le site tourne : `docker compose exec tilto-site python -c "import sqlite3; s=sqlite3.connect('/data/tilto.sqlite3'); d=sqlite3.connect('/data/backup.sqlite3'); s.backup(d)"`, puis sauvegarder le volume.

### Changer le mot de passe

Générer un nouveau hachage (`python -m app.hashpw`), le mettre dans `.env`, puis `docker compose up -d`. Toutes les sessions ouvertes sont invalidées.

## Plus tard : nom de domaine, Nginx et HTTPS

Quand le domaine pointe vers le VPS, faire passer le site par le serveur web existant :

1. Dans `.env` : `HOST_BIND=127.0.0.1` (le port n'est plus joignable de l'extérieur), `FORWARDED_ALLOW_IPS=*` (uvicorn fait confiance aux en-têtes `X-Forwarded-*` envoyés par Nginx ; sans risque puisque seul le serveur local peut joindre le port), puis `COOKIE_SECURE=true` une fois le HTTPS actif. `docker compose up -d`.
2. FastAPI/uvicorn tourne déjà avec `--proxy-headers` (voir `Dockerfile`) : avec `FORWARDED_ALLOW_IPS` réglé, il utilise la vraie IP du visiteur (limitation des connexions) et le schéma `https`.
3. Bloc Nginx (par exemple `/etc/nginx/sites-available/tilto`) :

```nginx
server {
    listen 80;
    server_name tilto.exemple.com;

    # Taille d'upload : au moins MAX_APK_MB + 2 Mo
    client_max_body_size 210m;

    location / {
        proxy_pass http://127.0.0.1:8085;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host  $host;

        # Dépôt d'un APK de 200 Mo sur une connexion lente
        proxy_read_timeout    300s;
        proxy_send_timeout    300s;
        proxy_request_buffering off;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/tilto /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

4. HTTPS : `sudo certbot --nginx -d tilto.exemple.com` (Certbot ajoute le bloc `listen 443 ssl` et la redirection), ou le mécanisme du serveur web déjà en place (Caddy, Traefik… : même principe, proxy vers `127.0.0.1:8085` avec les en-têtes `X-Forwarded-*` et une taille de requête suffisante). Puis `COOKIE_SECURE=true` dans `.env` et `docker compose up -d` (le site envoie alors aussi l'en-tête HSTS).

## Sécurité, en bref

- Mot de passe unique, stocké uniquement sous forme de hachage scrypt (N = 2^16, r = 8), vérifié en temps constant ; 5 échecs par IP en 15 minutes bloquent la connexion (réglable).
- Session dans un cookie signé (`itsdangerous`), `HttpOnly`, `SameSite=Lax`, limité au chemin `/admin`, `Secure` si `COOKIE_SECURE=true`, durée maximale `SESSION_MAX_AGE` ; les pages publiques ne déposent aucun cookie.
- Jeton CSRF sur tous les formulaires, y compris connexion et déconnexion.
- Fichiers : type vérifié sur le contenu (signature PNG/JPEG/WebP/GIF, SVG sans script pour le logo, APK = ZIP contenant `AndroidManifest.xml`), nom généré par le serveur, taille limitée avant même la lecture du formulaire (413).
- En-têtes : CSP stricte (aucun script en ligne), `X-Frame-Options`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, HSTS en HTTPS.
- Pas de mode debug, pas de documentation `/docs` exposée, conteneur sans privilèges (utilisateur 10001, `no-new-privileges`).

## Habiller les gabarits (maquette « Tilto Site »)

Les données suivent déjà les sections de la maquette (`maquette/Corrections et validation des maquettes/Tilto Site.dc.html`, planches 3a, 3b, 3c) : l'habillage ne touche que les gabarits publics, la feuille de style et d'éventuels scripts. Routes et base ne changent pas.

| Section de la maquette | Gabarit | Données |
|---|---|---|
| En-tête, navigation (Le jeu, Comment jouer, Captures, Télécharger) | `base.html` | ancres `#le-jeu`, `#comment-jouer`, `#captures`, `#telecharger` |
| Héros | `index.html` | `site.game_name` (affiché en majuscules), `site.tagline`, `site.play_store_url` (vide = bouton masqué), `apk` (`version`, `size_bytes\|filesize` ; `None` sans APK), `site.hero_note` (« Gratuit · Android ») |
| 4 arguments | `index.html` | `features` : `kicker` (INCLINE…), `title`, `body` |
| Comment jouer | `index.html` | `steps` : `title`, `body` (précision) |
| Captures | `index.html` | `screenshots` : `filename` (image servie par `/media/<filename>`, ou vide = emplacement réservé), `caption` (légende, aussi texte alternatif) |
| Bloc final | `index.html` (macro `download_buttons`, partagée avec le héros) | `site.download_title`, `site.download_text`, `apk` |
| Pied de page | `base.html` | `site.studio_logo_url` (vide si aucun logo), `site.studio_name`, `year`, `site.contact_email` (lien Contact masqué s'il est vide) |
| Politique de confidentialité (3c) | `privacy.html` | `site.privacy_updated\|date_fr`, `site.privacy_policy\|rich_text` (paragraphes, `<h2>`, listes) |

Autres fichiers : `error.html` (erreurs 404 et autres), `app/static/css/site.css` (les règles d'administration sont à la fin : les déplacer dans un `admin.css` si la nouvelle feuille remplace tout), polices dans `app/static/fonts/`. L'animation du terrain va dans un fichier de `app/static/js/` chargé par `<script src>` : la CSP interdit le JavaScript et les styles en ligne (`style="…"`) ainsi que toute ressource externe ; tout doit être servi par le site. Les éléments purement décoratifs de la maquette (classement d'exemple, curseur Douce / Vive, téléphones de Léa et Tom) relèvent du gabarit, pas de la base.
