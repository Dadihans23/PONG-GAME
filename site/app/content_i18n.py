"""Traductions anglaises et espagnoles des textes de la base (réglages, arguments,
étapes, tableaux, FAQ, captures, notes de version, politique de confidentialité).

Chaque entrée part d'un texte français EXACT : celui du contenu initial (db.py) ou
celui que le propriétaire a saisi sur le site en ligne (relevé sur tilto.fun le
2026-10-12). Un texte français qui n'est pas dans cette liste n'est jamais
traduit automatiquement : la page anglaise ou espagnole affiche le français
(repli) jusqu'à ce qu'une traduction soit saisie dans l'administration.

Servi à :
- db.init_db, au premier démarrage (base neuve) ;
- python -m app.reseed_i18n, pour une base existante (ajoute seulement les
  traductions qui manquent, ne touche jamais au français) ;
- python -m app.relecture, qui produit RELECTURE.md et relecture.csv.

Vocabulaire : celui de l'app (lib/l10n/GLOSSAIRE.md). Anglais américain ;
espagnol neutre au tutoiement « tú ».
"""

from __future__ import annotations

import re

# (où, français, anglais, espagnol, remarque pour les relecteurs)
ENTRIES: list[tuple[str, str, str, str, str]] = [
    # --- Haut de page ---------------------------------------------------------------
    ("hero_kicker", "PONG VERTICAL · ANDROID · SOLO ET DUEL LOCAL",
     "VERTICAL PONG · ANDROID · SOLO AND LOCAL DUEL",
     "PONG VERTICAL · ANDROID · SOLO Y DUELO LOCAL", "Texte initial."),
    ("hero_kicker", "JEU DE PONG GRATUIT · ANDROID · SOLO ET DUEL LOCAL",
     "FREE PONG GAME · ANDROID · SOLO AND LOCAL DUEL",
     "JUEGO DE PONG GRATIS · ANDROID · SOLO Y DUELO LOCAL", "Texte en ligne."),
    ("tagline", "Le Pong qu'on joue en inclinant son téléphone.",
     "The Pong you play by tilting your phone.",
     "El Pong que se juega inclinando el teléfono.",
     "Les trois derniers mots s'affichent en gras."),
    ("hero_text",
     "Ta raquette est en bas, celle de l'adversaire en haut. Pas de bouton à l'écran : tu "
     "tiens le téléphone à deux mains et tu le penches à gauche ou à droite. Joue seul contre "
     "l'ordinateur sur trois niveaux, ou défie un ami en duel. Chacun joue sur son téléphone, "
     "sur le même Wi-Fi, sans Internet.",
     "Your paddle is at the bottom, your opponent's at the top. There are no buttons on the "
     "screen: you hold the phone with both hands and tilt it left or right. Play alone against "
     "the computer on three levels, or challenge a friend to a duel. Each of you plays on your "
     "own phone, on the same Wi-Fi, with no internet.",
     "Tu paleta está abajo y la del rival, arriba. No hay botones en la pantalla: sostienes el "
     "teléfono con las dos manos y lo inclinas a la izquierda o a la derecha. Juega en "
     "solitario contra la máquina en tres niveles, o reta a un amigo a un duelo. Cada uno juega "
     "en su teléfono, en el mismo Wi-Fi, sin internet.", ""),
    ("hero_text_short",
     "Pas de bouton : tu penches le téléphone et ta raquette suit. Seul contre l'ordinateur, "
     "ou à deux sur le même Wi-Fi, sans Internet.",
     "No buttons: you tilt the phone and your paddle follows. Alone against the computer, or "
     "two players on the same Wi-Fi, with no internet.",
     "Sin botones: inclinas el teléfono y tu paleta lo sigue. Solo contra la máquina, o entre "
     "dos en el mismo Wi-Fi, sin internet.", "Version mobile."),
    ("hero_demo_text",
     "Partie de démonstration. En jeu, ta raquette suit l'inclinaison du téléphone, et la "
     "balle accélère tous les 4 renvois.",
     "Demo game. When you play, your paddle follows the tilt of the phone, and the ball speeds "
     "up every 4 hits.",
     "Partida de demostración. Al jugar, tu paleta sigue la inclinación del teléfono y la "
     "pelota acelera cada 4 golpes.", ""),
    ("hero_note", "Gratuit · Android", "Free · Android", "Gratis · Android", ""),
    ("hero_badge", "1 vs 1", "1 vs 1", "1 vs 1", "Identique dans les trois langues."),
    # --- Le jeu (arguments) -------------------------------------------------------------
    ("features_kicker", "CE QUI CHANGE DU PONG CLASSIQUE", "WHAT'S DIFFERENT FROM CLASSIC PONG",
     "LO QUE CAMBIA RESPECTO AL PONG CLÁSICO", ""),
    ("features_title", "Quatre idées, poussées jusqu'au bout.", "Four ideas, taken all the way.",
     "Cuatro ideas, llevadas hasta el final.", "Ce qui suit la virgule s'affiche en gras."),
    ("features_intro",
     "Tilto garde la règle du Pong : renvoyer la balle et ne pas la laisser passer. Ce qui "
     "change, c'est la façon de jouer. Ici, ce sont tes mains et le téléphone tout entier qui "
     "servent de manette, et le duel se joue sans réseau mobile ni compte.",
     "Tilto keeps the rule of Pong: hit the ball back and don't let it past you. What changes "
     "is the way you play. Here, your hands and the whole phone are the controller, and the "
     "duel is played with no mobile network and no account.",
     "Tilto conserva la regla del Pong: devolver la pelota y no dejarla pasar. Lo que cambia "
     "es la forma de jugar. Aquí, tus manos y el teléfono entero hacen de mando, y el duelo se "
     "juega sin red móvil ni cuenta.", ""),
    ("feature.1.kicker", "INCLINE", "TILT", "INCLINA", ""),
    ("feature.1.title", "Pas de bouton. Tu penches, la raquette suit.",
     "No buttons. You tilt, the paddle follows.", "Sin botones. Inclinas y la paleta te sigue.",
     ""),
    ("feature.1.body",
     "L'accéléromètre lit l'angle du téléphone en continu. Plus tu penches, plus la raquette "
     "va vite. Tes pouces ne couvrent jamais l'écran, et rien n'est posé sur le terrain : le "
     "bouton pause reste dans la bande du haut.",
     "The accelerometer reads the phone's angle continuously. The more you tilt, the faster "
     "the paddle moves. Your thumbs never cover the screen, and nothing sits on the court: the "
     "pause button stays in the top bar.",
     "El acelerómetro lee el ángulo del teléfono sin parar. Cuanto más lo inclinas, más rápido "
     "va la paleta. Tus pulgares nunca tapan la pantalla y no hay nada sobre el campo: el "
     "botón de pausa se queda en la franja superior.", "« terrain » : « campo » (neutre)."),
    ("feature.1.short_body",
     "Plus tu penches, plus la raquette va vite. Tes pouces ne couvrent jamais l'écran. Son et "
     "vibration à chaque renvoi.",
     "The more you tilt, the faster the paddle moves. Your thumbs never cover the screen. "
     "Sound and vibration on every hit.",
     "Cuanto más lo inclinas, más rápido va la paleta. Tus pulgares nunca tapan la pantalla. "
     "Sonido y vibración en cada golpe.", "Version mobile."),
    ("feature.1.spec", "Prise en main", "Grip", "Agarre", ""),
    ("feature.1.spec", "À deux mains, en portrait", "Both hands, portrait",
     "Con las dos manos, en vertical", ""),
    ("feature.1.spec", "Retour", "Feedback", "Respuesta", "Retour sonore et haptique."),
    ("feature.1.spec", "Son et vibration à chaque renvoi", "Sound and vibration on every hit",
     "Sonido y vibración en cada golpe", ""),
    ("feature.1.spec", "Démarrage", "Start", "Inicio", ""),
    ("feature.1.spec", "Tape n'importe où", "Tap anywhere", "Toca en cualquier parte", ""),
    ("feature.1.spec", "Pause", "Pause", "Pausa", ""),
    ("feature.1.spec", "En solo uniquement", "Solo mode only", "Solo en modo Solo",
     "« Solo en modo Solo » : « solo » = seulement."),
    ("feature.2.kicker", "À DEUX", "FOR TWO", "PARA DOS", ""),
    ("feature.2.title", "Chacun son téléphone, chacun sa raquette en bas.",
     "One phone each, and everyone's paddle at the bottom.",
     "Cada uno con su teléfono, cada uno con su paleta abajo.", ""),
    ("feature.2.body",
     "L'un crée la partie, l'autre la voit apparaître dans sa liste et la rejoint. Il n'y a "
     "pas d'adresse IP à taper, ni de compte ou de code à partager. Les deux téléphones se "
     "parlent directement sur le Wi-Fi de la maison, ou sur le partage de connexion de l'un de "
     "vous, même sans forfait data.",
     "One of you creates the game, the other sees it appear in their list and joins. There's "
     "no IP address to type, and no account or code to share. The two phones talk to each "
     "other directly over your home Wi-Fi, or over one of your hotspots, even without a data "
     "plan.",
     "Uno crea la partida y el otro la ve aparecer en su lista y se une. No hay que escribir "
     "ninguna dirección IP ni compartir cuentas o códigos. Los dos teléfonos se comunican "
     "directamente por el Wi-Fi de casa, o por el punto de acceso de uno de los dos, incluso "
     "sin plan de datos.", "« forfait data » : « data plan » / « plan de datos »."),
    ("feature.2.short_body",
     "L'un crée la partie, l'autre la voit apparaître et la rejoint. Les téléphones se "
     "parlent directement, même sans forfait data.",
     "One creates the game, the other sees it appear and joins. The phones talk to each other "
     "directly, even without a data plan.",
     "Uno crea la partida y el otro la ve aparecer y se une. Los teléfonos se comunican "
     "directamente, incluso sin plan de datos.", "Version mobile."),
    ("feature.2.spec", "Format", "Format", "Formato", ""),
    ("feature.2.spec", "Premier à 5 points", "First to 5 points", "A 5 puntos", ""),
    ("feature.2.spec", "Réseau", "Network", "Red", ""),
    ("feature.2.spec", "Même Wi-Fi ou partage de connexion", "Same Wi-Fi or hotspot",
     "Mismo Wi-Fi o punto de acceso", ""),
    ("feature.2.spec", "Lancement", "Start", "Inicio", ""),
    ("feature.2.spec", "Les deux « Prêt », puis 3-2-1", "Both “Ready”, then 3-2-1",
     "Los dos «Listo», luego 3-2-1", "« Prêt » : bouton de l'app (Ready / Listo)."),
    ("feature.2.spec", "Revanche", "Rematch", "Revancha", ""),
    ("feature.2.spec", "Un bouton, sans repasser par le menu", "One button, no trip back to the menu",
     "Un botón, sin volver al menú", ""),
    ("feature.3.kicker", "SENSIBILITÉ", "SENSITIVITY", "SENSIBILIDAD", ""),
    ("feature.3.title", "Réglée pour ta façon de tenir.", "Tuned to the way you hold it.",
     "Ajustada a tu forma de sostenerlo.", ""),
    ("feature.3.body",
     "Certains jouent à petits gestes, d'autres font tourner tout le téléphone. Le curseur de "
     "sensibilité adapte la vitesse de la raquette à l'angle. Tu le règles une fois et il "
     "reste mémorisé. La musique, les effets sonores et la vibration ont chacun leur "
     "interrupteur.",
     "Some people play with small moves, others turn the whole phone. The sensitivity slider "
     "adjusts how fast the paddle moves for a given angle. You set it once and it's "
     "remembered. Music, sound effects and vibration each have their own switch.",
     "Algunos juegan con gestos pequeños; otros giran todo el teléfono. El control de "
     "sensibilidad ajusta la velocidad de la paleta según el ángulo. Lo ajustas una vez y "
     "queda guardado. La música, los efectos sonoros y la vibración tienen cada uno su "
     "interruptor.", ""),
    ("feature.3.short_body",
     "De douce à vive, mémorisée une fois pour toutes. Musique, effets sonores et vibration "
     "ont chacun leur interrupteur.",
     "From low to high, saved once and for all. Music, sound effects and vibration each have "
     "their own switch.",
     "De baja a alta, guardada de una vez por todas. Música, efectos sonoros y vibración "
     "tienen cada uno su interruptor.", "Douce / Vive = Low / High = Baja / Alta (glossaire)."),
    ("feature.3.spec", "Sensibilité", "Sensitivity", "Sensibilidad", ""),
    ("feature.3.spec", "De douce à vive", "From low to high", "De baja a alta", ""),
    ("feature.3.spec", "Son", "Sound", "Sonido", ""),
    ("feature.3.spec", "Musique et effets, activés ou coupés", "Music and effects, on or off",
     "Música y efectos, activados o desactivados", ""),
    ("feature.3.spec", "Vibration", "Vibration", "Vibración", ""),
    ("feature.3.spec", "Activée ou coupée", "On or off", "Activada o desactivada", ""),
    ("feature.3.spec", "Où", "Where", "Dónde", ""),
    ("feature.3.spec", "Accueil › Réglages", "Home › Settings", "Inicio › Ajustes",
     "Noms des écrans de l'app."),
    ("feature.4.kicker", "RECORDS", "HIGH SCORES", "RÉCORDS", ""),
    ("feature.4.title", "Bats ton record, puis celui de la famille.",
     "Beat your high score, then the family's.", "Supera tu récord y luego el de la familia.",
     ""),
    ("feature.4.body",
     "Le classement garde les 10 meilleurs scores joués sur le téléphone, avec le pseudo et la "
     "date. Quand quelqu'un bat le record pendant une partie, le terrain passe à l'or. Les "
     "statistiques comptent tes parties, ton temps de jeu, ta meilleure série de renvois et ton "
     "bilan en duel.",
     "The leaderboard keeps the 10 best scores played on the phone, with the nickname and the "
     "date. When someone beats the high score during a game, the court turns gold. The "
     "statistics count your games, your play time, your best streak of hits and your duel "
     "record.",
     "La clasificación guarda las 10 mejores puntuaciones jugadas en el teléfono, con el apodo "
     "y la fecha. Cuando alguien supera el récord durante una partida, el campo se vuelve "
     "dorado. Las estadísticas cuentan tus partidas, tu tiempo de juego, tu mejor racha de "
     "golpes y tu balance en duelo.", ""),
    ("feature.4.short_body",
     "Top 10 du téléphone avec pseudo et date. Statistiques : parties, temps de jeu, meilleure "
     "série, bilan en duel.",
     "Top 10 on the phone with nickname and date. Statistics: games, play time, best streak, "
     "duel record.",
     "Top 10 del teléfono con apodo y fecha. Estadísticas: partidas, tiempo de juego, mejor "
     "racha, balance en duelo.", "Version mobile."),
    ("feature.4.spec", "Classement", "Leaderboard", "Clasificación", ""),
    ("feature.4.spec", "Top 10 local", "Local top 10", "Top 10 local", ""),
    ("feature.4.spec", "Statistiques", "Statistics", "Estadísticas", ""),
    ("feature.4.spec", "Parties, temps, série, duels", "Games, time, streak, duels",
     "Partidas, tiempo, racha, duelos", ""),
    ("feature.4.spec", "Accès", "Access", "Acceso", ""),
    ("feature.4.spec", "Depuis l'accueil, à tout moment", "From the home screen, any time",
     "Desde el inicio, en cualquier momento", ""),
    ("feature.4.spec", "Stockage", "Storage", "Almacenamiento", ""),
    ("feature.4.spec", "Sur le téléphone, jamais en ligne", "On the phone, never online",
     "En el teléfono, nunca en línea", ""),
    # --- Face-à-face et comparatif ----------------------------------------------------
    ("duel_kicker", "FACE-À-FACE · DUEL · PREMIER À 5", "FACE TO FACE · DUEL · FIRST TO 5",
     "CARA A CARA · DUELO · A 5 PUNTOS", ""),
    ("duel_title", "Chacun son téléphone,", "One phone each,", "Cada uno con su teléfono,",
     "Première ligne du titre."),
    ("duel_title_accent", "chacun sa raquette en bas.", "and everyone's paddle at the bottom.",
     "cada uno con su paleta abajo.", "Deuxième ligne, en dégradé."),
    ("duel_left_label", "TÉLÉPHONE DE LÉA", "LÉA'S PHONE", "TELÉFONO DE LÉA", ""),
    ("duel_left_text", "Léa se voit en bas, en bleu. Tom est en haut, en vert.",
     "Léa sees herself at the bottom, in blue. Tom is at the top, in green.",
     "Léa se ve abajo, en azul. Tom está arriba, en verde.", ""),
    ("duel_right_label", "TÉLÉPHONE DE TOM", "TOM'S PHONE", "TELÉFONO DE TOM", ""),
    ("duel_right_text",
     "Sur son écran, c'est Tom qui est en bas, en bleu. Le premier à 5 gagne.",
     "On his screen, Tom is the one at the bottom, in blue. First to 5 wins.",
     "En su pantalla, es Tom quien está abajo, en azul. Gana el primero en llegar a 5.", ""),
    ("duel_chip_1", "Même Wi-Fi ou partage de connexion", "Same Wi-Fi or hotspot",
     "Mismo Wi-Fi o punto de acceso", ""),
    ("duel_chip_2", "Les deux « Prêt », puis 3-2-1", "Both “Ready”, then 3-2-1",
     "Los dos «Listo», luego 3-2-1", ""),
    ("duel_chip_3", "Revanche en un bouton", "One-tap rematch", "Revancha con un botón", ""),
    ("compare_kicker", "SOLO OU DUEL", "SOLO OR DUEL", "SOLO O DUELO", ""),
    ("compare_title", "Deux façons de jouer, mêmes règles de base.",
     "Two ways to play, same basic rules.", "Dos formas de jugar, mismas reglas básicas.", ""),
    ("compare", "Adversaire", "Opponent", "Rival", ""),
    ("compare", "L'ordinateur", "The computer", "La máquina", "Glossaire : « la máquina »."),
    ("compare", "Un ami, sur son téléphone", "A friend, on their phone", "Un amigo, en su teléfono",
     ""),
    ("compare", "Niveaux", "Levels", "Niveles", ""),
    ("compare", "Facile, Normal, Difficile", "Easy, Normal, Hard", "Fácil, Normal, Difícil", ""),
    ("compare", "Le niveau de ton ami", "Your friend's level", "El nivel de tu amigo", ""),
    ("compare", "But", "Goal", "Objetivo", ""),
    ("compare", "Le plus gros score possible", "The highest score possible",
     "La puntuación más alta posible", ""),
    ("compare", "Arriver le premier à 5 points", "Be first to 5 points",
     "Llegar primero a 5 puntos", ""),
    ("compare", "Fin de partie", "Game over", "Fin de la partida", ""),
    ("compare", "La balle passe derrière toi", "The ball gets past you",
     "La pelota pasa detrás de ti", ""),
    ("compare", "Un joueur atteint 5 points", "A player reaches 5 points",
     "Un jugador llega a 5 puntos", ""),
    ("compare", "Oui, avec musique", "Yes, with music", "Sí, con música", ""),
    ("compare", "Non, le duel ne s'arrête pas", "No, the duel doesn't stop",
     "No, el duelo no se detiene", ""),
    ("compare", "Aucun, même en mode avion", "None, even in airplane mode",
     "Ninguna, incluso en modo avión", ""),
    ("compare", "Même Wi-Fi ou partage de connexion, sans Internet",
     "Same Wi-Fi or hotspot, no internet", "Mismo Wi-Fi o punto de acceso, sin internet", ""),
    ("compare", "Compte dans", "Counts toward", "Cuenta para", ""),
    ("compare", "Classement, statistiques", "Leaderboard, statistics",
     "Clasificación, estadísticas", ""),
    ("compare", "Victoires et défaites", "Wins and losses", "Victorias y derrotas", ""),
    # --- Fiche technique -------------------------------------------------------------
    ("hero_spec", "MODES", "MODES", "MODOS", ""),
    ("hero_spec", "Solo · Duel", "Solo · Duel", "Solo · Duelo", ""),
    ("hero_spec", "JOUEURS", "PLAYERS", "JUGADORES", ""),
    ("hero_spec", "1 ou 2", "1 or 2", "1 o 2", ""),
    ("hero_spec", "INTERNET", "INTERNET", "INTERNET", ""),
    ("hero_spec", "Jamais requis", "Never needed", "Nunca necesario", ""),
    ("hero_spec", "ANDROID", "ANDROID", "ANDROID", ""),
    ("hero_spec", "5.0 et plus", "5.0 and up", "5.0 o superior", ""),
    ("hero_spec", "PRIX", "PRICE", "PRECIO", ""),
    ("hero_spec", "Gratuit", "Free", "Gratis", ""),
    # --- Comment jouer, barème --------------------------------------------------------
    ("steps_title", "Comment jouer", "How to play", "Cómo jugar", ""),
    ("step.1.title", "Prends ton téléphone à deux mains.", "Grab your phone with both hands.",
     "Toma tu teléfono con las dos manos.", "Glossaire : « Grab your phone » / « Toma tu teléfono »."),
    ("step.1.body",
     "En portrait, l'écran face à toi, à plat ou légèrement relevé. Sur l'accueil, choisis "
     "Solo ou Multijoueur.",
     "In portrait, screen facing you, flat or slightly raised. On the home screen, choose Solo "
     "or Multiplayer.",
     "En vertical, con la pantalla hacia ti, plano o un poco levantado. En el inicio, elige "
     "Solo o Multijugador.", ""),
    ("step.2.title", "Tape l'écran pour lancer la balle.", "Tap the screen to serve the ball.",
     "Toca la pantalla para lanzar la pelota.", ""),
    ("step.2.body",
     "En duel, pas besoin : un compte à rebours 3-2-1 lance la balle sur les deux téléphones "
     "en même temps.",
     "In a duel, no need: a 3-2-1 countdown serves the ball on both phones at the same time.",
     "En duelo no hace falta: una cuenta regresiva 3-2-1 lanza la pelota en los dos teléfonos "
     "a la vez.", "« cuenta regresiva » (Amérique latine) plutôt que « cuenta atrás » (Espagne)."),
    ("step.3.title", "Incline pour la renvoyer.", "Tilt to hit it back.", "Inclina para devolverla.",
     ""),
    ("step.3.body",
     "Penche vers la gauche ou la droite pour placer ta raquette sous la balle. Ne la laisse "
     "pas passer derrière toi.",
     "Lean left or right to get your paddle under the ball. Don't let it get past you.",
     "Inclina hacia la izquierda o la derecha para poner tu paleta bajo la pelota. No dejes que "
     "pase detrás de ti.", ""),
    ("scoring_title", "Barème en solo", "Solo scoring", "Puntuación en solitario", ""),
    ("scoring", "Chaque renvoi", "Each hit", "Cada golpe", ""),
    ("scoring", "+50", "+50", "+50", ""),
    ("scoring", "L'ordinateur rate la balle", "The computer misses the ball",
     "La máquina falla la pelota", ""),
    ("scoring", "+100", "+100", "+100", ""),
    ("scoring", "La balle accélère", "The ball speeds up", "La pelota acelera", ""),
    ("scoring", "tous les 4 renvois", "every 4 hits", "cada 4 golpes", ""),
    # --- Captures ---------------------------------------------------------------------
    ("screens_title", "Captures", "Screenshots", "Capturas", ""),
    ("screens_intro", "À quoi ça ressemble sur ton téléphone.", "What it looks like on your phone.",
     "Así se ve en tu teléfono.", ""),
    ("screens_note", "Captures réelles · Android, 360 × 800", "Real screenshots · Android, 360 × 800",
     "Capturas reales · Android, 360 × 800", "Texte initial."),
    ("screens_note", "Captures réelles du jeu, sur Android", "Real in-game screenshots, on Android",
     "Capturas reales del juego, en Android", "Texte en ligne."),
    ("screenshot.caption", "L'accueil", "The home screen", "El inicio", ""),
    ("screenshot.description",
     "Choisis Solo ou Multijoueur, et en solo la difficulté : Facile, Normal ou Difficile. Le "
     "classement, les statistiques et les réglages sont à portée de pouce.",
     "Choose Solo or Multiplayer and, in solo, the difficulty: Easy, Normal or Hard. The "
     "leaderboard, statistics and settings are within thumb's reach.",
     "Elige Solo o Multijugador y, en solitario, la dificultad: Fácil, Normal o Difícil. La "
     "clasificación, las estadísticas y los ajustes están al alcance del pulgar.",
     "Texte initial."),
    ("screenshot.description",
     "Choisis Solo ou Multijoueur, et en solo la difficulté : Facile, Normal ou Difficile. Le "
     "classement, les statistiques et l'aide sont à portée de pouce.",
     "Choose Solo or Multiplayer and, in solo, the difficulty: Easy, Normal or Hard. The "
     "leaderboard, statistics and help are within thumb's reach.",
     "Elige Solo o Multijugador y, en solitario, la dificultad: Fácil, Normal o Difícil. La "
     "clasificación, las estadísticas y la ayuda están al alcance del pulgar.",
     "Texte en ligne."),
    ("screenshot.caption", "En solo", "Solo", "En solitario", ""),
    ("screenshot.description",
     "Le score reste discret, la balle en vedette. La jauge de vitesse, en haut, annonce la "
     "prochaine accélération.",
     "The score stays discreet and the ball takes center stage. The speed gauge at the top "
     "shows the next speed-up.",
     "La puntuación queda discreta y la pelota es la protagonista. El indicador de velocidad, "
     "arriba, anuncia la próxima aceleración.", "Texte initial."),
    ("screenshot.description",
     "Tape l'écran pour lancer la balle, puis incline le téléphone. Ta raquette bleue est en "
     "bas, l'ordinateur en haut.",
     "Tap the screen to serve the ball, then tilt the phone. Your blue paddle is at the bottom, "
     "the computer at the top.",
     "Toca la pantalla para lanzar la pelota y luego inclina el teléfono. Tu paleta azul está "
     "abajo; la máquina, arriba.", "Texte en ligne."),
    ("screenshot.caption", "En duel", "Duel", "En duelo", ""),
    ("screenshot.description",
     "Chaque score est de son côté, dans sa couleur. Le premier à 5 points gagne.",
     "Each score is on its own side, in its own color. First to 5 points wins.",
     "Cada puntuación está en su lado, con su color. Gana el primero en llegar a 5 puntos.", ""),
    ("screenshot.caption", "Fin du duel", "End of the duel", "Fin del duelo", ""),
    ("screenshot.description",
     "Score final, durée, plus long échange. Un bouton pour la revanche, l'autre joueur n'a "
     "qu'à accepter.",
     "Final score, duration, longest rally. One button for a rematch; the other player just "
     "has to accept.",
     "Marcador final, duración, intercambio más largo. Un botón para la revancha; el otro "
     "jugador solo tiene que aceptar.", "Glossaire : échange = rally / intercambio."),
    ("screenshot.caption", "Fin de partie", "Game over", "Fin de la partida", "Texte en ligne."),
    ("screenshot.description",
     "Ton score, tes renvois, la durée et la vitesse atteinte. Rejoue en un geste, ou va voir "
     "le classement.",
     "Your score, your hits, the duration and the speed reached. Play again in one tap, or "
     "check the leaderboard.",
     "Tu puntuación, tus golpes, la duración y la velocidad alcanzada. Vuelve a jugar con un "
     "toque o mira la clasificación.", "Texte en ligne."),
    ("screenshot.caption", "Le classement", "The leaderboard", "La clasificación", "Texte en ligne."),
    ("screenshot.description",
     "Les 10 meilleurs scores du téléphone, avec le pseudo et la date. Or, argent et bronze "
     "pour le podium.",
     "The phone's 10 best scores, with the nickname and the date. Gold, silver and bronze for "
     "the podium.",
     "Las 10 mejores puntuaciones del teléfono, con el apodo y la fecha. Oro, plata y bronce "
     "para el podio.", "Texte en ligne."),
    ("screenshot.caption", "Les statistiques", "Statistics", "Las estadísticas", "Texte en ligne."),
    ("screenshot.description",
     "Parties jouées, meilleur score, temps de jeu, meilleure série de renvois, et ton bilan "
     "en duel.",
     "Games played, best score, play time, best streak of hits, and your duel record.",
     "Partidas jugadas, mejor puntuación, tiempo de juego, mejor racha de golpes y tu balance "
     "en duelo.", "Texte en ligne."),
    ("screenshot.caption", "Les réglages", "Settings", "Los ajustes", "Texte en ligne."),
    ("screenshot.description",
     "Musique, effets sonores, vibration, et la sensibilité de la raquette, à essayer tout de "
     "suite dans la zone d'essai.",
     "Music, sound effects, vibration and paddle sensitivity, which you can try right away in "
     "the “Try it” area.",
     "Música, efectos sonoros, vibración y la sensibilidad de la paleta, que puedes probar "
     "enseguida en la zona «Pruébalo».", "Texte en ligne. Zone d'essai = « Try it » / « Pruébalo »."),
    # --- FAQ ----------------------------------------------------------------------
    ("faq_title", "Questions fréquentes", "Frequently asked questions", "Preguntas frecuentes", ""),
    ("faq_subtitle", "Avant de télécharger.", "Before you download.", "Antes de descargar.", ""),
    ("faq_text", "Une autre question ? Écris-nous avec le formulaire de contact.",
     "Another question? Write to us using the contact form.",
     "¿Otra pregunta? Escríbenos con el formulario de contacto.", ""),
    ("faq.internet.question", "Faut-il Internet pour jouer ?", "Do I need the internet to play?",
     "¿Hace falta internet para jugar?", ""),
    ("faq.internet.answer",
     "Non. Le solo marche même en mode avion. Le duel a juste besoin que les deux téléphones "
     "soient sur le même Wi-Fi ou partage de connexion.",
     "No. Solo works even in airplane mode. The duel just needs both phones to be on the same "
     "Wi-Fi or hotspot.",
     "No. El modo Solo funciona incluso en modo avión. El duelo solo necesita que ambos "
     "teléfonos estén en el mismo Wi-Fi o punto de acceso.", ""),
    ("faq.internet.short_answer",
     "Non. Le solo marche en mode avion, le duel a juste besoin du même Wi-Fi.",
     "No. Solo works in airplane mode; the duel just needs the same Wi-Fi.",
     "No. El modo Solo funciona en modo avión; el duelo solo necesita el mismo Wi-Fi.", ""),
    ("faq.iphone.question", "Mon ami a un iPhone, on peut jouer ?",
     "My friend has an iPhone. Can we play?", "Mi amigo tiene un iPhone, ¿podemos jugar?", ""),
    ("faq.iphone.answer",
     "Pas encore : Tilto existe uniquement sur Android pour l'instant. Le duel demande Tilto "
     "sur les deux téléphones.",
     "Not yet: Tilto is only available on Android for now. The duel needs Tilto on both phones.",
     "Todavía no: por ahora, Tilto solo existe en Android. El duelo necesita Tilto en ambos "
     "teléfonos.", ""),
    ("faq.iphone.short_answer",
     "Pas encore : Tilto existe uniquement sur Android pour l'instant.",
     "Not yet: Tilto is only available on Android for now.",
     "Todavía no: por ahora, Tilto solo existe en Android.", ""),
    ("faq.duel-connexion.question", "Le duel ne trouve pas la partie de mon ami.",
     "The duel can't find my friend's game.", "El duelo no encuentra la partida de mi amigo.", ""),
    ("faq.duel-connexion.answer",
     "Vérifiez que vous êtes sur le même réseau (pas un Wi-Fi invité), que ton ami a bien "
     "touché « Créer une partie », puis touche Actualiser.",
     "Check that you're both on the same network (not a guest Wi-Fi) and that your friend has "
     "tapped “Create a game”, then tap Refresh.",
     "Comprueba que ambos teléfonos estén en la misma red (no una red Wi-Fi para invitados) y "
     "que tu amigo haya tocado «Crear una partida»; luego toca Actualizar.",
     "Boutons de l'app : Create a game / Crear una partida, Refresh / Actualizar."),
    ("faq.duel-connexion.short_answer",
     "Même réseau (pas un Wi-Fi invité), « Créer une partie » côté ami, puis Actualiser.",
     "Same network (not a guest Wi-Fi), “Create a game” on your friend's side, then Refresh.",
     "Misma red (no una red Wi-Fi para invitados), «Crear una partida» en el teléfono de tu "
     "amigo y luego Actualizar.", ""),
    ("faq.petit-telephone.question", "Ça marche sur un petit téléphone ?",
     "Does it work on a small phone?", "¿Funciona en un teléfono pequeño?", ""),
    ("faq.petit-telephone.answer",
     "Oui. Le terrain s'adapte à la taille de l'écran, et Tilto fonctionne à partir d'Android "
     "5.0.",
     "Yes. The court adapts to the screen size, and Tilto works on Android 5.0 and up.",
     "Sí. El campo se adapta al tamaño de la pantalla, y Tilto funciona a partir de Android "
     "5.0.", ""),
    ("faq.pubs-achats.question", "Y a-t-il des achats ou des pubs ?",
     "Are there any purchases or ads?", "¿Hay compras o anuncios?", ""),
    ("faq.pubs-achats.answer",
     "Non. Tilto est gratuit, sans publicité, sans achat intégré et sans compte.",
     "No. Tilto is free, with no ads, no in-app purchases and no account.",
     "No. Tilto es gratis, sin anuncios, sin compras integradas y sin cuenta.", ""),
    ("faq.pubs-achats.short_answer", "Aucun. Gratuit, sans compte.", "None. Free, no account.",
     "Ninguno. Gratis, sin cuenta.", ""),
    ("faq.sensibilite.question", "La raquette part toute seule.",
     "The paddle moves on its own.", "La paleta se mueve sola.", ""),
    ("faq.sensibilite.answer",
     "La raquette suit l'inclinaison gauche-droite du téléphone : tiens-le bien droit, sans le "
     "pencher sur le côté, et elle s'arrête. Si elle reste trop vive, baisse la sensibilité dans "
     "Accueil › Réglages.",
     "The paddle follows the phone's left-right tilt: hold it level, without leaning it to the "
     "side, and it stops. If it's still too fast, lower the sensitivity in Home › Settings.",
     "La paleta sigue la inclinación izquierda-derecha del teléfono: sostenlo bien derecho, sin "
     "inclinarlo hacia un lado, y se detiene. Si sigue demasiado rápida, baja la sensibilidad en "
     "Inicio › Ajustes.", ""),
    # --- Téléchargement, installation, nouveautés -------------------------------------
    ("download_title", "Télécharge Tilto", "Download Tilto", "Descarga Tilto",
     "Le dernier mot s'affiche en gras."),
    ("download_text",
     "Le Play Store installe les mises à jour tout seul. L'APK sert si tu n'as pas le Play "
     "Store ou si tu veux l'installer à la main.",
     "The Play Store installs updates on its own. The APK is for when you don't have the Play "
     "Store or want to install the game by hand.",
     "Play Store instala las actualizaciones por sí solo. El APK sirve si no tienes Play Store "
     "o si quieres instalar el juego a mano.", ""),
    ("install_title", "Installer l'APK", "Install the APK", "Instalar el APK", ""),
    ("install", "Télécharge le fichier", "Download the file", "Descarga el archivo", ""),
    ("install", "Depuis ton téléphone Android.", "From your Android phone.",
     "Desde tu teléfono Android.", ""),
    ("install", "Ouvre-le", "Open it", "Ábrelo", ""),
    ("install", "Si Android le demande, autorise ton navigateur à installer des applications.",
     "If Android asks, allow your browser to install apps.",
     "Si Android lo pide, permite que tu navegador instale aplicaciones.", ""),
    ("install", "Installe", "Install it", "Instálalo", ""),
    ("install", "Touche Installer, puis Ouvrir.", "Tap Install, then Open.",
     "Toca Instalar y luego Abrir.", "Boutons d'Android, à vérifier sur un téléphone en anglais "
     "et en espagnol."),
    ("install_note",
     "L'APK n'est pas signé avec la même clé que la version du Play Store : pour passer de l'un "
     "à l'autre, il faudra désinstaller Tilto, et tes scores seront perdus.",
     "The APK isn't signed with the same key as the Play Store version: to switch from one to "
     "the other, you'll have to uninstall Tilto, and your scores will be lost.",
     "El APK no está firmado con la misma clave que la versión de Play Store: para pasar de uno "
     "a otro, tendrás que desinstalar Tilto y perderás tus puntuaciones.", ""),
    ("notes_title", "Nouveautés", "What's new", "Novedades", "Suivi du numéro de version."),
    ("release_notes", "Solo contre l'ordinateur, sur trois niveaux : Facile, Normal, Difficile.",
     "Solo against the computer, on three levels: Easy, Normal, Hard.",
     "Solo contra la máquina, en tres niveles: Fácil, Normal, Difícil.", "Notes de la 1.0.0."),
    ("release_notes", "Mode Duel : deux téléphones sur le même Wi-Fi, premier à 5 points.",
     "Duel mode: two phones on the same Wi-Fi, first to 5 points.",
     "Modo Duelo: dos teléfonos en el mismo Wi-Fi, a 5 puntos.", "Notes de la 1.0.0."),
    ("release_notes", "Classement des 10 meilleurs scores et statistiques, depuis l'accueil.",
     "Leaderboard of the 10 best scores and statistics, from the home screen.",
     "Clasificación de las 10 mejores puntuaciones y estadísticas, desde el inicio.",
     "Notes de la 1.0.0."),
    ("release_notes", "Réglages : sensibilité, musique, effets sonores et vibration.",
     "Settings: sensitivity, music, sound effects and vibration.",
     "Ajustes: sensibilidad, música, efectos sonoros y vibración.", "Notes de la 1.0.0."),
    ("release_notes", "Fin de partie avec « Nouveau record ».",
     "Game over screen with “New high score”.", "Fin de la partida con «Nuevo récord».",
     "Notes de la 1.0.0. Glossaire : New high score / Nuevo récord."),
    # --- Liens et pied de page --------------------------------------------------------
    ("play_soon_text", "Bientôt disponible", "Coming soon", "Próximamente", ""),
    ("footer_text",
     "Le Pong qu'on joue en inclinant son téléphone, seul ou à deux sur le même Wi-Fi. "
     "Gratuit, sans pub, sans compte.",
     "The Pong you play by tilting your phone, alone or with a friend on the same Wi-Fi. Free, "
     "no ads, no account.",
     "El Pong que se juega inclinando el teléfono, solo o entre dos en el mismo Wi-Fi. Gratis, "
     "sin anuncios, sin cuenta.", ""),
    ("footer_note", "Aucune donnée personnelle collectée · tout reste sur ton téléphone",
     "No personal data collected · everything stays on your phone",
     "No se recopila ningún dato personal · todo se queda en tu teléfono", "Texte initial."),
    ("footer_note", "Le jeu ne collecte aucune donnée personnelle · tout reste sur ton téléphone",
     "The game collects no personal data · everything stays on your phone",
     "El juego no recopila ningún dato personal · todo se queda en tu teléfono", "Texte en ligne."),
    ("footer_trademark", "Android est une marque de Google LLC.",
     "Android is a trademark of Google LLC.", "Android es una marca de Google LLC.", ""),
    # --- Politique de confidentialité (bloc par bloc) ---------------------------------
    ("privacy_policy",
     "Tilto ne collecte aucune donnée personnelle. Tout ce que le jeu enregistre reste sur ton "
     "téléphone.",
     "Tilto collects no personal data. Everything the game saves stays on your phone.",
     "Tilto no recopila ningún dato personal. Todo lo que el juego guarda se queda en tu "
     "teléfono.", "Introduction."),
    ("privacy_policy", "## Ce que Tilto garde sur ton téléphone",
     "## What Tilto keeps on your phone", "## Lo que Tilto guarda en tu teléfono", "Intertitre."),
    ("privacy_policy",
     "Ton pseudo, tes 10 meilleurs scores, tes statistiques (parties jouées, temps de jeu, "
     "meilleure série, victoires et défaites en duel) et tes réglages (sensibilité, son, "
     "vibration). Ces informations ne sont jamais envoyées ailleurs.",
     "Your nickname, your 10 best scores, your statistics (games played, play time, best "
     "streak, duel wins and losses) and your settings (sensitivity, sound, vibration). This "
     "information is never sent anywhere else.",
     "Tu apodo, tus 10 mejores puntuaciones, tus estadísticas (partidas jugadas, tiempo de "
     "juego, mejor racha, victorias y derrotas en duelo) y tus ajustes (sensibilidad, sonido, "
     "vibración). Esta información nunca se envía a ningún otro lugar.", ""),
    ("privacy_policy", "## Pendant un duel", "## During a duel", "## Durante un duelo", "Intertitre."),
    ("privacy_policy",
     "Les deux téléphones communiquent directement sur votre réseau Wi-Fi local, le temps de la "
     "partie : pseudos, position des raquettes et de la balle, score. Rien ne passe par "
     "Internet ni par nos serveurs.",
     "The two phones communicate directly over your local Wi-Fi network for the length of the "
     "game: nicknames, paddle and ball positions, score. Nothing goes through the internet or "
     "our servers.",
     "Los dos teléfonos se comunican directamente por su red Wi-Fi local mientras dura la "
     "partida: apodos, posición de las paletas y de la pelota, marcador. Nada pasa por "
     "internet ni por nuestros servidores.", ""),
    ("privacy_policy", "## Nom et logo du studio", "## Studio name and logo",
     "## Nombre y logotipo del estudio", "Intertitre."),
    ("privacy_policy",
     "Au lancement, et au plus une fois par jour, Tilto demande à tilto.fun le nom, le logo et "
     "la présentation du studio, pour les afficher dans l'app. Cette demande ne contient aucune "
     "donnée personnelle et rien sur ta façon de jouer. Comme pour toute visite d'un site, notre "
     "serveur voit l'adresse IP du téléphone (voir « Ce site »). Sans Internet, l'app affiche "
     "simplement le dernier logo connu.",
     "At launch, and at most once a day, Tilto asks tilto.fun for the studio's name, logo and "
     "description, to show them in the app. This request contains no personal data and nothing "
     "about the way you play. As with any website visit, our server sees the phone's IP address "
     "(see “This website”). Without internet, the app simply shows the last known logo.",
     "Al iniciarse, y como máximo una vez al día, Tilto le pide a tilto.fun el nombre, el "
     "logotipo y la presentación del estudio para mostrarlos en la app. Esta solicitud no "
     "contiene ningún dato personal ni nada sobre tu forma de jugar. Como en cualquier visita a "
     "un sitio web, nuestro servidor ve la dirección IP del teléfono (ver «Este sitio»). Sin "
     "internet, la app simplemente muestra el último logotipo conocido.",
     "« Ce site » renvoie à l'intertitre plus bas : garder le même libellé."),
    ("privacy_policy", "## Ce que Tilto n'utilise pas", "## What Tilto doesn't use",
     "## Lo que Tilto no usa", "Intertitre."),
    ("privacy_policy",
     "Pas de compte, pas de publicité, pas d'outil de mesure d'audience, pas de localisation.",
     "No account, no ads, no analytics tools, no location.",
     "Sin cuenta, sin publicidad, sin herramientas de medición de audiencia, sin ubicación.", ""),
    ("privacy_policy", "## Autorisations demandées", "## Permissions requested",
     "## Permisos solicitados", "Intertitre."),
    ("privacy_policy",
     "L'accès au réseau : le Wi-Fi local, pour trouver et rejoindre une partie en duel, et "
     "Internet, pour récupérer le nom et le logo du studio. La vibration, pour les renvois. Le "
     "capteur de mouvement qui sert à déplacer la raquette ne demande pas d'autorisation.",
     "Network access: the local Wi-Fi, to find and join a duel, and the internet, to fetch the "
     "studio's name and logo. Vibration, for hits. The motion sensor used to move the paddle "
     "doesn't require any permission.",
     "El acceso a la red: el Wi-Fi local, para encontrar una partida en duelo y unirse a ella, e "
     "internet, para obtener el nombre y el logotipo del estudio. La vibración, para los "
     "golpes. El sensor de movimiento que sirve para mover la paleta no necesita ningún "
     "permiso.", "Version à jour (après reseed_studio)."),
    ("privacy_policy",
     "L'accès au réseau Wi-Fi, pour trouver et rejoindre une partie en duel. La vibration, pour "
     "les renvois. Le capteur de mouvement qui sert à déplacer la raquette ne demande pas "
     "d'autorisation.",
     "Wi-Fi network access, to find and join a duel. Vibration, for hits. The motion sensor "
     "used to move the paddle doesn't require any permission.",
     "El acceso a la red Wi-Fi, para encontrar una partida en duelo y unirse a ella. La "
     "vibración, para los golpes. El sensor de movimiento que sirve para mover la paleta no "
     "necesita ningún permiso.", "Ancienne version (avant reseed_studio)."),
    ("privacy_policy", "## Ce site", "## This website", "## Este sitio", "Intertitre."),
    ("privacy_policy",
     "Comme tout site web, notre serveur enregistre des journaux techniques pour chaque visite : "
     "adresse IP, date et heure, page demandée et type de navigateur. Ils servent uniquement à "
     "faire fonctionner le site, à le sécuriser et à corriger les erreurs. Ils ne sont ni vendus "
     "ni partagés, et ne sont conservés que pour une durée limitée. Le site ne dépose aucun "
     "cookie de suivi.",
     "Like any website, our server keeps technical logs of each visit: IP address, date and "
     "time, page requested and browser type. They are used only to run the site, keep it "
     "secure and fix errors. They are neither sold nor shared, and are kept only for a limited "
     "time. The site sets no tracking cookies.",
     "Como cualquier sitio web, nuestro servidor guarda registros técnicos de cada visita: "
     "dirección IP, fecha y hora, página solicitada y tipo de navegador. Solo sirven para que "
     "el sitio funcione, protegerlo y corregir errores. No se venden ni se comparten, y solo se "
     "conservan durante un tiempo limitado. El sitio no instala ninguna cookie de seguimiento.",
     ""),
    ("privacy_policy", "## Formulaire de contact", "## Contact form", "## Formulario de contacto",
     "Intertitre."),
    ("privacy_policy",
     "Si tu nous écris avec le formulaire de la page Contact, nous recevons ton adresse e-mail, "
     "le sujet choisi, ton message et, si tu l'indiques, ton nom. Ces informations servent "
     "uniquement à te répondre : elles ne sont ni vendues, ni partagées, ni utilisées pour "
     "t'envoyer de la publicité. Elles sont conservées jusqu'à ce que nous supprimions le "
     "message. Une copie peut nous être transmise par e-mail pour que nous la voyions plus vite. "
     "La page Contact dépose un cookie technique de sécurité, effacé à la fermeture du "
     "navigateur ; il ne sert pas à te suivre.",
     "If you write to us using the form on the Contact page, we receive your email address, "
     "the subject you chose, your message and, if you give it, your name. This information is "
     "used only to reply to you: it is not sold, shared or used to send you advertising. It is "
     "kept until we delete the message. A copy may be sent to us by email so that we see it "
     "sooner. The Contact page sets a technical security cookie, deleted when you close your "
     "browser; it isn't used to track you.",
     "Si nos escribes con el formulario de la página Contacto, recibimos tu correo electrónico, "
     "el asunto elegido, tu mensaje y, si lo indicas, tu nombre. Esta información solo sirve "
     "para responderte: no se vende, no se comparte ni se usa para enviarte publicidad. Se "
     "conserva hasta que borramos el mensaje. Es posible que recibamos una copia por correo "
     "electrónico para verla antes. La página Contacto instala una cookie técnica de "
     "seguridad, que se borra al cerrar el navegador; no sirve para seguirte.", ""),
    ("privacy_policy", "## Effacer tes données", "## Delete your data", "## Borrar tus datos",
     "Intertitre."),
    ("privacy_policy",
     "Désinstalle Tilto, ou va dans Paramètres Android › Applications › Tilto › Stockage › "
     "Effacer les données.",
     "Uninstall Tilto, or go to Android Settings › Apps › Tilto › Storage › Clear data.",
     "Desinstala Tilto, o ve a Ajustes de Android › Aplicaciones › Tilto › Almacenamiento › "
     "Borrar datos.", "Menus d'Android, à vérifier sur un téléphone dans chaque langue."),
    ("privacy_policy", "## Une question ?", "## Any questions?", "## ¿Alguna pregunta?",
     "Intertitre."),
    ("privacy_policy",
     "Écris-nous avec le formulaire de la page Contact (lien en bas de chaque page). Tilto est "
     "un jeu de Nexora.",
     "Write to us using the form on the Contact page (link at the bottom of every page). Tilto "
     "is a game by Nexora.",
     "Escríbenos con el formulario de la página Contacto (enlace al pie de cada página). Tilto "
     "es un juego de Nexora.", "Texte initial."),
    ("privacy_policy",
     "Écris-nous avec le lien Contact en bas de cette page. Tilto est un jeu de Nexora.",
     "Write to us using the Contact link at the bottom of this page. Tilto is a game by Nexora.",
     "Escríbenos con el enlace Contacto al pie de esta página. Tilto es un juego de Nexora.",
     "Texte en ligne."),
]

_SPACES = re.compile(r"\s+")


def norm(text: str) -> str:
    """Clé de comparaison : espaces insécables et retours à la ligne ramenés à une espace."""
    return _SPACES.sub(" ", (text or "").replace(" ", " ").replace(" ", " ")).strip()


INDEX: dict[str, dict[str, str]] = {}
for _where, _fr, _en, _es, _note in ENTRIES:
    INDEX.setdefault(norm(_fr), {"en": _en, "es": _es})


def translate(text: str, lang: str) -> str | None:
    """Traduction d'un texte français connu, ou None.

    Texte sur plusieurs blocs (politique de confidentialité, notes de version) :
    traduit bloc par bloc (lignes vides) puis ligne par ligne ; None si un seul
    bloc est inconnu (jamais de page à moitié traduite).
    """
    if not (text or "").strip():
        return None
    found = INDEX.get(norm(text))
    if found:
        return found[lang]
    source = text.replace("\r\n", "\n").strip()
    if "\n" not in source:
        return None
    blocks = re.split(r"(\n\s*\n)", source)
    out = []
    for part in blocks:
        if not part.strip():
            out.append("\n\n")
            continue
        found = INDEX.get(norm(part))
        if found:
            out.append(found[lang])
            continue
        lines = part.split("\n")
        translated = [INDEX.get(norm(line)) for line in lines if line.strip()]
        if not translated or any(t is None for t in translated):
            return None
        out.append("\n".join(t[lang] for t in translated))
    return "".join(out)
