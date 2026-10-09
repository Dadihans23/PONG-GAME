# Tilto — nouvel écran d'accueil, icône de l'app et site de présentation

## Ce que je te demande

Tu as déjà dessiné le redesign de ce jeu (planches « Système de design », « Écrans solo », « Multijoueur », « Parcours »). Le jeu s'appelle maintenant **Tilto**, un jeu du studio **Nexora**. Tous les écrans me conviennent, **sauf l'écran d'accueil**, que je trouve trop générique : il ressemble à une application de gestion (cartes empilées, icônes dans des carrés arrondis, coches, tout au même poids), il « fait IA » et ne donne pas envie de jouer.

Je te demande trois choses :
1. **2 ou 3 directions différentes pour l'écran d'accueil seul**, toutes simples.
2. **2 ou 3 propositions d'icône pour l'app Tilto**.
3. **La maquette du site de présentation de Tilto**, avec les mêmes exigences que l'app (voir la section dédiée plus bas).

## La règle qui vaut pour tout : rien de générique

Je ne veux pas d'un rendu qui ressemble à un modèle ou à une interface générée :
- **pas d'icônes partout** : une icône seulement quand elle aide vraiment à comprendre, jamais en décoration à côté de chaque titre ou de chaque ligne ;
- **pas de grilles de cartes identiques** (le classique « trois cartes avec une icône, un titre et deux lignes ») ;
- **pas de pastilles, badges et coches en décoration** ;
- **pas de dégradés violets, de blobs flous, de mots-clés vides** (« révolutionnaire », « une expérience unique ») ;
- à la place : une hiérarchie forte, de la place, la typographie et le jeu lui-même comme éléments visuels principaux, et des textes concrets qui disent ce qu'on fait.

## Le jeu en bref

- Pong **vertical**, en **portrait** : ta raquette en bas (bleue), l'adversaire en haut (verte), balle blanche.
- On déplace sa raquette en **inclinant le téléphone**. D'où le nom : *tilt* = incliner.
- Deux modes : **Solo** contre l'ordinateur (Facile / Normal / Difficile) et **Duel** à deux, chacun sur son téléphone, sur le même Wi-Fi, sans Internet. Le duel se joue en 5 points.
- Textes en **français**, tutoiement.
- Android, téléphones d'entrée de gamme compris : concevoir pour **360 × 800**, et vérifier que ça tient en **320 dp** de large.

## Ce que doit contenir l'accueil (fonctions inchangées)

- Le nom du jeu : **TILTO**.
- Le pseudo du joueur : « Bonjour, Léa » avec possibilité de le modifier ; au tout premier lancement, un champ pour saisir son pseudo (message d'erreur si vide).
- Le choix du mode : **Solo** ou **Duel**.
- En Solo : le choix de la difficulté et le meilleur score.
- En Duel : le bilan victoires / défaites (à partir du premier duel joué).
- Le bouton principal **JOUER**.
- Les accès secondaires : Classement, Statistiques, Aide, Réglages.

## Direction souhaitée

- **Simple.** Peu d'éléments, de la place, une hiérarchie évidente : le jeu, puis JOUER, puis le reste.
- **Pas de cartes empilées**, pas de liste d'options façon formulaire.
- **Le jeu en vedette.** Mon idée de départ, à explorer dans au moins une direction : comme les bornes d'arcade, un **vrai terrain de Tilto qui joue tout seul en fond** (deux raquettes qui s'échangent la balle), avec par-dessus le titre, le choix du mode et JOUER. Les autres directions peuvent proposer autre chose, tant que c'est simple et que ça respire le jeu.
- Le choix Solo / Duel et la difficulté doivent ressembler à des **commandes de jeu** (gros boutons, sélecteur), pas à des réglages d'application.
- Classement, Statistiques, Aide et Réglages sont **discrets** (petites icônes, barre basse ou haute…).

## Contraintes (garder l'identité existante)

- Reprends le **système de design v2** existant : fond `#0B0B10`, surfaces `#15151C` / `#1E1E28`, rose néon `#E91E63` réservé à l'action principale (JOUER), bleu `#2196F3` = toi, vert `#4CAF50` = l'adversaire, police **Archivo**, titres en majuscules espacées, halos mesurés (simples ombres, pas de flou d'arrière-plan).
- Développable en **Flutter** avec des widgets standards : formes simples, dégradés et halos légers, pas de 3D ni d'illustration complexe. Le terrain animé en fond doit rester léger pour un téléphone d'entrée de gamme.
- Zones tactiles d'au moins 48 px ; JOUER à portée de pouce.
- Rien d'animé ne doit gêner la lecture des textes.

Pour chaque direction, montre l'accueil dans **trois états** :
1. premier lancement (champ pseudo vide, avec l'erreur) ;
2. pseudo enregistré, Solo sélectionné ;
3. Duel sélectionné.

Et explique en une phrase l'idée de chaque direction.

## Icône de l'app Tilto

- C'est la première chose que les joueurs verront sur leur téléphone et sur le Play Store.
- Elle doit évoquer **Tilto** : l'inclinaison, une raquette, une balle, le rebond. Pas le logo du studio.
- Lisible en très petit (48 px) comme en grand (512 px pour le Play Store).
- Format **icône adaptative Android** : un premier plan simple centré dans la zone sûre (environ 66 % du carré) sur un fond uni ou un dégradé simple, pour qu'elle reste correcte quelle que soit la forme de masque du téléphone (cercle, carré arrondi, goutte).
- Dans les couleurs du jeu : fond sombre, rose néon et/ou bleu, balle blanche.
- Montre chaque proposition en grand, en petit, et dans les masques rond et carré arrondi.

## Le studio Nexora (pour information)

Le jeu affiche une courte intro « Nexora » au lancement et « Un jeu de Nexora » discrètement dans les Réglages et l'Aide. **Le logo Nexora n'apparaît pas sur l'écran d'accueil ni dans l'icône.** Couleurs du studio : noir et blanc. Le logo Nexora est un symbole « N » en dégradé bleu-violet suivi du mot « Nexora » ; il en existe une version texte blanc pour les fonds sombres.

## Site de présentation de Tilto

Une **seule page**, qui présente le jeu et permet de le télécharger. Mêmes règles que l'app : **rien de générique, pas d'icônes à tout va**, même identité visuelle (fond sombre `#0B0B10`, rose néon pour l'action principale, bleu = toi, vert = l'adversaire, Archivo, titres espacés).

Public : des joueurs qui arrivent par un lien partagé par un ami, ou depuis la fiche du Play Store. En quelques secondes, ils doivent comprendre ce qu'est Tilto et pouvoir le télécharger.

Contenu attendu (ordre et forme libres) :
- **Le jeu en action dès l'arrivée** : un téléphone qui montre une partie, ou le terrain lui-même qui occupe l'écran, avec le nom TILTO et une phrase qui dit ce que c'est (un Pong qu'on joue en inclinant son téléphone, seul ou à deux).
- **Télécharger** : bouton Play Store et bouton « Télécharger l'APK » (avec la version et la taille), l'un des deux en action principale.
- **Ce qui le rend différent**, en peu de mots : contrôle par inclinaison, duel à deux sur le même Wi-Fi sans Internet, sensibilité réglable, classement et statistiques. Trouve une forme qui ne soit pas une grille de cartes à icônes : par exemple des captures d'écran légendées, ou une démonstration visuelle de chaque idée.
- **Comment jouer**, en trois temps.
- **Des captures d'écran** de l'app (utilise les écrans des maquettes existantes).
- **Pied de page** : « Un jeu de Nexora » avec le logo, lien vers la politique de confidentialité, contact.
- **Page « Politique de confidentialité »** : une page de texte simple et lisible dans le même style (le jeu ne collecte aucune donnée personnelle ; tout est stocké sur le téléphone).

Contraintes techniques : le site sera codé en **HTML et CSS simples** (rendu côté serveur, un peu de JavaScript), donc pas d'effet qui exige un framework lourd ; il doit être léger et rapide sur mobile. Montre la page **sur mobile (360 px) et sur ordinateur (1440 px)**.

## Livrables

1. Une planche avec les 2 ou 3 directions d'accueil, chacune dans ses trois états, avec une phrase d'explication.
2. Une planche avec les 2 ou 3 propositions d'icône, en grand, en petit et dans les masques.
3. Une planche avec le site de présentation, sur mobile et sur ordinateur, plus la page Politique de confidentialité.
4. Ta recommandation : quelle direction et quelle icône tu choisirais, et pourquoi. Le site doit être cohérent avec la direction d'accueil que tu recommandes.
