# Pong Game

Un jeu de Pong mobile en Flutter, contrôlé en inclinant le téléphone. Il est écrit sans moteur de jeu : uniquement des widgets Flutter et une boucle de jeu maison.

## Fonctionnalités

- **Contrôle à l'accéléromètre** : inclinez le téléphone pour déplacer le paddle
- **Trois niveaux de difficulté** : Facile, Normal, Difficile
- **Rebond angulaire** : l'angle de la balle dépend du point d'impact sur le paddle
- **Vitesse progressive** : la balle accélère tous les 4 renvois
- **Classement** : top 10 des scores avec nom, date et podium
- **Statistiques** : parties jouées, temps total de jeu, meilleure série de renvois
- **Sons et vibrations** : effets sonores, musique d'ambiance, retour haptique
- **Pause** en cours de partie
- **Sauvegarde locale** : pseudo, meilleur score, classement et statistiques sont conservés sur l'appareil

## Règles

| Action | Points |
|---|---|
| Renvoyer la balle | 50 |
| L'adversaire rate la balle | 100 |

La partie se termine quand la balle passe derrière votre paddle.

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
| `lib/main.dart` | Démarrage, ouverture des boîtes Hive, écran de chargement |
| `lib/entername.dart` | Écran d'accueil : pseudo, choix de la difficulté |
| `lib/game/pong_engine.dart` | Moteur du jeu : balle, collisions, score, IA, sans dépendance à Flutter |
| `lib/hompage.dart` | Écran de jeu : affichage, accéléromètre, sons, pause, fin de partie |
| `lib/leaderboard.dart` | Page du classement |
| `lib/statistics.dart` | Page des statistiques |
| `lib/aide.dart` | Page d'aide |
| `lib/ball.dart`, `lib/bricks.dart`, `lib/coverscreen.dart` | Balle, paddles, message de démarrage |
| `lib/scoreplayer.dart`, `lib/topscore.dart` | Affichage des scores |
| `assets/sounds/` | Sons et musiques |

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
