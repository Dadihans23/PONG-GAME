# Relecture des traductions

Fichier généré par `python tool/l10n_review.py` depuis `lib/l10n/*.arb` : ne pas le modifier à la main. Pour annoter, ouvrir `relecture.csv` dans un tableur (colonne « Remarques »).

*Generated from `lib/l10n/*.arb` for the English and Spanish reviewers. Please annotate `relecture.csv` (column « Remarques »). The French text is the original; the « Où » column says where the text appears and how long it may be. Glossary: `GLOSSAIRE.md`.*

Conventions : `{name}` est remplacé par une valeur (pseudo, nombre) et ne se traduit pas. `{count, plural, one{…} other{…}}` choisit le singulier ou le pluriel ; `{x, select, …}` choisit une variante. ⍽ marque une espace insécable, à garder.

198 chaînes.

| Clé | Où | FR | EN | ES |
|---|---|---|---|---|
| `commonBack` | Tooltip / screen-reader label of the back arrow in every screen header. Max ~12 chars. | Retour | Back | Atrás |
| `commonEdit` | Small text button next to the nickname (home screen, Settings). Max ~10 chars. | Modifier | Edit | Editar |
| `commonQuit` | Text button: leave the lobby (guest) or the end-of-duel screen; also the "leave" button of the "Leave the duel?" dialog. Max ~12 chars. | Quitter | Quit | Salir |
| `commonSave` | Main button of the nickname dialog (Settings). Shown in capitals. Max ~14 chars. | Enregistrer | Save | Guardar |
| `commonCancel` | Text button closing the nickname dialog without saving. Max ~12 chars. | Annuler | Cancel | Cancelar |
| `commonLabelValue` | Screen-reader text for a statistic tile ("Games played: 12"). Keep the punctuation of your language (French puts a space before the colon). | {label} : {value} | {label}: {value} | {label}: {value} |
| `gaugeProgress` | Screen-reader text for a dot gauge ("2 of 4"): hits made towards the next speed-up, or points in a duel. | {filled} sur {count} | {filled} of {count} | {filled} de {count} |
| `gaugeProgressLabelled` | Screen-reader text for a labelled dot gauge ("Speed 3, 2 of 4"). | {label}, {filled} sur {count} | {label}, {filled} of {count} | {label}, {filled} de {count} |
| `modeSolo` | Name of the single-player mode (vs the computer): home mode card, Statistics section title. Max ~12 chars. | Solo | Solo | Solo |
| `modeMultiplayer` | Name of the local two-phone mode: home mode card, screen title, Statistics and Help section titles. Screen titles are shown in spaced capitals. Max ~14 chars. | Multijoueur | Multiplayer | Multijugador |
| `difficultyEasy` | Difficulty of the computer opponent, on a small button (1/3 of the card width). Also shown in capitals in the game header ("SOLO · EASY"). Max ~9 chars. | Facile | Easy | Fácil |
| `difficultyNormal` | Medium difficulty (see difficultyEasy). Max ~9 chars. | Normal | Normal | Normal |
| `difficultyHard` | Hardest difficulty (see difficultyEasy). Max ~9 chars. | Difficile | Hard | Difícil |
| `splashLoading` | Under the loading bar of the start screen, next to the percentage. Max ~16 chars. | Chargement… | Loading… | Cargando… |
| `splashLoadingLabel` | Screen-reader name of the loading bar (the percentage is read after it). | Chargement | Loading | Cargando |
| `homeSettingsTooltip` | Tooltip / screen-reader label of the gear icon at the top right of the home screen. | Réglages | Settings | Ajustes |
| `homeGreeting` | Home screen greeting with the player nickname (up to 20 chars, shortened with … if needed). | Bonjour, {name} | Hi, {name} | Hola, {name} |
| `homeNicknameRequired` | Error under the nickname field when the player taps Play with an empty nickname. Max ~32 chars. | Choisis un pseudo pour jouer | Choose a nickname to play | Elige un apodo para jugar |
| `nicknameFieldLabel` | Label above the nickname field (home screen) and title of the nickname dialog (Settings). Max ~18 chars. | Ton pseudo | Your nickname | Tu apodo |
| `nicknameFieldHint` | Placeholder inside the empty nickname field. Max ~24 chars. | Entre ton pseudo | Enter your nickname | Escribe tu apodo |
| `homeGameModeTitle` | Small section title above the Solo and Multiplayer cards, shown in spaced capitals. Max ~16 chars. | Mode de jeu | Game mode | Modo de juego |
| `homeSoloSubtitle` | Subtitle of the selected Solo card. Max ~24 chars. | Contre l'ordinateur | Against the computer | Contra la máquina |
| `homeSoloSubtitleWithDifficulty` | Subtitle of the Solo card when it is not selected: reminds the chosen difficulty. Max ~34 chars. | Contre l'ordinateur · {difficulty} | Against the computer · {difficulty} | Contra la máquina · {difficulty} |
| `homeChooseDifficulty` | Line above the three difficulty buttons in the Solo card. Max ~26 chars. | Choisis la difficulté | Pick a difficulty | Elige la dificultad |
| `bestScore` | Best solo score: line at the bottom of the Solo card (home) and tile title in Statistics (half the screen width). Max ~16 chars. | Meilleur score | High score | Mejor puntuación |
| `bestScoreValue` | Screen-reader text of the high score line (home). | Meilleur score : {score} | High score: {score} | Mejor puntuación: {score} |
| `homeMultiplayerSubtitle` | Subtitle of the Multiplayer card on the home screen. Keep "Wi‑Fi" with its non-breaking hyphen. Max ~28 chars. | À deux, même Wi‑Fi | Two players, same Wi‑Fi | Para dos, mismo Wi‑Fi |
| `homeMultiplayerDetail` | Text inside the selected Multiplayer card (home). Up to 3 lines. | Duel en {points} points, chacun sur son téléphone. Pas besoin d'Internet. | First to {points} points, each on your own phone. No internet needed. | Duelo a {points} puntos, cada uno en su teléfono. No hace falta internet. |
| `homeDuelRecord` | Line at the bottom of the Multiplayer card, followed by "3 / 1". Max ~22 chars. | Victoires / défaites | Wins / losses | Victorias / derrotas |
| `duelRecordSemantics` | Screen-reader text of the duel record line (home). | Victoires : {wins}, défaites : {losses} | Wins: {wins}, losses: {losses} | Victorias: {wins}, derrotas: {losses} |
| `homePlay` | Main pink button of the home screen (starts the selected mode); also on the empty leaderboard. Shown in capitals. Max ~14 chars. | Jouer | Play | Jugar |
| `leaderboardTitle` | Leaderboard (top 10 solo scores): screen title in spaced capitals, home shortcut tile (1/3 of the width) and button on the game-over card. Max ~13 chars. | Classement | Leaderboard | Clasificación |
| `statisticsTitle` | Statistics: screen title in spaced capitals, home shortcut tile (1/3 of the width) and button on the game-over card. Max ~13 chars. | Statistiques | Statistics | Estadísticas |
| `helpTitle` | Help screen: title and home shortcut tile. Max ~10 chars. | Aide | Help | Ayuda |
| `hudSoloMode` | Game header before the first tap, shown in capitals ("SOLO · NORMAL"). | Solo · {difficulty} | Solo · {difficulty} | Solo · {difficulty} |
| `hudSpeed` | Game header during play, next to 4 dots, shown in capitals: current ball speed level. Max ~14 chars. | Vitesse {level} | Speed {level} | Velocidad {level} |
| `pauseTooltip` | Tooltip / screen-reader label of the pause button (top right during a solo game). | Pause | Pause | Pausa |
| `courtTapToStart` | Big instruction in the middle of the court before a solo game starts, in spaced capitals (font 20). Max ~16 chars. | Tape l'écran | Tap to start | Toca para jugar |
| `courtTiltHint` | Hint under "Tap the screen": the paddle is moved by tilting the phone. One line, max ~34 chars. | Incline le téléphone pour bouger | Tilt your phone to move | Inclina el teléfono para moverte |
| `courtRecord` | Previous high score shown on the court, in spaced capitals ("RECORD 2 400"). Max ~16 chars. | Record {score} | Best {score} | Récord {score} |
| `courtNewRecord` | Gold badge on the court when the player beats the high score during a game. Max ~16 chars. | Nouveau record | New high score | Nuevo récord |
| `pauseTitle` | Title of the pause overlay, very big spaced capitals. Max ~8 chars. | Pause | Paused | Pausa |
| `pauseScore` | Under the pause title when there is no high score yet. | Score {score} | Score {score} | Puntos {score} |
| `pauseScoreAndRecord` | Under the pause title: current score and high score. One line, max ~32 chars. | Score {score} · Record {record} | Score {score} · Best {record} | Puntos {score} · Récord {record} |
| `pauseResume` | Main button of the pause overlay, in capitals. Max ~14 chars. | Reprendre | Resume | Continuar |
| `pauseQuit` | Text button of the pause overlay: back to the home screen, the game is not counted. Max ~22 chars. | Quitter la partie | Quit game | Salir de la partida |
| `gameOverTitle` | Small spaced capitals at the top of the game-over card (not a record). Max ~18 chars. | Partie terminée | Game over | Fin de la partida |
| `gameOverNewRecord` | Gold badge at the top of the game-over card when the high score was beaten. Max ~18 chars. | Nouveau record ! | New high score! | ¡Nuevo récord! |
| `gameOverPoints` | Under the big final score of the game-over card (no high score yet). | points | points | puntos |
| `gameOverPointsWithRecord` | Under the big final score: reminds the high score. | points · record {record} | points · best {record} | puntos · récord {record} |
| `gameOverPointsOverRecord` | Under the big final score of a record game; {gain} is shown in gold ("+250"). Max ~40 chars. | points · {gain} sur l'ancien record | points · {gain} over your old best | puntos · {gain} sobre tu récord anterior |
| `gameOverHits` | Label under the number of times the player hit the ball (small tile, 1/3 of the card). Only the word: the number is displayed above it. Max ~10 chars. | {count, plural, one{renvoi} other{renvois}} | {count, plural, one{hit} other{hits}} | {count, plural, one{golpe} other{golpes}} |
| `gameOverDuration` | Label under the game duration ("3m 20s") on the game-over card (small tile). Max ~10 chars. | durée | time | tiempo |
| `gameOverRank` | Label under the leaderboard position ("2nd") on the game-over card of a record game (small tile). Max ~10 chars. | classement | rank | puesto |
| `gameOverTopSpeed` | Label under the highest speed level reached (small tile, 1/3 of the card). Max ~11 chars. | vitesse max | top speed | vel. máxima |
| `gameOverReplay` | Main pink button of the solo game-over card, in capitals. Max ~16 chars. | Rejouer | Play again | Jugar otra vez |
| `gameOverHome` | Text button at the bottom of the game-over card. Max ~22 chars. | Retour à l'accueil | Back to home | Volver al inicio |
| `rankOrdinal` | Leaderboard position, 1 to 10 only ("1" to "10"): game-over tile and screen-reader text of the leaderboard. Short ordinal; keep "{rank, select, ... other{...}}" (one case per number that needs a special form). | {rank, select, 1{1er} other{{rank}e}} | {rank, select, 1{1st} 2{2nd} 3{3rd} other{{rank}th}} | {rank, select, other{{rank}.º}} |
| `leaderboardEmptyTitle` | Title of the empty leaderboard. Max ~26 chars. | Aucun score enregistré | No scores yet | Aún no hay puntuaciones |
| `leaderboardEmptyMessage` | Text of the empty leaderboard, under the title. | Joue une partie solo : tes {count} meilleurs scores apparaîtront ici. | Play a solo game: your top {count} scores will show up here. | Juega una partida en solitario: tus {count} mejores puntuaciones aparecerán aquí. |
| `leaderboardRowSemantics` | Screen-reader text of a leaderboard row without a date. {rank} is an ordinal ("4th"). | {rank}, {name}, {score} points | {rank}, {name}, {score} points | {rank}, {name}, {score} puntos |
| `leaderboardRowSemanticsWithDate` | Screen-reader text of a leaderboard row with the game date. | {rank}, {name}, {score} points, le {date} | {rank}, {name}, {score} points, on {date} | {rank}, {name}, {score} puntos, el {date} |
| `leaderboardUnknownPlayer` | Shown instead of a nickname when an old leaderboard entry has none. | Inconnu | Unknown | Desconocido |
| `statsSoloEmpty` | Hint under the Solo section title while no game has been played. | Joue ta première partie pour remplir ces chiffres. | Play your first game to fill in these numbers. | Juega tu primera partida para llenar estas cifras. |
| `statsGamesPlayed` | Statistics tile title (half the screen width). Max ~16 chars. | Parties jouées | Games played | Partidas jugadas |
| `statsTotalTime` | Statistics row title, followed by a duration on the right ("7m 29s"). Max ~22 chars. | Temps total de jeu | Total play time | Tiempo total de juego |
| `statsBestStreak` | Statistics row title: most hits in a row in one solo game, followed by "23 hits". Max ~18 chars. | Meilleure série | Best streak | Mejor racha |
| `hitsCount` | Number of hits (times a paddle sent the ball back). Keep the non-breaking space after {countText}. {countText} is {count} already formatted ("1 234"). Used for the best streak (Statistics) and the longest rally (end of duel). | {count, plural, one{{countText}⍽renvoi} other{{countText}⍽renvois}} | {count, plural, one{{countText}⍽hit} other{{countText}⍽hits}} | {count, plural, one{{countText}⍽golpe} other{{countText}⍽golpes}} |
| `statsMultiplayerEmpty` | Hint under the Multiplayer section title while no duel has been played. | Joue ton premier duel pour remplir ces chiffres. | Play your first duel to fill in these numbers. | Juega tu primer duelo para llenar estas cifras. |
| `statsWins` | Small label above the number of duels won (Statistics). Max ~12 chars. | Victoires | Wins | Victorias |
| `statsLosses` | Small label above the number of duels lost (Statistics). Max ~12 chars. | Défaites | Losses | Derrotas |
| `duelsCount` | Total number of duels played, between wins and losses (Statistics). {countText} is {count} already formatted. | {count, plural, one{{countText}⍽duel} other{{countText}⍽duels}} | {count, plural, one{{countText}⍽duel} other{{countText}⍽duels}} | {count, plural, one{{countText}⍽duelo} other{{countText}⍽duelos}} |
| `statsDuelSemantics` | Screen-reader text of the duel record card; {duels} is the duelsCount text ("19 duels"). | Victoires : {wins}, défaites : {losses}, {duels} | Wins: {wins}, losses: {losses}, {duels} | Victorias: {wins}, derrotas: {losses}, {duels} |
| `helpControlsTitle` | Help card title. Max ~16 chars. | Contrôles | Controls | Controles |
| `helpControlsText` | Help card text: how to control the paddle. | Incline le téléphone à gauche ou à droite pour déplacer ta raquette. | Tilt your phone left or right to move your paddle. | Inclina el teléfono a la izquierda o a la derecha para mover tu paleta. |
| `helpGoalTitle` | Help card title. Max ~16 chars. | Objectif | Goal | Objetivo |
| `helpGoalText` | Help card text: the aim of a solo game. | Renvoie la balle le plus longtemps possible. Si elle passe derrière toi, c'est fini. | Keep the ball in play as long as you can. If it gets past you, it's over. | Devuelve la pelota el mayor tiempo posible. Si pasa detrás de ti, se acabó. |
| `helpPointsTitle` | Help card title. Max ~16 chars. | Points | Points | Puntos |
| `helpPointsText` | Help card text: scoring (50 points per hit, 100 when the computer misses). | +50 par renvoi, +100 quand l'adversaire rate. | +50 per hit, +100 when your opponent misses. | +50 por golpe, +100 cuando el rival falla. |
| `helpSpeedTitle` | Help card title. Max ~16 chars. | Vitesse | Speed | Velocidad |
| `helpSpeedText` | Help card text: the ball gets faster every 4 hits. | La balle accélère tous les 4 renvois. | The ball speeds up every 4 hits. | La pelota acelera cada 4 golpes. |
| `helpPauseTitle` | Help card title. Max ~16 chars. | Pause | Pause | Pausa |
| `helpPauseText` | Help card text: how to pause. | Touche le bouton pause en haut à droite. Pas de pause en multijoueur. | Tap the pause button at the top right. No pausing in multiplayer. | Toca el botón de pausa arriba a la derecha. En multijugador no hay pausa. |
| `helpMultiplayerText` | Help card text: how a local duel works (two phones on the same network, no internet). | Connectez-vous au même Wi‑Fi (ou au partage de connexion de l'un de vous). L'un crée la partie, l'autre la rejoint. Premier à 5 points. | Connect both phones to the same Wi‑Fi (or to one player's hotspot). One creates the game, the other joins it. First to 5 points wins. | Los dos teléfonos deben estar en el mismo Wi‑Fi (o en el punto de acceso de uno de los dos). Uno crea la partida y el otro se une. Gana el primero en llegar a 5 puntos. |
| `settingsTitle` | Settings screen title, in spaced capitals. Max ~13 chars. | Réglages | Settings | Ajustes |
| `settingsSoundSection` | Settings section title, spaced capitals. Max ~14 chars. | Son | Sound | Sonido |
| `settingsMusic` | Switch title (Settings). Max ~20 chars. | Musique | Music | Música |
| `settingsMusicSubtitle` | Under "Music": where music plays. Max ~26 chars. | Accueil et pause | Home and pause | Inicio y pausa |
| `settingsEffects` | Switch title (Settings). Max ~20 chars. | Effets sonores | Sound effects | Efectos sonoros |
| `settingsEffectsSubtitle` | Under "Sound effects": examples of sounds. Max ~28 chars. | Renvois, record, défaite | Hits, high score, loss | Golpes, récord, derrota |
| `settingsGameSection` | Settings section title, spaced capitals. Max ~14 chars. | Jeu | Game | Juego |
| `settingsVibration` | Switch title (Settings). Max ~20 chars. | Vibration | Vibration | Vibración |
| `settingsVibrationSubtitle` | Under "Vibration": when the phone vibrates. Max ~28 chars. | Au renvoi et au record | On hits and high scores | En golpes y récords |
| `settingsSensitivity` | Title of the paddle sensitivity slider (0 to 100) and its screen-reader name. Max ~16 chars. | Sensibilité | Sensitivity | Sensibilidad |
| `settingsSensitivityHint` | Explains the sensitivity slider. Must match the words of the slider ends (settingsSensitivityLow / High). | Plus vive : la raquette va plus vite et demande moins d'inclinaison. | Higher: the paddle moves faster and needs less tilt. | Más alta: la paleta va más rápido y necesita menos inclinación. |
| `settingsSensitivityLow` | Left end of the sensitivity slider (value 0). Max ~8 chars. | Douce | Low | Baja |
| `settingsSensitivityHigh` | Right end of the sensitivity slider (value 100). Max ~8 chars. | Vive | High | Alta |
| `settingsTrialZone` | Above a small strip where a paddle follows the phone tilt with the chosen sensitivity. One line, max ~36 chars. | Zone d'essai · penche ton téléphone | Try it · tilt your phone | Pruébalo · inclina tu teléfono |
| `settingsLanguageSection` | Settings section title, spaced capitals. Max ~14 chars. | Langue | Language | Idioma |
| `settingsLanguageAutomatic` | Language choice that follows the phone language (button, 1/2 of the card width). The other choices are the language names, never translated (Français, English, Español). Max ~12 chars. | Automatique | Automatic | Automático |
| `settingsLanguageAutomaticHint` | Under the language buttons when "Automatic" is selected; {language} is the language the app uses now, in its own name ("English"): the phone language if the app speaks it, otherwise English. | Selon ton téléphone : {language} | Based on your phone: {language} | Según tu teléfono: {language} |
| `settingsProfileSection` | Settings section title, spaced capitals. Max ~14 chars. | Profil | Profile | Perfil |
| `settingsNickname` | Small label above the nickname (Settings). Max ~14 chars. | Pseudo | Nickname | Apodo |
| `settingsNicknameNone` | Shown instead of the nickname when none is saved. | Aucun | None | Ninguno |
| `settingsNicknameChoose` | Text button when no nickname is saved yet. Max ~10 chars. | Choisir | Choose | Elegir |
| `settingsVersion` | Small line at the bottom of Settings and of the Studio page ("Tilto · version 1.1.0"). Do not translate {game}. | {game} · version {version} | {game} · version {version} | {game} · versión {version} |
| `nicknameDialogMessage` | Text of the nickname dialog (Settings), under the title. | Il apparaît dans le classement. | It shows on the leaderboard. | Aparece en la clasificación. |
| `nicknameDialogRequired` | Error under the field of the nickname dialog when it is empty. | Choisis un pseudo | Choose a nickname | Elige un apodo |
| `studioTitle` | Title of the page about the studio that made the game, in spaced capitals. Max ~13 chars. | Le studio | The studio | El estudio |
| `studioIntro` | First sentence of the Studio page; {studio} is shown in bold. Do not translate {game} or {studio}. | {game} est un jeu de {studio}. | {game} is a game by {studio}. | {game} es un juego de {studio}. |
| `studioVisitWebsite` | Button opening the studio website in the browser, in capitals. Max ~22 chars. | Visiter le site | Visit the website | Visitar el sitio web |
| `studioContact` | Text button opening the contact page in the browser. Max ~22 chars. | Écrire au studio | Contact the studio | Escribir al estudio |
| `studioLinkFailed` | Message at the bottom of the screen when the browser cannot be opened; {host} is a web address ("tilto.fun"). | Le lien ne s'ouvre pas. Va sur {host} depuis ton navigateur. | The link won't open. Go to {host} in your browser. | El enlace no se abre. Entra en {host} desde tu navegador. |
| `studioSignaturePrefix` | Small signature at the bottom of Settings and Help, followed by the studio logo: "A game by [logo]". Max ~14 chars. | Un jeu de | A game by | Un juego de |
| `studioSignatureSemantics` | Screen-reader text of the signature (the logo is read as the studio name). | Un jeu de {studio} | A game by {studio} | Un juego de {studio} |
| `studioSignatureLink` | Screen-reader text of the signature when it opens the Studio page. | Le studio, {studio} | The studio, {studio} | El estudio, {studio} |
| `mpPlayingAs` | Top of the multiplayer menu; {name} (the nickname) is shown in bold. One line. | Tu joues en tant que {name} | You're playing as {name} | Juegas como {name} |
| `mpCreateTitle` | Big card of the multiplayer menu: host a duel. Also quoted in joinTipCreate. Max ~22 chars. | Créer une partie | Create a game | Crear una partida |
| `mpCreateSubtitle` | Under "Create a game". | Ton ami la rejoint depuis son téléphone. | Your friend joins from their phone. | Tu amigo se une desde su teléfono. |
| `mpJoinTitle` | Big card of the multiplayer menu: find a game nearby. Max ~22 chars. | Rejoindre une partie | Join a game | Unirse a una partida |
| `mpJoinSubtitle` | Under "Join a game". | Trouve la partie d'un ami à proximité. | Find a friend's game nearby. | Busca la partida de un amigo cercano. |
| `mpNetworkHint` | Reminder at the bottom of the multiplayer menu: both phones must be on the same local network. | Soyez sur le même Wi‑Fi, ou connecte-toi au partage de connexion de l'autre. Pas besoin d'Internet. | Be on the same Wi‑Fi, or connect to the other player's hotspot. No internet needed. | Los dos deben estar en el mismo Wi‑Fi, o conéctate al punto de acceso del otro jugador. No hace falta internet. |
| `joinTitle` | Title of the "find a game" screen, spaced capitals. Max ~13 chars. | Rejoindre | Join | Unirse |
| `joinRefresh` | Button: search for games again, in capitals. Max ~14 chars. | Actualiser | Refresh | Actualizar |
| `joinSearching` | Big text under the radar animation while searching. Max ~24 chars. | Recherche de parties… | Looking for games… | Buscando partidas… |
| `joinSearchingHint` | Under "Looking for games…". | Reste près de l'autre joueur, sur le même Wi‑Fi. | Stay close to the other player, on the same Wi‑Fi. | Quédate cerca del otro jugador, en el mismo Wi‑Fi. |
| `joinNoGame` | Title when the search found nothing. Max ~26 chars. | Aucune partie trouvée | No games found | No se encontraron partidas |
| `joinTipNetwork` | First numbered tip when no game is found. | Vérifie que vous êtes sur le même Wi‑Fi ou partage de connexion. | Check that you're both on the same Wi‑Fi or hotspot. | Comprueba que ambos teléfonos estén en el mismo Wi‑Fi o punto de acceso. |
| `joinTipCreate` | Second numbered tip when no game is found; {action} is the mpCreateTitle text. Use the quotation marks of your language. | Demande à l'autre joueur de toucher « {action} ». | Ask the other player to tap “{action}”. | Pide al otro jugador que toque «{action}». |
| `joinGamesNearby` | Status line above the list of games found. One line with joinStillSearching. | {count, plural, one{{count} partie à proximité} other{{count} parties à proximité}} | {count, plural, one{{count} game nearby} other{{count} games nearby}} | {count, plural, one{{count} partida cercana} other{{count} partidas cercanas}} |
| `joinStillSearching` | Status line while the search goes on; {found} is the joinGamesNearby text. One line, max ~40 chars. | {found} · recherche en cours | {found} · searching | {found} · buscando |
| `joinGameFull` | Grey badge instead of the Join button when a game already has 2 players. Max ~10 chars. | Complète | Full | Llena |
| `joinJoin` | Small pink button on a game row. Max ~10 chars. | Rejoindre | Join | Unirse |
| `joinPlayers` | Under the game name in the list ("1 / 2 players"). | {count} / {max} joueurs | {count} / {max} players | {count} / {max} jugadores |
| `joinConnecting` | Replaces the Join button while connecting. Max ~12 chars. | Connexion… | Connecting… | Conectando… |
| `gameOf` | Name of a game, after the nickname of the player who created it. {elision} is only for French ("d'Inès" before a vowel): keep "{elision, select, other{...}}" around your text. | {elision, select, yes{Partie d'{name}} other{Partie de {name}}} | {elision, select, other{{name}'s game}} | {elision, select, other{Partida de {name}}} |
| `gameOfOpponent` | Name of a game when the host nickname is unknown (rare). | Partie de ton adversaire | Your opponent's game | Partida de tu rival |
| `lobbyTitle` | Title of the waiting room before a duel, spaced capitals. Max ~13 chars. | Salon | Lobby | Sala |
| `lobbyDuelFormat` | Under the game name in the lobby. | Duel · premier à {points} points | Duel · first to {points} points | Duelo a {points} puntos |
| `lobbyYouHost` | Under my nickname in the lobby, when I created the game. Max ~20 chars. | Toi · hôte | You · host | Tú · anfitrión |
| `lobbyYou` | Under my nickname in the lobby, when I joined the game. | Toi | You | Tú |
| `lobbyHost` | Under the other nickname: the player who created the game. | Hôte | Host | Anfitrión |
| `lobbyGuest` | Under the other nickname: the player who joined my game. | Invité | Guest | Invitado |
| `lobbyJustJoined` | Under the other nickname right after they joined. Max ~20 chars. | Vient de rejoindre | Just joined | Acaba de unirse |
| `lobbyReadyStatus` | Green badge on a player row: this player is ready. Max ~10 chars. | Prêt | Ready | Listo |
| `lobbyWaitingStatus` | Grey badge on a player row: not ready yet. Max ~12 chars. | En attente | Waiting | Esperando |
| `lobbyWaitingForPlayer` | Empty slot of the lobby while nobody has joined. One line. | En attente d'un joueur… | Waiting for a player… | Esperando a un jugador… |
| `lobbyVisible` | Under the radar animation while the host waits alone. | Ta partie est visible par les joueurs à proximité. | Players nearby can see your game. | Los jugadores cercanos pueden ver tu partida. |
| `lobbyHintAlone` | Above the disabled Ready button while the host is alone. | Disponible dès qu'un joueur te rejoint | Available as soon as someone joins | Disponible cuando alguien se una |
| `lobbyHintOtherReady` | Above the Ready button when the other player is already ready. | {name} t'attend. À toi ! | {name} is waiting for you. Your move! | {name} te está esperando. ¡Te toca! |
| `lobbyHintBothReady` | Above the Ready button when nobody is ready yet. | La partie démarre quand vous êtes prêts tous les deux | The game starts when you're both ready | La partida empieza cuando los dos estén listos |
| `waitingFor` | Lobby hint and pending button: waiting for the other player. {elision} is only for French: keep "{elision, select, other{...}}" around your text. Max ~30 chars. | {elision, select, yes{En attente d'{name}…} other{En attente de {name}…}} | {elision, select, other{Waiting for {name}…}} | {elision, select, other{Esperando a {name}…}} |
| `waitingForOpponent` | Same as waitingFor when the nickname is unknown (rare). | En attente de ton adversaire… | Waiting for your opponent… | Esperando a tu rival… |
| `lobbyReady` | Main pink button of the lobby, in capitals: I am ready to play. Max ~14 chars. | Prêt | Ready | Listo |
| `lobbyNotReady` | Secondary button replacing Ready once tapped (cancels it), in capitals. Max ~22 chars. | Je ne suis plus prêt | I'm not ready | Ya no estoy listo |
| `lobbyCancelGame` | Text button for the host: close the game. Max ~20 chars. | Annuler la partie | Cancel game | Cancelar partida |
| `countdownVersus` | Between the two nicknames above the 3-2-1 countdown, in capitals ("LÉA  VS  TOM"). | contre | vs | contra |
| `countdownGrabPhone` | Under the 3-2-1 countdown, in spaced capitals. Max ~22 chars. | Prends ton téléphone | Grab your phone | Toma tu teléfono |
| `countdownHint` | Small line at the bottom of the countdown. One line, max ~38 chars. | À deux mains, prêt à incliner | Both hands, ready to tilt | Con las dos manos, listo para inclinar |
| `duelHudFormat` | Duel header, in capitals ("DUEL · FIRST TO 5"). Max ~26 chars. | Duel · premier à {points} | Duel · first to {points} | Duelo a {points} puntos |
| `duelConnectionWeak` | Red warning in the duel header when the network is slow. Max ~16 chars. | Connexion faible | Weak connection | Conexión débil |
| `duelConnectionGood` | Screen-reader text of the Wi-Fi icon in the duel header when all is fine. | Bonne connexion | Good connection | Buena conexión |
| `duelScoreSemantics` | Screen-reader text of the duel score ("Léa 3, Tom 2"). | {myName} {myScore}, {opponentName} {opponentScore} | {myName} {myScore}, {opponentName} {opponentScore} | {myName} {myScore}, {opponentName} {opponentScore} |
| `duelPointFor` | Badge in the middle of the court right after a point. Max ~24 chars with the name. | Point pour {name} | Point for {name} | Punto para {name} |
| `duelResumeIn` | Under the score after a point, counting down the seconds before the next serve. | Reprise dans {seconds}… | Resuming in {seconds}… | Seguimos en {seconds}… |
| `resultVictory` | Big spaced capitals title of the end-of-duel screen (winner). Max ~10 chars. | Victoire | Victory | Victoria |
| `resultDefeat` | Big spaced capitals title of the end-of-duel screen (loser). Max ~10 chars. | Défaite | Defeat | Derrota |
| `resultWinner` | Under the title of the end-of-duel screen. | {name} gagne ! | {name} wins! | ¡{name} gana! |
| `resultDetail` | Under the final score after a win; {duration} looks like "2m 14s", {rally} is the hitsCount text ("14 hits"). | {duration} · plus long échange : {rally} | {duration} · longest rally: {rally} | {duration} · intercambio más largo: {rally} |
| `resultCloseLoss` | Under the final score after a narrow loss (by 1 or 2 points). | Si près ! La revanche ? | So close! Rematch? | ¡Casi! ¿La revancha? |
| `resultLoss` | Under the final score after a clear loss. | La revanche ? | Rematch? | ¿La revancha? |
| `rematchIAsked` | Status line above the buttons once I asked for a rematch. | Tu veux rejouer · {name} n'a pas encore répondu | Rematch requested · {name} hasn't answered yet | Revancha pedida · {name} aún no responde |
| `rematchOpponentAsked` | Status line when the other player asked for a rematch. | {name} veut rejouer | {name} wants a rematch | {name} quiere la revancha |
| `opponentLeftGame` | End-of-duel status line and incident title: the other player left. | {name} a quitté la partie | {name} left the game | {name} salió de la partida |
| `resultRematch` | Main pink button of the end-of-duel screen (ask for or accept a rematch), in capitals. Max ~16 chars. | Rejouer | Rematch | Revancha |
| `incidentOpponentLostTitle` | Dialog title (host side): the guest phone is gone. | Connexion perdue avec {name} | Lost connection with {name} | Se perdió la conexión con {name} |
| `incidentOpponentLostMessage` | Dialog text under incidentOpponentLostTitle. | Ta partie reste ouverte : {name} peut la rejoindre à nouveau. | Your game is still open: {name} can join again. | Tu partida sigue abierta: {name} puede volver a unirse. |
| `incidentBackToLobby` | Dialog button, in capitals. Max ~20 chars. | Retour au salon | Back to lobby | Volver a la sala |
| `incidentHostLeftMessage` | Dialog text (guest side) when the host left on purpose. | La partie est terminée. Tu peux en rejoindre une autre ou créer la tienne. | The game is over. You can join another one or create your own. | La partida terminó. Puedes unirte a otra o crear la tuya. |
| `incidentBackToMenu` | Dialog button, in capitals. Max ~20 chars. | Retour au menu | Back to menu | Volver al menú |
| `incidentConnectionLostTitle` | Dialog title (guest side): the host stopped answering. | Connexion perdue | Connection lost | Conexión perdida |
| `incidentConnectionLostMessage` | Dialog text under incidentConnectionLostTitle. | {name} ne répond plus. Vérifie que vous êtes toujours sur le même Wi‑Fi. | {name} isn't responding. Check that you're both still on the same Wi‑Fi. | {name} no responde. Comprueba que ambos teléfonos sigan en el mismo Wi‑Fi. |
| `incidentConnectionFailedTitle` | Dialog title: joining a game failed. | Connexion impossible | Couldn't connect | No se pudo conectar |
| `incidentConnectionFailedMessage` | Dialog text under incidentConnectionFailedTitle. | Vérifie que vous êtes sur le même Wi‑Fi, puis réessaie. | Check that you're both on the same Wi‑Fi, then try again. | Comprueba que ambos teléfonos estén en el mismo Wi‑Fi y vuelve a intentarlo. |
| `incidentRetry` | Dialog button, in capitals. Max ~16 chars. | Réessayer | Try again | Reintentar |
| `incidentBack` | Dialog text button (go back). Max ~12 chars. | Retour | Back | Volver |
| `incidentGameFullTitle` | Dialog title: the game already has 2 players. | Partie complète | Game full | Partida llena |
| `incidentGameFullMessage` | Dialog text under incidentGameFullTitle. | {name} joue déjà avec quelqu'un. Choisis une autre partie ou crée la tienne. | {name} is already playing with someone. Pick another game or create your own. | {name} ya está jugando con alguien. Elige otra partida o crea la tuya. |
| `incidentBackToList` | Dialog button, in capitals. Max ~20 chars. | Retour à la liste | Back to the list | Volver a la lista |
| `incidentNoWifiTitle` | Dialog title: the phone is on no local network. | Pas de Wi‑Fi | No Wi‑Fi | Sin Wi‑Fi |
| `incidentNoWifiMessage` | Dialog text under incidentNoWifiTitle. | Connecte-toi à un Wi‑Fi ou au partage de connexion de l'autre joueur, puis réessaie. | Connect to a Wi‑Fi network or the other player's hotspot, then try again. | Conéctate a una red Wi‑Fi o al punto de acceso del otro jugador y vuelve a intentarlo. |
| `incidentLeaveDuelTitle` | Confirmation dialog title after the Android back button during a duel. | Quitter le duel ? | Leave the duel? | ¿Salir del duelo? |
| `incidentLeaveDuelMessage` | Confirmation dialog text. | Le duel s'arrête pour {name} aussi. | The duel will end for {name} too. | El duelo también terminará para {name}. |
| `incidentKeepPlaying` | Main button of the leave confirmation (the safe choice), in capitals. Max ~20 chars. | Continuer le duel | Keep playing | Seguir jugando |
| `incidentVersionTitle` | Dialog title: the two phones have different app versions. | Versions différentes | Different versions | Versiones diferentes |
| `incidentVersionMessage` | Dialog text under incidentVersionTitle. | Installe la même version du jeu sur les deux téléphones, puis réessaie. | Install the same version of the game on both phones, then try again. | Instala la misma versión del juego en los dos teléfonos y vuelve a intentarlo. |
| `incidentClosedTitle` | Dialog title: the duel stopped because the app went to the background. | Partie fermée | Game closed | Partida cerrada |
| `incidentClosedMessage` | Dialog text under incidentClosedTitle. | La partie s'arrête quand le jeu passe en arrière-plan. Tu peux en créer ou en rejoindre une autre. | The game stops when the app goes to the background. You can create or join another one. | La partida se detiene cuando el juego pasa a segundo plano. Puedes crear otra o unirte a una. |
