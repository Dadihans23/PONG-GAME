# Site de présentation de Tilto

Petit site FastAPI (rendu serveur Jinja2, SQLite, fichiers sur disque) qui présente le jeu, propose l'APK en téléchargement et le lien Play Store, publie la politique de confidentialité et les mentions légales, reçoit les messages du formulaire de contact, et offre une administration protégée par mot de passe pour tout modifier sans toucher au code.

## Organisation

```
site/
├── app/
│   ├── main.py            création de l'application (uvicorn --factory app.main:create_app)
│   ├── config.py          variables d'environnement
│   ├── db.py              schéma SQLite, contenu initial, requêtes
│   ├── security.py        mot de passe scrypt, CSRF, limitation, taille des requêtes, en-têtes
│   ├── uploads.py         vérification et enregistrement des images et des APK
│   ├── render.py          gabarits et filtres (taille, date, date courte, texte enrichi)
│   ├── routes_public.py   /, /confidentialite, /mentions-legales, /contact, /telecharger, /media/…, /sante,
│   │                      /robots.txt, /sitemap.xml, /.well-known/security.txt
│   ├── seo.py             robots.txt, sitemap.xml, security.txt, titre et description de l'accueil, JSON-LD
│   ├── routes_admin.py    /admin/…
│   ├── routes_api.py      /api/app/studio, lu par l'app mobile (voir « API de l'app »)
│   ├── contact.py         formulaire de contact : jeton, délai, validation
│   ├── mailer.py          notification SMTP facultative des messages de contact
│   ├── reseed_v2.py       commande facultative : textes v1 → textes v2 (voir plus bas)
│   ├── reseed_studio.py   commande : section « Nom et logo du studio » dans la politique en base
│   ├── hashpw.py          génération du hachage du mot de passe et de la clé secrète
│   ├── templates/         gabarits HTML (publics, et admin/)
│   ├── seed/              logo initial du studio, copié dans les données au premier démarrage
│   └── static/            css/site.css (site), css/admin.css (administration), js/ (theme.js partagé, admin.js), fonts/ (Archivo, WOFF2), img/ (favicons, og-tilto.png)
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

Au premier démarrage, la base et le contenu initial sont créés automatiquement : textes de la maquette « Tilto Site v2 », corrigés (haut de page et fiche technique, 4 arguments avec leurs caractéristiques, comparatif Solo / Duel, 3 étapes, barème, 4 captures avec description, 6 questions fréquentes, étapes d'installation de l'APK, pied de page, politique de confidentialité avec la section « Formulaire de contact »), studio Nexora et son logo clair, hébergeur Contabo GmbH dans les mentions légales. Restent à saisir dans l'administration : le lien Play Store, les images des captures, l'APK (ses notes de version 1.0.0 sont proposées au premier dépôt) et les mentions légales (le tableau de bord signale « Mentions légales incomplètes » tant que les champs obligatoires sont vides).

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

La base et les fichiers sont dans le volume `tilto-data` : la reconstruction de l'image ne les touche pas. Le schéma est créé avec `CREATE TABLE IF NOT EXISTS`, les colonnes ajoutées par une version sont ajoutées aux bases existantes (`MIGRATIONS` dans `db.py`), et le contenu initial n'est inséré que s'il manque.

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

## Administration (maquette « Tilto Admin v2 »)

`maquette/Corrections et validation des maquettes/Tilto Admin v2.dc.html` (planche) et `TiltoAdmin2.dc.html` (composant). Gabarits `app/templates/admin/` (composants communs dans `_ui.html`), styles `app/static/css/admin.css` (feuille autonome : l'administration ne charge pas `site.css`), script `app/static/js/admin.js`.

- **Menu** : barre latérale de 240 px groupée dans l'ordre du site (`routes_admin.NAV`, titres et sous-titres des pages dans `PAGES`) ; sous 900 px, barre du haut « TILTO admin · studio » et bouton « Menu ». Thème Sombre / Clair en bas du menu, mémorisé comme sur le site (`theme.js`, clé `tilto-theme`) ; sans choix, le système décide.
- **Tableau de bord** : calculé depuis la base (`routes_admin.site_state`) : alerte rouge si des mentions légales obligatoires manquent, trois derniers messages, liste « À faire » (mentions, APK, notes de la version proposée, images des captures, adresse de contact ; le lien Play Store n'y figure pas tant que l'app n'est pas sur le Play Store), état de chaque section.
- **Textes de sections** : chaque page de section porte ses propres textes (sur-titre, titre…) ; Textes garde le haut de page, le bloc de téléchargement, les liens et le pied de page (`SETTING_GROUPS`). `POST /admin/textes` accepte toujours n'importe quel texte de `TEXT_FIELDS`.
- **Tableaux** (fiche technique, Solo / Duel, barème, installation) : un seul formulaire, `POST /admin/tableaux/<slug>`, qui enregistre l'en-tête et toutes les lignes (`row-<id>-<colonne>`, `new-<colonne>`), puis applique `action` (`add`, `up:<id>`, `down:<id>`, `delete:<id>`). Les anciennes routes par ligne existent toujours.
- **Listes** (arguments avec leurs caractéristiques, étapes, FAQ) : un élément se déplie (`<details>`) pour être modifié ; en-tête de section enregistré par `POST /admin/en-tete/<page>`.
- **Erreurs** : un envoi refusé n'enregistre rien ; la page est réaffichée avec les valeurs saisies, un bandeau en haut et le message sous le champ (`errors` : nom du champ → message).
- **Dernier enregistrement** : horodatage par page dans `setting` (clé interne `_saved:<page>`, jamais affichée ni modifiable comme texte), écrit en UTC et converti à l'heure locale par `admin.js`.
- **JavaScript** (amélioration progressive, tout marche sans lui) : compteurs « n / max » (le maximum vient de `maxlength`), boutons « Copier », boîte de confirmation `<dialog>` des suppressions (sans JS : envoi direct), barre de progression et « Annuler l'envoi » pour l'APK (XHR ; sans JS : envoi classique), onglets Modifier / Aperçu de la confidentialité sur mobile (l'aperçu est le texte enregistré, rendu par le serveur), menu mobile.
- Trois icônes seulement (monter, descendre, supprimer), en SVG dans les gabarits : rien n'est chargé hors du site, la CSP ne change pas.

### Étapes d'installation : titre + précision

Les étapes d'installation (`spec_row`, groupe `install`) ont deux colonnes : `label` = titre, `value` = précision. Au démarrage, une étape qui a encore exactement l'ancien texte par défaut d'une seule colonne est découpée (`db.INSTALL_SPLIT`, par exemple « Télécharge le fichier » / « Depuis ton téléphone Android. ») ; une étape modifiée par le propriétaire n'est pas touchée (sa précision reste vide, à remplir dans Administration › Installation). `python -m app.reseed_v2` propose aussi de remplacer les étapes par celles de la v2.

## Référencement (SEO)

- **Adresse fixe** : `SITE_URL` (`.env`, défaut `https://tilto.fun`, sans « / » final ni chemin, vérifié au démarrage). Toutes les URL absolues en partent (canonique, Open Graph, sitemap, robots.txt, security.txt, JSON-LD), jamais l'hôte de la requête.
- **`/robots.txt`** (`seo.robots_txt`) : politique « recherche oui, entraînement non ». Tout le monde peut tout lire sauf `/telecharger`, `/contact/merci`, `/sante` et `/api/` ; les robots d'entraînement des IA (GPTBot, ClaudeBot, Google-Extended, Applebot-Extended, CCBot, meta-externalagent, Bytespider) sont refusés partout ; les robots de recherche des assistants (OAI-SearchBot, ChatGPT-User, PerplexityBot, Claude-SearchBot…) suivent la règle générale. `/admin` n'y figure pas (le fichier est public) : ses pages portent `noindex`.
- **`/sitemap.xml`** : `/`, `/contact`, `/confidentialite`, `/mentions-legales`. `lastmod` : date de l'APK courant pour l'accueil (absente sans APK), `privacy_updated` et `legal_updated` (si remplie). Ni `priority` ni `changefreq`.
- **`/.well-known/security.txt`** (RFC 9116) : contact = page Contact, expire le 1er octobre 2027 (à prolonger avant).
- **Balises** (`base.html`) : une route passe `canonical_path` à `site_context` pour les pages indexables ; la page reçoit alors `<link rel="canonical">` (sans paramètres), Open Graph (`og:type`, `og:site_name`, `og:locale` fr_FR, `og:url`, `og:title`, `og:description`, `og:image` 1200 × 630 + `alt`) et `twitter:card` `summary_large_image`. Sans `canonical_path` (message envoyé, erreurs) : `<meta name="robots" content="noindex">`. Le bloc `description` d'un gabarit donne la meta description ; vide (404, message envoyé), il n'y en a pas.
- **Accueil** : titre et description dans `seo.HOME_TITLE_SUFFIX` / `seo.HOME_DESCRIPTION` (textes fixes, pas dans l'administration). Données structurées JSON-LD (`seo.home_json_ld`) : WebSite, Organization (studio, logo), MobileApplication (Android 5.0 ou plus, gratuit, version et lien de téléchargement seulement si un APK est en ligne, captures seulement celles qui ont une image) et FAQPage (texte exact de la FAQ). Jamais de note ni d'avis. Bloc `<script type="application/ld+json">` : données non exécutées, compatibles avec la CSP ; `tojson` échappe `<`, `>` et `&`.
- **Image de partage** : `app/static/img/og-tilto.png` (1200 × 630, ~70 Ko), générée par `node tool/og_image.cjs` (Playwright/Chromium, polices de `assets/fonts/`). Modifier le script puis relancer, jamais l'image à la main.
- **Polices** : Archivo en WOFF2, sous-ensemble latin + latin étendu (accents, œ, « », ’, …, ·, ×, flèches, €), ~28 Ko par graisse au lieu de ~190 Ko en TTF, partagées par `site.css` et `admin.css`. Seule la graisse 900 (titre de l'accueil) est préchargée. Régénérer avec `tool/site_fonts.py` (fonttools + brotli dans un venv à part, pas dans `requirements.txt`) ; les TTF source sont ceux de l'app (`assets/fonts/`). ↗, ʳ, ᵉ et l'espace fine insécable ne sont pas dans Archivo : le navigateur les prend dans une police de secours (comme avant).
- **Statiques versionnés** : dans les gabarits, `static_url('css/site.css')` donne `/static/css/site.css?v=<10 caractères du SHA-256>`, calculé une fois par démarrage. Les CSS et JS changent donc d'URL à chaque déploiement qui les modifie : un cache long (`Cache-Control: max-age=31536000, immutable`) peut être posé sur `/static/` dans Nginx. Les polices (appelées depuis les CSS) et les favicons ne sont pas versionnés : leur garder un cache plus court, ou changer leur nom si on les modifie.
- **Logo du pied de page** : `width`/`height` calculés d'après le fichier (hauteur 24 px, pas de décalage au chargement). Le logo initial (`app/seed/`, copié aux nouvelles installations) est réduit à 221 × 48 (~9 Ko) par `tool/site_seed_logo.py` ; un site déjà en ligne garde le logo déposé dans l'administration (à remplacer par une version réduite).
- Hors de l'application (Nginx, voir plus haut) : redirection de `www`, compression gzip, cache des statiques.

## Sécurité, en bref

- Mot de passe unique, stocké uniquement sous forme de hachage scrypt (N = 2^16, r = 8), vérifié en temps constant ; 5 échecs par IP en 15 minutes bloquent la connexion (réglable).
- Session dans un cookie signé (`itsdangerous`), `HttpOnly`, `SameSite=Lax`, limité au chemin `/admin`, `Secure` si `COOKIE_SECURE=true`, durée maximale `SESSION_MAX_AGE` ; les pages publiques ne déposent aucun cookie, sauf `/contact` (voir ci-dessous).
- Formulaire de contact : jeton anti-CSRF « double envoi » (cookie technique aléatoire `tilto_contact`, `HttpOnly`, `SameSite=Strict`, limité au chemin `/contact`, effacé à la fermeture du navigateur, plus un jeton signé avec `SECRET_KEY` dans le formulaire), champ piège invisible (`website`, un envoi qui le remplit est ignoré en silence), délai minimal `CONTACT_MIN_SECONDS` entre affichage et envoi, jeton valable 2 heures, limitation à `CONTACT_MAX_PER_HOUR` messages par IP et `CONTACT_GLOBAL_PER_HOUR` au total par heure (en mémoire), corps limité à 32 Ko, message à 2000 caractères, e-mail validé et sans retour à la ligne (pas d'injection d'en-têtes dans la notification). Aucun service externe ni captcha. Aucune adresse IP n'est enregistrée avec les messages.
- Jeton CSRF sur tous les formulaires, y compris connexion et déconnexion.
- Fichiers : type vérifié sur le contenu (signature PNG/JPEG/WebP/GIF, SVG sans script pour le logo, APK = ZIP contenant `AndroidManifest.xml`), nom généré par le serveur, taille limitée avant même la lecture du formulaire (413).
- En-têtes : CSP stricte (aucun script en ligne), `X-Frame-Options`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, HSTS en HTTPS.
- Pas de mode debug, pas de documentation `/docs` exposée, conteneur sans privilèges (utilisateur 10001, `no-new-privileges`).

## Formulaire de contact et notification par e-mail

`/contact` affiche le formulaire (nom facultatif, e-mail, sujet : Question, Problème technique, Suggestion, Autre, message de 2000 caractères au plus) ; un envoi réussi mène à `/contact/merci`. Les messages sont enregistrés en base et se lisent dans **Administration › Messages** (liste et lecture côte à côte sur ordinateur ; ouvrir un message le marque comme lu ; « Marquer comme non lu », « Supprimer », « Répondre » qui ouvre un `mailto:` avec l'adresse et le sujet « Re: … »). Le nombre de non-lus s'affiche à côté de « Messages » dans le menu, et les trois derniers messages sur le tableau de bord.

Notification facultative, variables de `.env` (voir `.env.example`) :

| Variable | Rôle |
|---|---|
| `SMTP_HOST` | serveur SMTP (vide = aucune notification) |
| `SMTP_PORT` | 587 (STARTTLS, défaut) ou 465 (SSL) |
| `SMTP_SECURITY` | facultatif : `starttls` ou `ssl` (déduit du port sinon) |
| `SMTP_USER`, `SMTP_PASSWORD` | identifiants (vide = pas d'authentification) |
| `SMTP_FROM` | expéditeur (adresse autorisée par le serveur SMTP) |
| `CONTACT_NOTIFY_TO` | destinataire de la notification |
| `CONTACT_MAX_PER_HOUR`, `CONTACT_GLOBAL_PER_HOUR`, `CONTACT_MIN_SECONDS` | limitations (3, 30, 3 par défaut) |

La notification part en tâche de fond après la réponse au visiteur ; son « Répondre » écrit directement au visiteur (`Reply-To`). Un échec (serveur injoignable, mauvais mot de passe) est écrit dans `docker compose logs` (`ERROR tilto.mailer: …`) et le message reste en base. Sans `SMTP_HOST`, `SMTP_FROM` et `CONTACT_NOTIFY_TO`, rien n'est envoyé.

## API de l'app : `GET /api/app/studio`

Seul appel de l'app mobile au site : au lancement, au plus une fois par jour, elle demande le nom, la présentation et le logo du studio (page « Le studio », depuis Réglages ou Aide), et garde la dernière réponse pour fonctionner sans Internet. Le contrat est fixé avec l'app : ne renommer ni retirer aucun champ (un changement incompatible passe par `schema: 2`).

```json
{
  "schema": 1,
  "studio": {"name": "Nexora", "about": "…", "website": "https://tilto.fun", "contact_url": "https://tilto.fun/contact"},
  "logo": {"url": "https://tilto.fun/media/<nom>.png", "sha256": "<64 hex>", "width": 221, "height": 48, "content_type": "image/png"},
  "updated_at": "2026-10-12T10:00:00+00:00"
}
```

- Données : réglages `studio_name`, `studio_about` (Administration › Studio, « Présentation du studio », 800 caractères, vide par défaut ; paragraphes séparés par une ligne vide) et `studio_logo`. `website` = `SITE_URL`, `contact_url` = `SITE_URL/contact` ; toutes les URL partent de `SITE_URL`, jamais de l'hôte de la requête.
- `logo` vaut `null` sans logo, si le fichier manque, ou si le logo est en SVG ou GIF (l'app n'affiche que PNG, JPEG, WebP ; l'administration le signale). `sha256`, `width` et `height` sont lus dans le fichier (empreinte gardée en mémoire tant que le fichier ne change pas).
- `updated_at` : dernier enregistrement de la page Studio (réglage interne `_saved:studio`) ; à défaut, date du fichier du logo ; à défaut, une date fixe. Jamais l'heure de l'appel.
- En-têtes : `Cache-Control: public, max-age=3600`, `ETag` (hachage du corps) avec réponse 304 sur `If-None-Match`, `X-Robots-Tag: noindex`, aucun cookie, pas de CORS. Lecture seule. Exclue de `robots.txt`, absente du sitemap.

La politique de confidentialité par défaut décrit cet appel (section « Nom et logo du studio », `db.PRIVACY_STUDIO_SECTION`, et phrase des autorisations). Une base existante garde sa politique : pour l'y ajouter, après une sauvegarde de la base :

```bash
docker compose exec tilto-site python -m app.reseed_studio            # affiche les changements, ne modifie rien
docker compose exec tilto-site python -m app.reseed_studio --apply    # demande « oui », puis applique
```

La commande ajoute la section si elle manque (avant « Ce que Tilto n'utilise pas », sinon avant « Ce site », sinon à la fin), remplace la phrase des autorisations seulement si elle est encore mot pour mot celle d'origine, et met `privacy_updated` à la date du jour. Rien d'autre n'est touché ; relancée, elle ne fait rien. Depuis le poste : `ssh -t hans@79.143.190.190 "cd ~/tilto-site && docker compose exec tilto-site python -m app.reseed_studio --apply"` (`-t` : la question « oui » a besoin d'un terminal).

## Mise à jour vers le site v2 : ce qui change en production

Au premier démarrage de la v2, sans rien effacer :

- nouvelles colonnes : `content_item.short_body` (texte court mobile des arguments), `screenshot.description`, `apk_release.release_notes` et `release_date` ;
- nouvelles tables : `spec_row` (fiche technique, comparatif, barème, étapes d'installation, caractéristiques des arguments), `faq`, `contact_message` ;
- nouveaux réglages (sur-titres, titres de sections, textes du pied de page, mentions légales…) avec leur texte initial ;
- contenus v2 insérés une seule fois (repère interne `_seed_v2`) : fiche technique, comparatif, barème, installation, 6 questions de FAQ, caractéristiques et texte court des 4 arguments existants (reconnus à leur sur-titre INCLINE, À DEUX, SENSIBILITÉ, RECORDS), notes de version de l'APK `1.0.0` s'il est déjà déposé et sans notes. Un tableau vidé ensuite dans l'administration n'est pas recréé.

Les textes **déjà en base ne sont pas écrasés**. Après le déploiement, la page affichera donc encore les textes v1 suivants, à mettre à jour :

1. **Textes › Accroche** : en v1 elle contient aussi « Seul contre l'ordinateur, ou à deux sur le même Wi-Fi. », qui fait maintenant doublon avec le nouveau texte de présentation. Texte v2 : « Le Pong qu'on joue en inclinant son téléphone. »
2. **Textes › Phrase du bloc de téléchargement** : v2 « Le Play Store installe les mises à jour tout seul. L'APK sert si tu n'as pas le Play Store ou si tu veux l'installer à la main. » (à ne changer qu'une fois l'app sur le Play Store).
3. **Arguments** : titres et textes v2 des 4 arguments (le texte court et les caractéristiques sont déjà ajoutés).
4. **Comment jouer** : précisions v2 des 3 étapes, titre de l'étape 2 « Tape l'écran pour lancer la balle. ».
5. **Captures** : légendes v2 (L'accueil, En solo, En duel, Fin du duel), descriptions, et une 4e capture « Fin du duel ». Vérifier que chaque image correspond à sa nouvelle légende.
6. **Confidentialité** : ajouter la section « Formulaire de contact » (texte dans `db.py`, `PRIVACY_CONTACT_SECTION`) et changer la date de mise à jour.
7. **Mentions légales** : éditeur (nom, forme juridique, adresse, e-mail, directeur de la publication) et adresse et téléphone de l'hébergeur Contabo GmbH, à vérifier sur le site de Contabo.
8. **APK** : relire les notes de version de la 1.0.0 (page APK) et, si besoin, la date de version.
9. Facultatif : variables SMTP dans `.env` sur le VPS, puis `docker compose up -d`.

Les points 1 à 6 peuvent aussi être faits en une fois, après une sauvegarde de la base :

```bash
docker compose exec tilto-site python -m app.reseed_v2            # liste les changements, ne modifie rien
docker compose exec tilto-site python -m app.reseed_v2 --apply    # demande « oui », puis applique
```

La commande remplace, position par position, les textes des arguments (et leurs caractéristiques), des étapes et des légendes et descriptions des captures par ceux de la v2 (images conservées, capture manquante ajoutée sans image), l'accroche et la phrase de téléchargement, et ajoute la section contact à la politique de confidentialité (date mise à aujourd'hui). Elle ne touche ni aux APK, ni aux images, ni à la FAQ, ni aux tableaux, ni aux mentions légales.

## Habiller les gabarits (maquette « Tilto Landing Neon », direction Néon magenta)

L'accueil suit la maquette `maquette/Corrections et validation des maquettes/Tilto Landing Neon.dc.html` (planche 6a, ordinateur 1440 px ; mobile, tablette et mode sombre conçus dans le même esprit). Surfaces « néon » sombres dans les deux thèmes (en-tête collant, héros, Face-à-face, téléchargement, pied de page) ; sections claires rosées (Le jeu, Comment jouer, Captures, FAQ) qui passent sur les fonds sombres du site en mode sombre. Les titres en deux graisses passent par le filtre `|accent` (`app/render.py`) : la fin en gras est ce qui suit la dernière virgule, sinon les trois derniers mots (phrase de six mots ou plus) ou le dernier mot. Les données suivaient à l'origine la maquette « Tilto Site v2 ». Les gabarits actuels affichent ces données avec un balisage minimal, sans habillage : l'habillage ne touche que les gabarits publics, `app/static/css/site.css` et `app/static/js/`. Routes et base ne changent pas. Toutes les valeurs sont échappées par Jinja ; `|rich_text` pour les textes longs à intertitres.

Variables communes à toutes les pages publiques (`routes_public.site_context`) :

| Variable | Contenu |
|---|---|
| `site` | tous les réglages (clés ci-dessous), plus `site.studio_logo_url` (vide sans logo) |
| `year` | année en cours |
| `apk` | APK courant ou `None` : `version`, `size_bytes` (`\|filesize`), `sha256` (empreinte complète), `uploaded_at`, `date` (date de version, ou de dépôt, AAAA-MM-JJ ; `\|date_short` → « 9 oct. 2026 », `\|date_fr` → « 9 octobre 2026 »), `notes` (liste des nouveautés, une par ligne saisie), `download_name` (ex. `Tilto-1.0.0.apk`) |
| `faq` | questions : `anchor`, `question`, `answer`, `short_answer` (mobile, peut être vide), `footer_label` |
| `footer_links` | liens du pied de page, seulement de vraies pages : `[{label, href, external}]` — Google Play et « Télécharger l'APK vx » s'ils existent, puis Contact, Politique de confidentialité, Mentions légales. Aucune ancre de l'accueil (la navigation du haut s'en charge) ; le champ `footer_label` des questions de la FAQ n'est plus utilisé ni proposé dans l'administration |

Page d'accueil (`index.html`) :

| Section de la maquette | Données |
|---|---|
| Barre de navigation (Le jeu, Solo ou Duel, Comment jouer, Captures, FAQ, Installer l'APK) | ancres `#le-jeu`, `#solo-duel` (section Face-à-face, qui contient le tableau), `#comment-jouer`, `#captures`, `#faq`, `#installer-apk`, `#telecharger`, `#nouveautes`, `#bareme` ; bande utilitaire : `site.hero_note`, `apk.version`, taille, `apk.date\|date_short`. La pastille de la section visible est allumée par `nav.js` (attribut `data-section`). Sélecteur de langue prêt dans `base.html` mais affiché seulement si une liste `languages` (`{code, label, href, current}`) est passée : vide aujourd'hui. |
| Haut de page | `site.hero_kicker`, `site.game_name`, `site.hero_badge` (pastille à côté du titre, vide = masquée), `site.tagline`, `site.hero_text` (ordinateur), `site.hero_text_short` (mobile), `site.play_store_url` (rempli = bouton Google Play rose ; vide = bouton « Google Play » non cliquable avec `site.play_soon_text`), `apk` (version, taille, « sans Play Store » est du gabarit) |
| Fiche technique (MODES, JOUEURS…) | `hero_specs` : `label`, `value` (la version mobile de la maquette n'en montre que 3 : au gabarit de choisir) |
| Démo | `site.hero_demo_text` (légende) ; le terrain rond animé est du gabarit ; bulle = première capture qui a une image (`screenshots`), sinon pas de bulle |
| Section « Ce qui change » | `site.features_kicker`, `site.features_title`, `site.features_intro` |
| 4 arguments (01 à 04) | `features` : `kicker`, `title`, `body`, `short_body` (mobile, peut être vide), `specs` (liste de `label`, `value`) ; le numéro est `loop.index` |
| Face-à-face (section `#solo-duel`) | `site.duel_kicker`, `site.duel_title`, `site.duel_title_accent` (2e ligne en dégradé ; titre et 2e ligne vides = scène masquée), `site.duel_left_label` / `duel_left_name` / `duel_left_score` / `duel_left_text`, idem `duel_right_*`, `site.duel_chip_1` à `duel_chip_3` (vides masquées). Les pseudos et scores servent aussi aux téléphones dessinés (scène et argument 02) : chaque téléphone montre son propriétaire en bas, en bleu, l'autre en haut, en vert, comme dans l'app |
| Solo ou Duel (dans Face-à-face) | `site.compare_kicker`, `site.compare_title`, `compare` : `label` (critère), `value` (Solo), `value2` (Duel) |
| Comment jouer | `site.steps_title`, `steps` : `title`, `body` |
| Barème en solo | `site.scoring_title`, `scoring` : `label`, `value` |
| Captures | `site.screens_title`, `site.screens_intro`, `site.screens_note`, `screenshots` : `filename` (`/media/<filename>`, vide = emplacement réservé), `caption`, `description` |
| Questions fréquentes | `site.faq_title`, `site.faq_subtitle`, `faq` (chaque question porte `id="{{ q.anchor }}"`, cible des liens du pied de page), `site.faq_text` + lien `/contact` |
| Télécharge Tilto | `site.download_title`, `site.download_text`, `apk` |
| Installer l'APK | `site.install_title`, `install_steps` (`label` = titre de l'étape, en gras ; `value` = précision, peut être vide), `site.install_note` (phrase Play Store), `apk.sha256` |
| Nouveautés | `site.notes_title`, `apk.version`, `apk.date`, `apk.notes` |
| Pied de page (`base.html`) | `site.footer_text`, `site.studio_logo_url`, `footer_links`, « Un jeu de `site.studio_name` · © `year` · `site.game_name` `apk.version` », `site.footer_note`, `site.footer_trademark` |

Autres pages :

| Page | Gabarit | Données |
|---|---|---|
| `/confidentialite` (3c) | `privacy.html` | `site.privacy_updated\|date_fr`, `site.privacy_policy\|rich_text` |
| `/mentions-legales` | `legal.html` | `legal_sections` : `[{title, rows: [{label, value}]}]` (Éditeur du site, Directeur de la publication, Hébergeur ; champs vides omis), `site.legal_extra\|rich_text`, `site.legal_updated`, ou directement `site.legal_publisher`, `legal_form`, `legal_registration`, `legal_address`, `legal_email`, `legal_phone`, `legal_director`, `legal_host_name`, `legal_host_address`, `legal_host_phone` |
| `/contact` | `contact.html` | `form` (`name`, `email`, `subject`, `message`, `errors` : liste de messages en français), `subjects`, `max_message`, `contact_token` (champ caché `csrf_token`, obligatoire), `honeypot` (nom du champ piège, à garder invisible avec la classe `contact-hp` définie à la fin de `site.css`), `site.contact_email` (adresse affichée si remplie) |
| `/contact/merci` | `contact_sent.html` | variables communes |
| Erreurs | `error.html` | `status`, `message` (sans `site` : le pied de page affiche des liens fixes) |

La CSP interdit le JavaScript et les styles en ligne (`style="…"`) ainsi que toute ressource externe : scripts dans `app/static/js/` chargés par `<script src>`, polices dans `app/static/fonts/` (WOFF2). Dans les gabarits, les CSS et JS passent par `static_url('…')` (URL versionnée). Les éléments purement décoratifs de la maquette (classement d'exemple, curseur Douce / Vive, écrans dessinés dans les téléphones, partie de démonstration, « VS ») relèvent du gabarit, pas de la base. Icônes : seulement des SVG en ligne fonctionnels (`_icons.html` pour la flèche de téléchargement ; soleil / lune, +/− de la FAQ, chevron de l'empreinte, flèche de Contact), aucune police d'icônes.

### Réglages ajoutés avec la maquette Néon magenta

Ajoutés à `DEFAULT_SETTINGS` : les bases existantes les reçoivent avec leur valeur par défaut au démarrage suivant, sans toucher aux autres textes.

| Clé | Valeur par défaut | Où dans l'administration |
|---|---|---|
| `hero_badge` | « 1 vs 1 » | Fiche technique › Haut de page |
| `play_soon_text` | « Bientôt disponible » | Textes › Liens |
| `duel_kicker` | « FACE-À-FACE · DUEL · PREMIER À 5 » | Solo / Duel › Face-à-face |
| `duel_title`, `duel_title_accent` | « Chacun son téléphone, » / « chacun sa raquette en bas. » | Solo / Duel › Face-à-face |
| `duel_left_label`, `duel_left_name`, `duel_left_score`, `duel_left_text` | « TÉLÉPHONE DE LÉA », « Léa », « 2 », « Léa se voit en bas, en bleu. Tom est en haut, en vert. » | Solo / Duel › Face-à-face |
| `duel_right_label`, `duel_right_name`, `duel_right_score`, `duel_right_text` | « TÉLÉPHONE DE TOM », « Tom », « 3 », « Sur son écran, c'est Tom qui est en bas, en bleu. Le premier à 5 gagne. » | Solo / Duel › Face-à-face |
| `duel_chip_1` à `duel_chip_3` | « Même Wi-Fi ou partage de connexion », « Les deux « Prêt », puis 3-2-1 », « Revanche en un bouton » | Solo / Duel › Face-à-face |

Les scores acceptent un chiffre de 0 à 5.

## Déploiement automatique (branche `prod`)

Chaque push sur la branche `prod` lance `.github/workflows/deploy-prod.yml` : analyse et tests de l'app Flutter, tests du site, puis copie de `site/` sur le VPS (rsync) et `docker compose up -d --build`. Le `.env` et le volume `tilto-data` restent sur le serveur et ne sont jamais écrasés. Un déploiement peut aussi être relancé à la main (onglet Actions › Déploiement prod › Run workflow).

### Mise en place (une seule fois)

1. **Sur ton PC**, crée une clé SSH dédiée au déploiement, sans mot de passe :
   ```bash
   ssh-keygen -t ed25519 -C "deploy-tilto" -f ~/.ssh/tilto_deploy -N ""
   ```
2. **Autorise cette clé sur le VPS** (demande ton mot de passe une dernière fois) :
   ```bash
   ssh-copy-id -i ~/.ssh/tilto_deploy.pub hans@79.143.190.190
   ```
   Sous Windows sans `ssh-copy-id` : `type $env:USERPROFILE\.ssh\tilto_deploy.pub | ssh hans@79.143.190.190 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"`
3. **Sur le VPS**, prépare le dossier et le `.env` (une seule fois) :
   ```bash
   mkdir -p ~/tilto-site && cd ~/tilto-site
   # copie .env.example depuis le dépôt, puis :
   cp .env.example .env && chmod 600 .env
   # choisis un HOST_PORT libre (vérifie avec : ss -ltnp | grep :8085)
   ```
   Les valeurs `SECRET_KEY` et `ADMIN_PASSWORD_HASH` se génèrent après le premier déploiement avec
   `docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret` puis sans `--secret`.
   L'utilisateur `hans` doit pouvoir lancer `docker` sans `sudo` (groupe `docker`).
4. **Sur GitHub** (dépôt › Settings › Secrets and variables › Actions) :
   - Secrets : `DEPLOY_HOST` = `79.143.190.190`, `DEPLOY_USER` = `hans`,
     `DEPLOY_SSH_KEY` = contenu de `~/.ssh/tilto_deploy` (la clé **privée**),
     `DEPLOY_KNOWN_HOSTS` = sortie de `ssh-keyscan 79.143.190.190`.
   - Variable : `DEPLOY_PATH` = `/home/hans/tilto-site`.
   - Optionnel : Settings › Environments › `prod` › « Required reviewers » pour valider chaque déploiement à la main.
5. **Crée la branche `prod`** et pousse : `git push origin main:prod`.
