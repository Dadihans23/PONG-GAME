// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonBack => 'Back';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonQuit => 'Quit';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String commonLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String gaugeProgress(int filled, int count) {
    return '$filled of $count';
  }

  @override
  String gaugeProgressLabelled(String label, int filled, int count) {
    return '$label, $filled of $count';
  }

  @override
  String get modeSolo => 'Solo';

  @override
  String get modeMultiplayer => 'Multiplayer';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get splashLoading => 'Loading…';

  @override
  String get splashLoadingLabel => 'Loading';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeNicknameRequired => 'Choose a nickname to play';

  @override
  String get nicknameFieldLabel => 'Your nickname';

  @override
  String get nicknameFieldHint => 'Enter your nickname';

  @override
  String get homeGameModeTitle => 'Game mode';

  @override
  String get homeSoloSubtitle => 'Against the computer';

  @override
  String homeSoloSubtitleWithDifficulty(String difficulty) {
    return 'Against the computer · $difficulty';
  }

  @override
  String get homeChooseDifficulty => 'Pick a difficulty';

  @override
  String get bestScore => 'High score';

  @override
  String bestScoreValue(String score) {
    return 'High score: $score';
  }

  @override
  String get homeMultiplayerSubtitle => 'Two players, same Wi‑Fi';

  @override
  String homeMultiplayerDetail(int points) {
    return 'First to $points points, each on your own phone. No internet needed.';
  }

  @override
  String get homeDuelRecord => 'Wins / losses';

  @override
  String duelRecordSemantics(int wins, int losses) {
    return 'Wins: $wins, losses: $losses';
  }

  @override
  String get homePlay => 'Play';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get helpTitle => 'Help';

  @override
  String hudSoloMode(String difficulty) {
    return 'Solo · $difficulty';
  }

  @override
  String hudSpeed(int level) {
    return 'Speed $level';
  }

  @override
  String get pauseTooltip => 'Pause';

  @override
  String get courtTapToStart => 'Tap to start';

  @override
  String get courtTiltHint => 'Tilt your phone to move';

  @override
  String courtRecord(String score) {
    return 'Best $score';
  }

  @override
  String get courtNewRecord => 'New high score';

  @override
  String get pauseTitle => 'Paused';

  @override
  String pauseScore(String score) {
    return 'Score $score';
  }

  @override
  String pauseScoreAndRecord(String score, String record) {
    return 'Score $score · Best $record';
  }

  @override
  String get pauseResume => 'Resume';

  @override
  String get pauseQuit => 'Quit game';

  @override
  String get gameOverTitle => 'Game over';

  @override
  String get gameOverNewRecord => 'New high score!';

  @override
  String get gameOverPoints => 'points';

  @override
  String gameOverPointsWithRecord(String record) {
    return 'points · best $record';
  }

  @override
  String gameOverPointsOverRecord(String gain) {
    return 'points · $gain over your old best';
  }

  @override
  String gameOverHits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hits',
      one: 'hit',
    );
    return '$_temp0';
  }

  @override
  String get gameOverDuration => 'time';

  @override
  String get gameOverRank => 'rank';

  @override
  String get gameOverTopSpeed => 'top speed';

  @override
  String get gameOverReplay => 'Play again';

  @override
  String get gameOverHome => 'Back to home';

  @override
  String rankOrdinal(String rank) {
    String _temp0 = intl.Intl.selectLogic(
      rank,
      {
        '1': '1st',
        '2': '2nd',
        '3': '3rd',
        'other': '${rank}th',
      },
    );
    return '$_temp0';
  }

  @override
  String get leaderboardEmptyTitle => 'No scores yet';

  @override
  String leaderboardEmptyMessage(int count) {
    return 'Play a solo game: your top $count scores will show up here.';
  }

  @override
  String leaderboardRowSemantics(String rank, String name, String score) {
    return '$rank, $name, $score points';
  }

  @override
  String leaderboardRowSemanticsWithDate(String rank, String name, String score, String date) {
    return '$rank, $name, $score points, on $date';
  }

  @override
  String get leaderboardUnknownPlayer => 'Unknown';

  @override
  String get statsSoloEmpty => 'Play your first game to fill in these numbers.';

  @override
  String get statsGamesPlayed => 'Games played';

  @override
  String get statsTotalTime => 'Total play time';

  @override
  String get statsBestStreak => 'Best streak';

  @override
  String hitsCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText hits',
      one: '$countText hit',
    );
    return '$_temp0';
  }

  @override
  String get statsMultiplayerEmpty => 'Play your first duel to fill in these numbers.';

  @override
  String get statsWins => 'Wins';

  @override
  String get statsLosses => 'Losses';

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
    return 'Wins: $wins, losses: $losses, $duels';
  }

  @override
  String get helpControlsTitle => 'Controls';

  @override
  String get helpControlsText => 'Tilt your phone left or right to move your paddle.';

  @override
  String get helpGoalTitle => 'Goal';

  @override
  String get helpGoalText => 'Keep the ball in play as long as you can. If it gets past you, it\'s over.';

  @override
  String get helpPointsTitle => 'Points';

  @override
  String get helpPointsText => '+50 per hit, +100 when your opponent misses.';

  @override
  String get helpSpeedTitle => 'Speed';

  @override
  String get helpSpeedText => 'The ball speeds up every 4 hits.';

  @override
  String get helpPauseTitle => 'Pause';

  @override
  String get helpPauseText => 'Tap the pause button at the top right. No pausing in multiplayer.';

  @override
  String get helpMultiplayerText => 'Connect both phones to the same Wi‑Fi (or to one player\'s hotspot). One creates the game, the other joins it. First to 5 points wins.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSoundSection => 'Sound';

  @override
  String get settingsMusic => 'Music';

  @override
  String get settingsMusicSubtitle => 'Home and pause';

  @override
  String get settingsEffects => 'Sound effects';

  @override
  String get settingsEffectsSubtitle => 'Hits, high score, loss';

  @override
  String get settingsGameSection => 'Game';

  @override
  String get settingsVibration => 'Vibration';

  @override
  String get settingsVibrationSubtitle => 'On hits and high scores';

  @override
  String get settingsSensitivity => 'Sensitivity';

  @override
  String get settingsSensitivityHint => 'Higher: the paddle moves faster and needs less tilt.';

  @override
  String get settingsSensitivityLow => 'Low';

  @override
  String get settingsSensitivityHigh => 'High';

  @override
  String get settingsTrialZone => 'Try it · tilt your phone';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageAutomatic => 'Automatic';

  @override
  String settingsLanguageAutomaticHint(String language) {
    return 'Based on your phone: $language';
  }

  @override
  String get settingsProfileSection => 'Profile';

  @override
  String get settingsNickname => 'Nickname';

  @override
  String get settingsNicknameNone => 'None';

  @override
  String get settingsNicknameChoose => 'Choose';

  @override
  String settingsVersion(String game, String version) {
    return '$game · version $version';
  }

  @override
  String get nicknameDialogMessage => 'It shows on the leaderboard.';

  @override
  String get nicknameDialogRequired => 'Choose a nickname';

  @override
  String get studioTitle => 'The studio';

  @override
  String studioIntro(String game, String studio) {
    return '$game is a game by $studio.';
  }

  @override
  String get studioVisitWebsite => 'Visit the website';

  @override
  String get studioContact => 'Contact the studio';

  @override
  String studioLinkFailed(String host) {
    return 'The link won\'t open. Go to $host in your browser.';
  }

  @override
  String get studioSignaturePrefix => 'A game by';

  @override
  String studioSignatureSemantics(String studio) {
    return 'A game by $studio';
  }

  @override
  String studioSignatureLink(String studio) {
    return 'The studio, $studio';
  }

  @override
  String mpPlayingAs(String name) {
    return 'You\'re playing as $name';
  }

  @override
  String get mpCreateTitle => 'Create a game';

  @override
  String get mpCreateSubtitle => 'Your friend joins from their phone.';

  @override
  String get mpJoinTitle => 'Join a game';

  @override
  String get mpJoinSubtitle => 'Find a friend\'s game nearby.';

  @override
  String get mpNetworkHint => 'Be on the same Wi‑Fi, or connect to the other player\'s hotspot. No internet needed.';

  @override
  String get joinTitle => 'Join';

  @override
  String get joinRefresh => 'Refresh';

  @override
  String get joinSearching => 'Looking for games…';

  @override
  String get joinSearchingHint => 'Stay close to the other player, on the same Wi‑Fi.';

  @override
  String get joinNoGame => 'No games found';

  @override
  String get joinTipNetwork => 'Check that you\'re both on the same Wi‑Fi or hotspot.';

  @override
  String joinTipCreate(String action) {
    return 'Ask the other player to tap “$action”.';
  }

  @override
  String joinGamesNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games nearby',
      one: '$count game nearby',
    );
    return '$_temp0';
  }

  @override
  String joinStillSearching(String found) {
    return '$found · searching';
  }

  @override
  String get joinGameFull => 'Full';

  @override
  String get joinJoin => 'Join';

  @override
  String joinPlayers(int count, int max) {
    return '$count / $max players';
  }

  @override
  String get joinConnecting => 'Connecting…';

  @override
  String gameOf(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'other': '$name\'s game',
      },
    );
    return '$_temp0';
  }

  @override
  String get gameOfOpponent => 'Your opponent\'s game';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String lobbyDuelFormat(int points) {
    return 'Duel · first to $points points';
  }

  @override
  String get lobbyYouHost => 'You · host';

  @override
  String get lobbyYou => 'You';

  @override
  String get lobbyHost => 'Host';

  @override
  String get lobbyGuest => 'Guest';

  @override
  String get lobbyJustJoined => 'Just joined';

  @override
  String get lobbyReadyStatus => 'Ready';

  @override
  String get lobbyWaitingStatus => 'Waiting';

  @override
  String get lobbyWaitingForPlayer => 'Waiting for a player…';

  @override
  String get lobbyVisible => 'Players nearby can see your game.';

  @override
  String get lobbyHintAlone => 'Available as soon as someone joins';

  @override
  String lobbyHintOtherReady(String name) {
    return '$name is waiting for you. Your move!';
  }

  @override
  String get lobbyHintBothReady => 'The game starts when you\'re both ready';

  @override
  String waitingFor(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'other': 'Waiting for $name…',
      },
    );
    return '$_temp0';
  }

  @override
  String get waitingForOpponent => 'Waiting for your opponent…';

  @override
  String get lobbyReady => 'Ready';

  @override
  String get lobbyNotReady => 'I\'m not ready';

  @override
  String get lobbyCancelGame => 'Cancel game';

  @override
  String get countdownVersus => 'vs';

  @override
  String get countdownGrabPhone => 'Grab your phone';

  @override
  String get countdownHint => 'Both hands, ready to tilt';

  @override
  String duelHudFormat(int points) {
    return 'Duel · first to $points';
  }

  @override
  String get duelConnectionWeak => 'Weak connection';

  @override
  String get duelConnectionGood => 'Good connection';

  @override
  String duelScoreSemantics(String myName, int myScore, String opponentName, int opponentScore) {
    return '$myName $myScore, $opponentName $opponentScore';
  }

  @override
  String duelPointFor(String name) {
    return 'Point for $name';
  }

  @override
  String duelResumeIn(int seconds) {
    return 'Resuming in $seconds…';
  }

  @override
  String get resultVictory => 'Victory';

  @override
  String get resultDefeat => 'Defeat';

  @override
  String resultWinner(String name) {
    return '$name wins!';
  }

  @override
  String resultDetail(String duration, String rally) {
    return '$duration · longest rally: $rally';
  }

  @override
  String get resultCloseLoss => 'So close! Rematch?';

  @override
  String get resultLoss => 'Rematch?';

  @override
  String rematchIAsked(String name) {
    return 'Rematch requested · $name hasn\'t answered yet';
  }

  @override
  String rematchOpponentAsked(String name) {
    return '$name wants a rematch';
  }

  @override
  String opponentLeftGame(String name) {
    return '$name left the game';
  }

  @override
  String get resultRematch => 'Rematch';

  @override
  String incidentOpponentLostTitle(String name) {
    return 'Lost connection with $name';
  }

  @override
  String incidentOpponentLostMessage(String name) {
    return 'Your game is still open: $name can join again.';
  }

  @override
  String get incidentBackToLobby => 'Back to lobby';

  @override
  String get incidentHostLeftMessage => 'The game is over. You can join another one or create your own.';

  @override
  String get incidentBackToMenu => 'Back to menu';

  @override
  String get incidentConnectionLostTitle => 'Connection lost';

  @override
  String incidentConnectionLostMessage(String name) {
    return '$name isn\'t responding. Check that you\'re both still on the same Wi‑Fi.';
  }

  @override
  String get incidentConnectionFailedTitle => 'Couldn\'t connect';

  @override
  String get incidentConnectionFailedMessage => 'Check that you\'re both on the same Wi‑Fi, then try again.';

  @override
  String get incidentRetry => 'Try again';

  @override
  String get incidentBack => 'Back';

  @override
  String get incidentGameFullTitle => 'Game full';

  @override
  String incidentGameFullMessage(String name) {
    return '$name is already playing with someone. Pick another game or create your own.';
  }

  @override
  String get incidentBackToList => 'Back to the list';

  @override
  String get incidentNoWifiTitle => 'No Wi‑Fi';

  @override
  String get incidentNoWifiMessage => 'Connect to a Wi‑Fi network or the other player\'s hotspot, then try again.';

  @override
  String get incidentLeaveDuelTitle => 'Leave the duel?';

  @override
  String incidentLeaveDuelMessage(String name) {
    return 'The duel will end for $name too.';
  }

  @override
  String get incidentKeepPlaying => 'Keep playing';

  @override
  String get incidentVersionTitle => 'Different versions';

  @override
  String get incidentVersionMessage => 'Install the same version of the game on both phones, then try again.';

  @override
  String get incidentClosedTitle => 'Game closed';

  @override
  String get incidentClosedMessage => 'The game stops when the app goes to the background. You can create or join another one.';
}
