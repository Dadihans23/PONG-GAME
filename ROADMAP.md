# Roadmap — Pong Game

Checklist de suivi du projet. Chaque tâche est cochée dès qu'elle est terminée et vérifiée.

Légende : `[ ]` à faire · `[~]` en cours · `[x]` terminé

Ordre de travail : la phase 1 (solo et corrections) est terminée avant de commencer la phase 2 (multijoueur local). La phase 3 (en ligne) n'est pas planifiée en détail.

Décisions déjà prises :
- Le jeu reste en **vertical** : raquettes en haut et en bas, coordonnées -1 → 1.
- Duel : le premier à **5 points** gagne.
- Duel : chaque joueur appuie sur **Prêt** avant le démarrage.
- Tous les textes restent en **français**.
- **Pas de pause** en duel pour le MVP.

---

## Phase 1 — Mode solo et corrections

### 1.1 Corrections de bugs

Code terminé et relu ; validation sur téléphone prévue avec le test de fin de phase 1.3.

- [x] **Son d'accueil manquant** : l'appel à `welcome.mp3` (fichier absent) est retiré
- [x] **Halo permanent sur la balle** : le halo ne s'affiche plus qu'avant le démarrage
- [x] **Raquette qui bouge hors partie** : accéléromètre ignoré avant le démarrage, en pause et après la défaite
- [x] **Pseudo non modifiable** : lien « Modifier » à côté de « Bonjour <pseudo> »
- [x] **Musique d'accueil** : elle reprend au retour du jeu
- [x] **Meilleur score de l'accueil** : rafraîchi au retour d'une partie
- [x] **Fuites audio** : lecteurs `letsgo` et `shoot` libérés dans `dispose()`
- [x] **`setState` après fermeture de l'écran** : minuteur du halo de score protégé par `mounted`
- [x] **Fin de partie** : `resetgame()` appelé une seule fois, `onPopInvoked` déprécié retiré
- [x] **Orientation** : app verrouillée en portrait
- [x] **Score nul au classement** : une partie à 0 point n'est plus enregistrée
- [x] **Plantage audio** (`IllegalStateException` dans `MediaPlayer.getPlaybackParams`, vu une fois en release) : tous les sons passent par `GameSound` (`lib/game_sound.dart`), qui charge chaque son une fois et envoie les commandes une par une. Disparition du plantage confirmée par le propriétaire
- [x] **Erreur du capteur au démarrage** (`MissingPluginException … setAccelerationSamplingPeriod`) : `sensors_plus` passé en 4.0.2. À confirmer dans les journaux du téléphone

### 1.2 Nettoyage

- [x] Supprimer `_losePlayer`, `_counter` et le code commenté (`ball.dart`, `brouillon.dart` supprimé)
- [x] Corriger les avertissements de `flutter analyze` : 129 remarques dont 22 avertissements au départ, 0 avertissement et 18 infos à la fin (noms de classes et `withOpacity`, laissés volontairement)
- [x] Remplacer le test par défaut `widget_test.dart` par les tests du moteur
- [x] Pseudo : refuser un pseudo fait d'espaces (`trim`)
- [x] Accueil : empêcher le double tap sur « S U I V A N T » d'ouvrir deux parties
- [x] Accueil : protéger par `mounted` le `setState` de la secousse du champ
- [x] Fins de ligne : `.gitattributes` ajouté
- Sons inutilisés (`winter`, `chiptune`, `reprendre`, `win1`, `lose1`, `lose2`, `lose3`) : conservés pour l'instant, à utiliser ou supprimer en 1.4

### 1.3 Moteur de jeu séparé de l'écran

Nécessaire pour tester le jeu et pour le multijoueur. Le comportement du solo ne doit pas changer.

- [x] Extraire la logique dans `lib/game/pong_engine.dart`
- [x] Brancher `hompage.dart` sur le moteur
- [x] Boucle de jeu à pas fixe (`stepsPerSecond` pas de moteur par seconde), un seul rafraîchissement par image. Les constantes de vitesse n'ont pas changé
- [x] Tests unitaires du moteur : 30 tests (rebonds, score, accélération, défaite, IA)
- [x] Test du solo sur un vrai téléphone par le propriétaire : validé
  - [x] Vitesse du jeu : réglée au ressenti avec le propriétaire, 450 pas par seconde (l'ancien code en faisait environ 700 en release sur SM-A135F, jugé trop rapide ; 500 jugé presque bon)

### 1.3 bis Contrôle de la raquette indépendant du téléphone

À faire après l'approbation du test solo de la 1.3 et avant la phase 2 (le duel exige la même raquette sur deux téléphones). Aujourd'hui la raquette avance à chaque événement du capteur, donc sa vitesse dépend de la cadence du capteur de chaque téléphone.

- [x] Mesurer sur le SM-A135F la cadence réelle de l'accéléromètre : **6 événements par seconde**. La raquette avance donc par 6 sauts par seconde, à 1,18 × sin(inclinaison) unité/s (0,59 unité/s à 30°, 1,18 au maximum)
- [x] `sensors_plus` mis à jour en 4.0.2 pour lire le capteur à 50 Hz ; la compilation Android en release passe sans toucher aux outils de compilation
- [x] Le capteur mémorise l'inclinaison (`lib/game/tilt_control.dart`), le moteur déplace la raquette à chaque pas (`playerSpeed`), avec tests (59 tests au total)
- [x] Inclinaison normalisée, lissage de 50 ms, zone morte progressive d'environ 3°, vitesse maximale
- [x] Première version réglée sur la vitesse actuelle de la raquette (1,18 unité/s au maximum)
- [x] Testé par le propriétaire : vitesse de la raquette augmentée de 20 % (`paddleMaxSpeed` 1,18 → 1,42)

### 1.5 Redesign du mode solo

Maquettes : `maquette/Redesign app PONG mobile/` (système de design, écrans solo, multijoueur, parcours).

- [x] Système de design partagé (`lib/ui/`) : palette, police Archivo intégrée, composants
- [x] Chargement, accueil, classement, statistiques, aide, conformes aux maquettes (vérifiés sur téléphone)
- [x] Écran de jeu, pause, fin de partie, conformes aux maquettes (vérifiés sur téléphone)
- [x] Écran Réglages : musique, effets sonores, vibration, sensibilité de la raquette (5 crans), pseudo
- [x] Version finale installée sur le téléphone, écran Réglages vérifié sur l'appareil
- [x] Test du mode solo redessiné par le propriétaire : validé

### 1.4 Améliorations du solo

- [ ] Musique de fond pendant la partie
- [ ] Effets visuels à l'impact raquette/balle
- [ ] Traînée derrière la balle
- [ ] Niveaux progressifs avec effets visuels par palier
- [ ] Power-ups (raquette plus large, balle ralentie…)
- [ ] Mode multi-balle

---

## Phase 2 — Multijoueur local

Référence : `pong_multiplayer_spec.md`. Deux téléphones sur le même Wi-Fi ou hotspot, sans Internet. Le téléphone qui crée la partie (Host) fait autorité.

### 2.1 Modèles et règles du duel

- [x] Modèles `GameState`, `Player`, `GameRoom` (`lib/multiplayer/model/`), JSON validant
- [x] États de partie : attente, joueur connecté, prêt, compte à rebours, en jeu, terminé, déconnecté
- [x] Moteur du duel (`lib/game/duel_engine.dart`), physique commune avec le solo (`pong_physics.dart`) ; raquette du joueur 2 pilotée en position, vitesse plafonnée
- [x] Largeur de raquette indépendante de la taille de l'écran (demi-largeur de contact 0,37)
- [x] Victoire à 5 points, remise en jeu vers le perdant après 2 s, accélération tous les 8 renvois (4 par joueur)
- [x] Tests unitaires du mode duel, des modèles et de la vue inversée

### 2.2 Couche réseau

Isolée du moteur, pour pouvoir la remplacer plus tard par un serveur en ligne.

- [x] Interface de transport commune (`lib/net/transport.dart`), WebSocket et mémoire
- [x] Protocole JSON versionné (`lib/net/PROTOCOL.md`), décodage défensif, battement de cœur
- [x] Serveur WebSocket côté Host (`dart:io`), refus d'un 3ᵉ joueur
- [x] Client WebSocket côté joueur 2
- [x] Permissions Android dans le manifeste principal (le release n'avait pas `INTERNET`) et verrou multicast
- [ ] Test de connexion entre deux téléphones

### 2.3 Découverte des parties

- [x] Annonce de la partie par broadcast UDP côté Host, sur chaque interface, plus réponse aux sondes
- [x] Écoute et liste des parties côté Client
- [x] Retrait d'une partie qui n'est plus annoncée
- [ ] Test sur Wi-Fi classique et sur hotspot

- [ ] Saisie manuelle de l'adresse du Host en secours (plus tard)

### 2.4 Écrans et parcours

- [x] Carte « Multijoueur » active sur l'accueil, avec victoires / défaites
- [x] Écrans de présentation d'après la maquette : menu (M1), recherche (J1-J3), salon et compte à rebours (L1-L4), duel (D1-D2), fin (V1-V2), incidents (X1-X3)
- [x] Sections Multijoueur des statistiques et de l'aide
- [x] Contrôleur de session (`lib/multiplayer/controller/`) qui vit plus longtemps que les écrans
- [~] Branchement des écrans sur le contrôleur, sons, vibrations, bouton retour

### 2.5 Synchronisation

- [x] Le Host fait tourner le moteur et envoie l'état 30 fois par seconde
- [x] Le Client envoie la position de sa raquette 30 fois par seconde, affichée en local sans attendre le réseau
- [x] Interpolation légère chez le Client (33 ms)
- [x] Vue inversée chez le Client : chacun voit sa raquette en bas
- [x] Compte à rebours 3-2-1 synchronisé
- [x] Même score, même gagnant, même durée sur les deux téléphones (vérifié en simulation)
- [x] Rejouer sans recréer la partie
- [~] Sons et vibrations (branchement en cours)

### 2.6 Déconnexions

- [x] Le joueur 2 quitte : le Host retourne au salon (vérifié en simulation)
- [x] Le Host quitte : le Client voit « Partie terminée » et retourne au menu (vérifié en simulation)
- [x] Perte de Wi-Fi ou app mise en arrière-plan (vérifié en simulation)

### 2.7 Validation du MVP

- [ ] Les 15 critères de la section 25 de la spec passent sur deux téléphones Android
- [ ] Le mode solo fonctionne toujours

### 2.8 Optimisation (après le MVP)

- [ ] Interpolation de la balle chez le Client
- [ ] Réduction de la taille et de la fréquence des messages
- [ ] Correction des désynchronisations

---

## Phase 3 — Multijoueur en ligne (plus tard)

- [ ] À planifier une fois la phase 2 stabilisée : serveur FastAPI/WebSocket, salons en ligne, matchmaking, authentification

---

## Nouveaux écrans

| Écran | Phase | Rôle |
|---|---|---|
| Menu multijoueur | 2.4 | Choisir entre « Créer une partie » et « Rejoindre une partie » |
| Liste des parties | 2.4 | Parties trouvées sur le réseau, boutons Rejoindre et Actualiser |
| Salon | 2.4 | Attente du second joueur, statut Prêt de chacun, Annuler |
| Jeu duel | 2.4 | Partie à deux : scores des deux joueurs, sans pause |

Ajouts sur des écrans existants, sans nouvel écran :
- Accueil : bouton « Multijoueur » et bouton « Modifier » le pseudo
- Dialogues : fin de partie en duel, déconnexion
