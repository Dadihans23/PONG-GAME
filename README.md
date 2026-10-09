# Tilto

**Tilto**, un jeu de **Nexora** : un jeu de raquette et de balle mobile en Flutter, contrôlé en inclinant le téléphone. Il est écrit sans moteur de jeu : uniquement des widgets Flutter et une boucle de jeu maison.

## Fonctionnalités

- **Contrôle à l'accéléromètre** : inclinez le téléphone pour déplacer le paddle
- **Trois niveaux de difficulté** : Facile, Normal, Difficile
- **Rebond angulaire** : l'angle de la balle dépend du point d'impact sur le paddle
- **Vitesse progressive** : la balle accélère tous les 4 renvois
- **Classement** : top 10 des scores avec nom, date et podium
- **Statistiques** : parties jouées, temps total de jeu, meilleure série de renvois
- **Sons et vibrations** : effets sonores, musique d'ambiance, retour haptique
- **Pause** en cours de partie
- **Duel à deux** sur le même Wi-Fi : un téléphone crée la partie, l'autre la trouve et la rejoint, premier à 5 points, revanche en un geste
- **Sauvegarde locale** : pseudo, meilleur score, classement et statistiques sont conservés sur l'appareil

## Règles

| Action | Points |
|---|---|
| Renvoyer la balle | 50 |
| L'adversaire rate la balle | 100 |

La partie se termine quand la balle passe derrière votre paddle.

## Multijoueur local

Deux téléphones sur le même Wi-Fi, ou l'un connecté au partage de connexion de l'autre ; Internet n'est pas nécessaire.

1. À l'accueil, choisir **Multijoueur** puis **Jouer**.
2. Un joueur touche **Créer une partie** : son salon s'ouvre et la partie est annoncée sur le réseau local.
3. L'autre touche **Rejoindre une partie**, puis **Rejoindre** sur la partie trouvée.
4. Chacun touche **Prêt** : compte à rebours 3-2-1, puis duel. Chaque joueur voit sa raquette en bas.
5. Premier à 5 points. **Rejouer** relance un duel quand les deux l'ont demandé.

Il n'y a pas de pause en duel : si l'app passe en arrière-plan, la partie est fermée et l'autre joueur est prévenu. Les victoires et défaites sont comptées sur la carte Multijoueur de l'accueil.

Côté technique, le téléphone qui crée la partie fait tourner le moteur et envoie l'état 30 fois par seconde par WebSocket (port 47800) ; les parties sont découvertes par broadcast UDP (port 47801). Le protocole est décrit dans `lib/net/PROTOCOL.md`.

## Marque

Le nom du jeu (Tilto), le nom du studio (Nexora) et les chemins des logos sont regroupés dans `lib/brand.dart` ; le code ne les écrit nulle part ailleurs. Au lancement, l'intro du studio (logo blanc sur noir, 1,5 s, un toucher la passe) précède l'écran de chargement (4,5 s) : 6 s au total.

Pour changer de studio : modifier `Brand.studioName` dans `lib/brand.dart` et remplacer les images de `assets/brand/` (logo à texte blanc pour fond sombre, logo d'origine pour fond clair, symbole seul). `tool/brand_logos.py` (Python + Pillow) produit ces trois images à partir de `assets/nexora.png` ; ses seuils sont propres à ce logo. Le nom sous l'icône est dans `android/app/src/main/AndroidManifest.xml` (`android:label`) et `ios/Runner/Info.plist`. Le paquet Dart et l'identifiant de l'app restent `pong_game` / `com.example.pong_game` jusqu'à la publication.

## Lancer le projet

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) avec un SDK Dart 3.3 ou plus récent, et un appareil physique. L'accéléromètre n'est pas disponible sur la plupart des émulateurs, le paddle n'y bougera donc pas.

```bash
flutter pub get
flutter run
```

Pour générer un APK :

```bash
flutter build apk
```

## Structure du code

| Fichier | Rôle |
|---|---|
| `lib/brand.dart` | Nom du jeu, nom du studio, logos : le seul fichier à changer pour la marque |
| `lib/main.dart` | Démarrage, ouverture des boîtes Hive, écran de chargement |
| `lib/studio_intro.dart` | Intro du studio avant le chargement |
| `lib/entername.dart` | Écran d'accueil : pseudo, mode (solo ou multijoueur), difficulté |
| `lib/game/pong_engine.dart` | Moteur du jeu solo : balle, collisions, score, IA, sans dépendance à Flutter |
| `lib/game/duel_engine.dart` | Moteur du duel, sur le téléphone qui a créé la partie |
| `lib/game/game_tuning.dart` | Rythme du jeu et réglages de la raquette, communs au solo et au duel |
| `lib/hompage.dart` | Écran de jeu solo : affichage, accéléromètre, sons, pause, fin de partie |
| `lib/game_ui/` | Terrain, bandeau, pause et carte de fin du solo |
| `lib/net/` | Réseau local : sessions WebSocket, découverte UDP, protocole |
| `lib/multiplayer/controller/` | Contrôleur du duel : parcours, synchronisation, revanche, incidents |
| `lib/multiplayer/screens/`, `lib/multiplayer/widgets/` | Écrans du multijoueur (menu, recherche, salon, duel, fin, incidents) |
| `lib/multiplayer/multiplayer_flow.dart` | Parcours multijoueur : relie le contrôleur aux écrans, boucle du duel, sons |
| `lib/leaderboard.dart` | Page du classement |
| `lib/statistics.dart` | Page des statistiques |
| `lib/aide.dart` | Page d'aide |
| `lib/settings/` | Réglages : musique, effets, vibration, sensibilité de la raquette |
| `lib/ui/` | Système de design : couleurs, textes, boutons, cartes |
| `assets/sounds/` | Sons et musiques |
| `assets/brand/` | Logos du studio (fond sombre, fond clair, symbole seul) |

## Dépendances principales

- [`sensors_plus`](https://pub.dev/packages/sensors_plus) : accéléromètre
- [`hive_flutter`](https://pub.dev/packages/hive_flutter) : stockage local
- [`audioplayers`](https://pub.dev/packages/audioplayers) : sons
- [`avatar_glow`](https://pub.dev/packages/avatar_glow) : effet lumineux autour de la balle

## Pistes d'amélioration

- Niveaux progressifs avec effets visuels
- Power-ups (paddle plus large, balle ralentie…)
- Mode multi-balle
- Musique de fond pendant la partie
- Effets visuels à l'impact et traînée de balle
