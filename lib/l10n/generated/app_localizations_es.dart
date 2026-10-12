// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonQuit => 'Salir';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String commonLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String gaugeProgress(int filled, int count) {
    return '$filled de $count';
  }

  @override
  String gaugeProgressLabelled(String label, int filled, int count) {
    return '$label, $filled de $count';
  }

  @override
  String get modeSolo => 'Solo';

  @override
  String get modeMultiplayer => 'Multijugador';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String get splashLoading => 'Cargando…';

  @override
  String get splashLoadingLabel => 'Cargando';

  @override
  String get homeSettingsTooltip => 'Ajustes';

  @override
  String homeGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get homeNicknameRequired => 'Elige un apodo para jugar';

  @override
  String get nicknameFieldLabel => 'Tu apodo';

  @override
  String get nicknameFieldHint => 'Escribe tu apodo';

  @override
  String get homeGameModeTitle => 'Modo de juego';

  @override
  String get homeSoloSubtitle => 'Contra la máquina';

  @override
  String homeSoloSubtitleWithDifficulty(String difficulty) {
    return 'Contra la máquina · $difficulty';
  }

  @override
  String get homeChooseDifficulty => 'Elige la dificultad';

  @override
  String get bestScore => 'Mejor puntuación';

  @override
  String bestScoreValue(String score) {
    return 'Mejor puntuación: $score';
  }

  @override
  String get homeMultiplayerSubtitle => 'Dos jugadores, mismo Wi‑Fi';

  @override
  String homeMultiplayerDetail(int points) {
    return 'Duelo a $points puntos, cada uno en su teléfono. No hace falta internet.';
  }

  @override
  String get homeDuelRecord => 'Victorias / derrotas';

  @override
  String duelRecordSemantics(int wins, int losses) {
    return 'Victorias: $wins, derrotas: $losses';
  }

  @override
  String get homePlay => 'Jugar';

  @override
  String get leaderboardTitle => 'Clasificación';

  @override
  String get statisticsTitle => 'Estadísticas';

  @override
  String get helpTitle => 'Ayuda';

  @override
  String hudSoloMode(String difficulty) {
    return 'Solo · $difficulty';
  }

  @override
  String hudSpeed(int level) {
    return 'Velocidad $level';
  }

  @override
  String get pauseTooltip => 'Pausa';

  @override
  String get courtTapToStart => 'Toca la pantalla';

  @override
  String get courtTiltHint => 'Inclina el teléfono para moverte';

  @override
  String courtRecord(String score) {
    return 'Récord $score';
  }

  @override
  String get courtNewRecord => 'Nuevo récord';

  @override
  String get pauseTitle => 'Pausa';

  @override
  String pauseScore(String score) {
    return 'Puntos $score';
  }

  @override
  String pauseScoreAndRecord(String score, String record) {
    return 'Puntos $score · Récord $record';
  }

  @override
  String get pauseResume => 'Continuar';

  @override
  String get pauseQuit => 'Salir de la partida';

  @override
  String get gameOverTitle => 'Fin de la partida';

  @override
  String get gameOverNewRecord => '¡Nuevo récord!';

  @override
  String get gameOverPoints => 'puntos';

  @override
  String gameOverPointsWithRecord(String record) {
    return 'puntos · récord $record';
  }

  @override
  String gameOverPointsOverRecord(String gain) {
    return 'puntos · $gain sobre tu récord anterior';
  }

  @override
  String gameOverHits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'golpes',
      one: 'golpe',
    );
    return '$_temp0';
  }

  @override
  String get gameOverDuration => 'tiempo';

  @override
  String get gameOverRank => 'puesto';

  @override
  String get gameOverTopSpeed => 'vel. máxima';

  @override
  String get gameOverReplay => 'Jugar otra vez';

  @override
  String get gameOverHome => 'Volver al inicio';

  @override
  String rankOrdinal(String rank) {
    String _temp0 = intl.Intl.selectLogic(
      rank,
      {
        'other': '$rank.º',
      },
    );
    return '$_temp0';
  }

  @override
  String get leaderboardEmptyTitle => 'Aún no hay puntuaciones';

  @override
  String leaderboardEmptyMessage(int count) {
    return 'Juega una partida en solo: tus $count mejores puntuaciones aparecerán aquí.';
  }

  @override
  String leaderboardRowSemantics(String rank, String name, String score) {
    return '$rank, $name, $score puntos';
  }

  @override
  String leaderboardRowSemanticsWithDate(String rank, String name, String score, String date) {
    return '$rank, $name, $score puntos, el $date';
  }

  @override
  String get leaderboardUnknownPlayer => 'Desconocido';

  @override
  String get statsSoloEmpty => 'Juega tu primera partida para llenar estas cifras.';

  @override
  String get statsGamesPlayed => 'Partidas jugadas';

  @override
  String get statsTotalTime => 'Tiempo total de juego';

  @override
  String get statsBestStreak => 'Mejor racha';

  @override
  String hitsCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText golpes',
      one: '$countText golpe',
    );
    return '$_temp0';
  }

  @override
  String get statsMultiplayerEmpty => 'Juega tu primer duelo para llenar estas cifras.';

  @override
  String get statsWins => 'Victorias';

  @override
  String get statsLosses => 'Derrotas';

  @override
  String duelsCount(int count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText duelos',
      one: '$countText duelo',
    );
    return '$_temp0';
  }

  @override
  String statsDuelSemantics(int wins, int losses, String duels) {
    return 'Victorias: $wins, derrotas: $losses, $duels';
  }

  @override
  String get helpControlsTitle => 'Controles';

  @override
  String get helpControlsText => 'Inclina el teléfono a la izquierda o a la derecha para mover tu paleta.';

  @override
  String get helpGoalTitle => 'Objetivo';

  @override
  String get helpGoalText => 'Devuelve la pelota el mayor tiempo posible. Si pasa detrás de ti, se acabó.';

  @override
  String get helpPointsTitle => 'Puntos';

  @override
  String get helpPointsText => '+50 por golpe, +100 cuando el rival falla.';

  @override
  String get helpSpeedTitle => 'Velocidad';

  @override
  String get helpSpeedText => 'La pelota acelera cada 4 golpes.';

  @override
  String get helpPauseTitle => 'Pausa';

  @override
  String get helpPauseText => 'Toca el botón de pausa arriba a la derecha. En multijugador no hay pausa.';

  @override
  String get helpMultiplayerText => 'Los dos teléfonos deben estar en el mismo Wi‑Fi (o en el punto de acceso de uno de los dos). Uno crea la partida y el otro se une. Gana el primero en llegar a 5 puntos.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSoundSection => 'Sonido';

  @override
  String get settingsMusic => 'Música';

  @override
  String get settingsMusicSubtitle => 'Inicio y pausa';

  @override
  String get settingsEffects => 'Efectos de sonido';

  @override
  String get settingsEffectsSubtitle => 'Golpes, récord, derrota';

  @override
  String get settingsGameSection => 'Juego';

  @override
  String get settingsVibration => 'Vibración';

  @override
  String get settingsVibrationSubtitle => 'Al golpear y con cada récord';

  @override
  String get settingsSensitivity => 'Sensibilidad';

  @override
  String get settingsSensitivityHint => 'Más alta: la paleta va más rápido y necesita menos inclinación.';

  @override
  String get settingsSensitivityLow => 'Baja';

  @override
  String get settingsSensitivityHigh => 'Alta';

  @override
  String get settingsTrialZone => 'Pruébalo · inclina tu teléfono';

  @override
  String get settingsLanguageSection => 'Idioma';

  @override
  String get settingsLanguageAutomatic => 'Automático';

  @override
  String settingsLanguageAutomaticHint(String language) {
    return 'Sigue el idioma del teléfono: $language';
  }

  @override
  String get settingsProfileSection => 'Perfil';

  @override
  String get settingsNickname => 'Apodo';

  @override
  String get settingsNicknameNone => 'Ninguno';

  @override
  String get settingsNicknameChoose => 'Elegir';

  @override
  String settingsVersion(String game, String version) {
    return '$game · versión $version';
  }

  @override
  String get nicknameDialogMessage => 'Aparece en la clasificación.';

  @override
  String get nicknameDialogRequired => 'Elige un apodo';

  @override
  String get studioTitle => 'El estudio';

  @override
  String studioIntro(String game, String studio) {
    return '$game es un juego de $studio.';
  }

  @override
  String get studioVisitWebsite => 'Visitar el sitio web';

  @override
  String get studioContact => 'Escribir al estudio';

  @override
  String studioLinkFailed(String host) {
    return 'El enlace no se abre. Entra en $host desde tu navegador.';
  }

  @override
  String get studioSignaturePrefix => 'Un juego de';

  @override
  String studioSignatureSemantics(String studio) {
    return 'Un juego de $studio';
  }

  @override
  String studioSignatureLink(String studio) {
    return 'El estudio, $studio';
  }

  @override
  String mpPlayingAs(String name) {
    return 'Juegas como $name';
  }

  @override
  String get mpCreateTitle => 'Crear una partida';

  @override
  String get mpCreateSubtitle => 'Tu amigo se une desde su teléfono.';

  @override
  String get mpJoinTitle => 'Unirse a una partida';

  @override
  String get mpJoinSubtitle => 'Busca la partida de un amigo cercano.';

  @override
  String get mpNetworkHint => 'Los dos deben estar en el mismo Wi‑Fi, o conéctate al punto de acceso del otro jugador. No hace falta internet.';

  @override
  String get joinTitle => 'Unirse';

  @override
  String get joinRefresh => 'Actualizar';

  @override
  String get joinSearching => 'Buscando partidas…';

  @override
  String get joinSearchingHint => 'Quédate cerca del otro jugador, en el mismo Wi‑Fi.';

  @override
  String get joinNoGame => 'No se encontraron partidas';

  @override
  String get joinTipNetwork => 'Comprueba que ambos teléfonos estén en el mismo Wi‑Fi o punto de acceso.';

  @override
  String joinTipCreate(String action) {
    return 'Pide al otro jugador que toque «$action».';
  }

  @override
  String joinGamesNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidas cercanas',
      one: '$count partida cercana',
    );
    return '$_temp0';
  }

  @override
  String joinStillSearching(String found) {
    return '$found · buscando';
  }

  @override
  String get joinGameFull => 'Llena';

  @override
  String get joinJoin => 'Unirse';

  @override
  String joinPlayers(int count, int max) {
    return '$count / $max jugadores';
  }

  @override
  String get joinConnecting => 'Conectando…';

  @override
  String gameOf(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'other': 'Partida de $name',
      },
    );
    return '$_temp0';
  }

  @override
  String get gameOfOpponent => 'Partida de tu rival';

  @override
  String get lobbyTitle => 'Sala';

  @override
  String lobbyDuelFormat(int points) {
    return 'Duelo a $points puntos';
  }

  @override
  String get lobbyYouHost => 'Tú · anfitrión';

  @override
  String get lobbyYou => 'Tú';

  @override
  String get lobbyHost => 'Anfitrión';

  @override
  String get lobbyGuest => 'Invitado';

  @override
  String get lobbyJustJoined => 'Acaba de unirse';

  @override
  String get lobbyReadyStatus => 'Listo';

  @override
  String get lobbyWaitingStatus => 'Esperando';

  @override
  String get lobbyWaitingForPlayer => 'Esperando a un jugador…';

  @override
  String get lobbyVisible => 'Los jugadores cercanos pueden ver tu partida.';

  @override
  String get lobbyHintAlone => 'Disponible cuando alguien se una';

  @override
  String lobbyHintOtherReady(String name) {
    return '$name te está esperando. ¡Te toca!';
  }

  @override
  String get lobbyHintBothReady => 'La partida empieza cuando los dos estén listos';

  @override
  String waitingFor(String elision, String name) {
    String _temp0 = intl.Intl.selectLogic(
      elision,
      {
        'other': 'Esperando a $name…',
      },
    );
    return '$_temp0';
  }

  @override
  String get waitingForOpponent => 'Esperando a tu rival…';

  @override
  String get lobbyReady => 'Listo';

  @override
  String get lobbyNotReady => 'Ya no estoy listo';

  @override
  String get lobbyCancelGame => 'Cancelar partida';

  @override
  String get countdownVersus => 'contra';

  @override
  String get countdownGrabPhone => 'Toma tu teléfono';

  @override
  String get countdownHint => 'Con las dos manos, listo para inclinar';

  @override
  String duelHudFormat(int points) {
    return 'Duelo a $points puntos';
  }

  @override
  String get duelConnectionWeak => 'Conexión débil';

  @override
  String get duelConnectionGood => 'Buena conexión';

  @override
  String duelScoreSemantics(String myName, int myScore, String opponentName, int opponentScore) {
    return '$myName $myScore, $opponentName $opponentScore';
  }

  @override
  String duelPointFor(String name) {
    return 'Punto para $name';
  }

  @override
  String duelResumeIn(int seconds) {
    return 'Seguimos en $seconds…';
  }

  @override
  String get resultVictory => 'Victoria';

  @override
  String get resultDefeat => 'Derrota';

  @override
  String resultWinner(String name) {
    return '¡$name gana!';
  }

  @override
  String resultDetail(String duration, String rally) {
    return '$duration · intercambio más largo: $rally';
  }

  @override
  String get resultCloseLoss => '¡Casi! ¿La revancha?';

  @override
  String get resultLoss => '¿La revancha?';

  @override
  String rematchIAsked(String name) {
    return 'Quieres la revancha · $name aún no responde';
  }

  @override
  String rematchOpponentAsked(String name) {
    return '$name quiere la revancha';
  }

  @override
  String opponentLeftGame(String name) {
    return '$name salió de la partida';
  }

  @override
  String get resultRematch => 'Revancha';

  @override
  String incidentOpponentLostTitle(String name) {
    return 'Se perdió la conexión con $name';
  }

  @override
  String incidentOpponentLostMessage(String name) {
    return 'Tu partida sigue abierta: $name puede volver a unirse.';
  }

  @override
  String get incidentBackToLobby => 'Volver a la sala';

  @override
  String get incidentHostLeftMessage => 'La partida terminó. Puedes unirte a otra o crear la tuya.';

  @override
  String get incidentBackToMenu => 'Volver al menú';

  @override
  String get incidentConnectionLostTitle => 'Conexión perdida';

  @override
  String incidentConnectionLostMessage(String name) {
    return '$name no responde. Comprueba que ambos teléfonos sigan en el mismo Wi‑Fi.';
  }

  @override
  String get incidentConnectionFailedTitle => 'No se pudo conectar';

  @override
  String get incidentConnectionFailedMessage => 'Comprueba que ambos teléfonos estén en el mismo Wi‑Fi y vuelve a intentarlo.';

  @override
  String get incidentRetry => 'Reintentar';

  @override
  String get incidentBack => 'Volver';

  @override
  String get incidentGameFullTitle => 'Partida llena';

  @override
  String incidentGameFullMessage(String name) {
    return '$name ya está jugando con alguien. Elige otra partida o crea la tuya.';
  }

  @override
  String get incidentBackToList => 'Volver a la lista';

  @override
  String get incidentNoWifiTitle => 'Sin Wi‑Fi';

  @override
  String get incidentNoWifiMessage => 'Conéctate a una red Wi‑Fi o al punto de acceso del otro jugador y vuelve a intentarlo.';

  @override
  String get incidentLeaveDuelTitle => '¿Salir del duelo?';

  @override
  String incidentLeaveDuelMessage(String name) {
    return 'El duelo también terminará para $name.';
  }

  @override
  String get incidentKeepPlaying => 'Seguir jugando';

  @override
  String get incidentVersionTitle => 'Versiones diferentes';

  @override
  String get incidentVersionMessage => 'Instala la misma versión del juego en los dos teléfonos y vuelve a intentarlo.';

  @override
  String get incidentClosedTitle => 'Partida cerrada';

  @override
  String get incidentClosedMessage => 'La partida se detiene cuando el juego pasa a segundo plano. Puedes crear otra o unirte a una.';
}
