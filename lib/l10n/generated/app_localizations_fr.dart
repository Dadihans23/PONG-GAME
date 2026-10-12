// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonBack => 'Retour';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonQuit => 'Quitter';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String commonLabelValue(String label, String value) {
    return '$label : $value';
  }

  @override
  String gaugeProgress(int filled, int count) {
    return '$filled sur $count';
  }

  @override
  String gaugeProgressLabelled(String label, int filled, int count) {
    return '$label, $filled sur $count';
  }

  @override
  String get modeSolo => 'Solo';

  @override
  String get modeMultiplayer => 'Multijoueur';

  @override
  String get difficultyEasy => 'Facile';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Difficile';

  @override
  String get splashLoading => 'Chargement…';

  @override
  String get splashLoadingLabel => 'Chargement';

  @override
  String get homeSettingsTooltip => 'Réglages';

  @override
  String homeGreeting(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get homeNicknameRequired => 'Choisis un pseudo pour jouer';

  @override
  String get nicknameFieldLabel => 'Ton pseudo';

  @override
  String get nicknameFieldHint => 'Entre ton pseudo';

  @override
  String get homeGameModeTitle => 'Mode de jeu';

  @override
  String get homeSoloSubtitle => 'Contre l\'ordinateur';

  @override
  String homeSoloSubtitleWithDifficulty(String difficulty) {
    return 'Contre l\'ordinateur · $difficulty';
  }

  @override
  String get homeChooseDifficulty => 'Choisis la difficulté';

  @override
  String get bestScore => 'Meilleur score';

  @override
  String bestScoreValue(String score) {
    return 'Meilleur score : $score';
  }

  @override
  String get homeMultiplayerSubtitle => 'À deux, même Wi‑Fi';

  @override
  String homeMultiplayerDetail(int points) {
    return 'Duel en $points points, chacun sur son téléphone. Pas besoin d\'Internet.';
  }

  @override
  String get homeDuelRecord => 'Victoires / défaites';

  @override
  String duelRecordSemantics(int wins, int losses) {
    return 'Victoires : $wins, défaites : $losses';
  }

  @override
  String get homePlay => 'Jouer';

  @override
  String get leaderboardTitle => 'Classement';

  @override
  String get statisticsTitle => 'Statistiques';

  @override
  String get helpTitle => 'Aide';

  @override
  String hudSoloMode(String difficulty) {
    return 'Solo · $difficulty';
  }

  @override
  String hudSpeed(int level) {
    return 'Vitesse $level';
  }

  @override
  String get pauseTooltip => 'Pause';

  @override
  String get courtTapToStart => 'Tape l\'écran';

  @override
  String get courtTiltHint => 'Incline le téléphone pour bouger';

  @override
  String courtRecord(String score) {
    return 'Record $score';
  }

  @override
  String get courtNewRecord => 'Nouveau record';

  @override
  String get pauseTitle => 'Pause';

  @override
  String pauseScore(String score) {
    return 'Score $score';
  }

  @override
  String pauseScoreAndRecord(String score, String record) {
    return 'Score $score · Record $record';
  }

  @override
  String get pauseResume => 'Reprendre';

  @override
  String get pauseQuit => 'Quitter la partie';

  @override
  String get gameOverTitle => 'Partie terminée';

  @override
  String get gameOverNewRecord => 'Nouveau record !';

  @override
  String get gameOverPoints => 'points';

  @override
  String gameOverPointsWithRecord(String record) {
    return 'points · record $record';
  }

  @override
  String gameOverPointsOverRecord(String gain) {
    return 'points · $gain sur l\'ancien record';
  }

  @override
  String gameOverHits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'renvois',
      one: 'renvoi',
    );
    return '$_temp0';
  }

  @override
  String get gameOverDuration => 'durée';

  @override
  String get gameOverRank => 'classement';

  @override
  String get gameOverTopSpeed => 'vitesse max';

  @override
  String get gameOverReplay => 'Rejouer';

  @override
  String get gameOverHome => 'Retour à l\'accueil';

  @override
  String rankOrdinal(String rank) {
    String _temp0 = intl.Intl.selectLogic(
      rank,
      {
        '1': '1er',
        'other': '${rank}e',
      },
    );
    return '$_temp0';
  }

  @override
  String get leaderboardEmptyTitle => 'Aucun score enregistré';

  @override
  String leaderboardEmptyMessage(int count) {
    return 'Joue une partie solo : tes $count meilleurs scores apparaîtront ici.';
  }

  @override
  String leaderboardRowSemantics(String rank, String name, String score) {
    return '$rank, $name, $score points';
  }

  @override
  String leaderboardRowSemanticsWithDate(String rank, String name, String score, String date) {
    return '$rank, $name, $score points, le $date';
  }

  @override
  String get leaderboardUnknownPlayer => 'Inconnu';

  @override
  String get statsSoloEmpty => 'Joue ta première partie pour remplir ces chiffres.';

  @override
  String get statsGamesPlayed => 'Parties jouées';

  @override
  String get statsTotalTime => 'Temps total de jeu';

  @override
  String get statsBestStreak => 'Meilleure série';

  @override
  String hitsCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText renvois',
      one: '$countText renvoi',
    );
    return '$_temp0';
  }

  @override
  String get statsMultiplayerEmpty => 'Joue ton premier duel pour remplir ces chiffres.';

  @override
  String get statsWins => 'Victoires';

  @override
  String get statsLosses => 'Défaites';

  @override
  String duelsCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText duels',
      one: '$countText duel',
    );
    return '$_temp0';
  }

  @override
  String statsDuelSemantics(int wins, int losses, String duels) {
    return 'Victoires : $wins, défaites : $losses, $duels';
  }

  @override
  String get helpControlsTitle => 'Contrôles';

  @override
  String get helpControlsText => 'Incline le téléphone à gauche ou à droite pour déplacer ta raquette.';

  @override
  String get helpGoalTitle => 'Objectif';

  @override
  String get helpGoalText => 'Renvoie la balle le plus longtemps possible. Si elle passe derrière toi, c\'est fini.';

  @override
  String get helpPointsTitle => 'Points';

  @override
  String get helpPointsText => '+50 par renvoi, +100 quand l\'adversaire rate.';

  @override
  String get helpSpeedTitle => 'Vitesse';

  @override
  String get helpSpeedText => 'La balle accélère tous les 4 renvois.';

  @override
  String get helpPauseTitle => 'Pause';

  @override
  String get helpPauseText => 'Touche le bouton pause en haut à droite. Pas de pause en multijoueur.';

  @override
  String get helpMultiplayerText => 'Connectez-vous au même Wi‑Fi (ou au partage de connexion de l\'un de vous). L\'un crée la partie, l\'autre la rejoint. Premier à 5 points.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSoundSection => 'Son';

  @override
  String get settingsMusic => 'Musique';

  @override
  String get settingsMusicSubtitle => 'Accueil et pause';

  @override
  String get settingsEffects => 'Effets sonores';

  @override
  String get settingsEffectsSubtitle => 'Renvois, record, défaite';

  @override
  String get settingsGameSection => 'Jeu';

  @override
  String get settingsVibration => 'Vibration';

  @override
  String get settingsVibrationSubtitle => 'Au renvoi et au record';

  @override
  String get settingsSensitivity => 'Sensibilité';

  @override
  String get settingsSensitivityHint => 'Plus vive : la raquette va plus vite et demande moins d\'inclinaison.';

  @override
  String get settingsSensitivityLow => 'Douce';

  @override
  String get settingsSensitivityHigh => 'Vive';

  @override
  String get settingsTrialZone => 'Zone d\'essai · penche ton téléphone';

  @override
  String get settingsLanguageSection => 'Langue';

  @override
  String get settingsLanguageAutomatic => 'Automatique';

  @override
  String settingsLanguageAutomaticHint(String language) {
    return 'Selon ton téléphone : $language';
  }

  @override
  String get settingsProfileSection => 'Profil';

  @override
  String get settingsNickname => 'Pseudo';

  @override
  String get settingsNicknameNone => 'Aucun';

  @override
  String get settingsNicknameChoose => 'Choisir';

  @override
  String settingsVersion(String game, String version) {
    return '$game · version $version';
  }

  @override
  String get nicknameDialogMessage => 'Il apparaît dans le classement.';

  @override
  String get nicknameDialogRequired => 'Choisis un pseudo';

  @override
  String get studioTitle => 'Le studio';

  @override
  String studioIntro(String game, String studio) {
    return '$game est un jeu de $studio.';
  }

  @override
  String get studioVisitWebsite => 'Visiter le site';

  @override
  String get studioContact => 'Écrire au studio';

  @override
  String studioLinkFailed(String host) {
    return 'Le lien ne s\'ouvre pas. Va sur $host depuis ton navigateur.';
  }

  @override
  String get studioSignaturePrefix => 'Un jeu de';

  @override
  String studioSignatureSemantics(String studio) {
    return 'Un jeu de $studio';
  }

  @override
  String studioSignatureLink(String studio) {
    return 'Le studio, $studio';
  }

  @override
  String mpPlayingAs(String name) {
    return 'Tu joues en tant que $name';
  }

  @override
  String get mpCreateTitle => 'Créer une partie';

  @override
  String get mpCreateSubtitle => 'Ton ami la rejoint depuis son téléphone.';

  @override
  String get mpJoinTitle => 'Rejoindre une partie';

  @override
  String get mpJoinSubtitle => 'Trouve la partie d\'un ami à proximité.';

  @override
  String get mpNetworkHint => 'Soyez sur le même Wi‑Fi, ou connecte-toi au partage de connexion de l\'autre. Pas besoin d\'Internet.';

  @override
  String get joinTitle => 'Rejoindre';

  @override
  String get joinRefresh => 'Actualiser';

  @override
  String get joinSearching => 'Recherche de parties…';

  @override
  String get joinSearchingHint => 'Reste près de l\'autre joueur, sur le même Wi‑Fi.';

  @override
  String get joinNoGame => 'Aucune partie trouvée';

  @override
  String get joinTipNetwork => 'Vérifie que vous êtes sur le même Wi‑Fi ou partage de connexion.';

  @override
  String joinTipCreate(String action) {
    return 'Demande à l\'autre joueur de toucher « $action ».';
  }

  @override
  String joinGamesNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parties à proximité',
      one: '$count partie à proximité',
    );
    return '$_temp0';
  }

  @override
  String joinStillSearching(String found) {
    return '$found · recherche en cours';
  }

  @override
  String get joinGameFull => 'Complète';

  @override
  String get joinJoin => 'Rejoindre';

  @override
  String joinPlayers(int count, int max) {
    return '$count / $max joueurs';
  }

  @override
  String get joinConnecting => 'Connexion…';

  @override
  String gameOf(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'yes': 'Partie d\'$name',
        'other': 'Partie de $name',
      },
    );
    return '$_temp0';
  }

  @override
  String get gameOfOpponent => 'Partie de ton adversaire';

  @override
  String get lobbyTitle => 'Salon';

  @override
  String lobbyDuelFormat(int points) {
    return 'Duel · premier à $points points';
  }

  @override
  String get lobbyYouHost => 'Toi · hôte';

  @override
  String get lobbyYou => 'Toi';

  @override
  String get lobbyHost => 'Hôte';

  @override
  String get lobbyGuest => 'Invité';

  @override
  String get lobbyJustJoined => 'Vient de rejoindre';

  @override
  String get lobbyReadyStatus => 'Prêt';

  @override
  String get lobbyWaitingStatus => 'En attente';

  @override
  String get lobbyWaitingForPlayer => 'En attente d\'un joueur…';

  @override
  String get lobbyVisible => 'Ta partie est visible par les joueurs à proximité.';

  @override
  String get lobbyHintAlone => 'Disponible dès qu\'un joueur te rejoint';

  @override
  String lobbyHintOtherReady(String name) {
    return '$name t\'attend. À toi !';
  }

  @override
  String get lobbyHintBothReady => 'La partie démarre quand vous êtes prêts tous les deux';

  @override
  String waitingFor(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'yes': 'En attente d\'$name…',
        'other': 'En attente de $name…',
      },
    );
    return '$_temp0';
  }

  @override
  String get waitingForOpponent => 'En attente de ton adversaire…';

  @override
  String get lobbyReady => 'Prêt';

  @override
  String get lobbyNotReady => 'Je ne suis plus prêt';

  @override
  String get lobbyCancelGame => 'Annuler la partie';

  @override
  String get countdownVersus => 'contre';

  @override
  String get countdownGrabPhone => 'Prends ton téléphone';

  @override
  String get countdownHint => 'À deux mains, prêt à incliner';

  @override
  String duelHudFormat(int points) {
    return 'Duel · premier à $points';
  }

  @override
  String get duelConnectionWeak => 'Connexion faible';

  @override
  String get duelConnectionGood => 'Bonne connexion';

  @override
  String duelScoreSemantics(String myName, int myScore, String opponentName, int opponentScore) {
    return '$myName $myScore, $opponentName $opponentScore';
  }

  @override
  String duelPointFor(String name) {
    return 'Point pour $name';
  }

  @override
  String duelResumeIn(int seconds) {
    return 'Reprise dans $seconds…';
  }

  @override
  String get resultVictory => 'Victoire';

  @override
  String get resultDefeat => 'Défaite';

  @override
  String resultWinner(String name) {
    return '$name gagne !';
  }

  @override
  String resultDetail(String duration, String rally) {
    return '$duration · plus long échange : $rally';
  }

  @override
  String get resultCloseLoss => 'Si près ! La revanche ?';

  @override
  String get resultLoss => 'La revanche ?';

  @override
  String rematchIAsked(String name) {
    return 'Tu veux rejouer · $name n\'a pas encore répondu';
  }

  @override
  String rematchOpponentAsked(String name) {
    return '$name veut rejouer';
  }

  @override
  String opponentLeftGame(String name) {
    return '$name a quitté la partie';
  }

  @override
  String get resultRematch => 'Rejouer';

  @override
  String incidentOpponentLostTitle(String name) {
    return 'Connexion perdue avec $name';
  }

  @override
  String incidentOpponentLostMessage(String name) {
    return 'Ta partie reste ouverte : $name peut la rejoindre à nouveau.';
  }

  @override
  String get incidentBackToLobby => 'Retour au salon';

  @override
  String get incidentHostLeftMessage => 'La partie est terminée. Tu peux en rejoindre une autre ou créer la tienne.';

  @override
  String get incidentBackToMenu => 'Retour au menu';

  @override
  String get incidentConnectionLostTitle => 'Connexion perdue';

  @override
  String incidentConnectionLostMessage(String name) {
    return '$name ne répond plus. Vérifie que vous êtes toujours sur le même Wi‑Fi.';
  }

  @override
  String get incidentConnectionFailedTitle => 'Connexion impossible';

  @override
  String get incidentConnectionFailedMessage => 'Vérifie que vous êtes sur le même Wi‑Fi, puis réessaie.';

  @override
  String get incidentRetry => 'Réessayer';

  @override
  String get incidentBack => 'Retour';

  @override
  String get incidentGameFullTitle => 'Partie complète';

  @override
  String incidentGameFullMessage(String name) {
    return '$name joue déjà avec quelqu\'un. Choisis une autre partie ou crée la tienne.';
  }

  @override
  String get incidentBackToList => 'Retour à la liste';

  @override
  String get incidentNoWifiTitle => 'Pas de Wi‑Fi';

  @override
  String get incidentNoWifiMessage => 'Connecte-toi à un Wi‑Fi ou au partage de connexion de l\'autre joueur, puis réessaie.';

  @override
  String get incidentLeaveDuelTitle => 'Quitter le duel ?';

  @override
  String incidentLeaveDuelMessage(String name) {
    return 'Le duel s\'arrête pour $name aussi.';
  }

  @override
  String get incidentKeepPlaying => 'Continuer le duel';

  @override
  String get incidentVersionTitle => 'Versions différentes';

  @override
  String get incidentVersionMessage => 'Installe la même version du jeu sur les deux téléphones, puis réessaie.';

  @override
  String get incidentClosedTitle => 'Partie fermée';

  @override
  String get incidentClosedMessage => 'La partie s\'arrête quand le jeu passe en arrière-plan. Tu peux en créer ou en rejoindre une autre.';
}
