import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// Tooltip / screen-reader label of the back arrow in every screen header. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// Small text button next to the nickname (home screen, Settings). Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// Text button: leave the lobby (guest) or the end-of-duel screen; also the "leave" button of the "Leave the duel?" dialog. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get commonQuit;

  /// Main button of the nickname dialog (Settings). Shown in capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// Text button closing the nickname dialog without saving. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// Screen-reader text for a statistic tile ("Games played: 12"). Keep the punctuation of your language (French puts a space before the colon).
  ///
  /// In fr, this message translates to:
  /// **'{label} : {value}'**
  String commonLabelValue(String label, String value);

  /// Screen-reader text for a dot gauge ("2 of 4"): hits made towards the next speed-up, or points in a duel.
  ///
  /// In fr, this message translates to:
  /// **'{filled} sur {count}'**
  String gaugeProgress(int filled, int count);

  /// Screen-reader text for a labelled dot gauge ("Speed 3, 2 of 4").
  ///
  /// In fr, this message translates to:
  /// **'{label}, {filled} sur {count}'**
  String gaugeProgressLabelled(String label, int filled, int count);

  /// Name of the single-player mode (vs the computer): home mode card, Statistics section title. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Solo'**
  String get modeSolo;

  /// Name of the local two-phone mode: home mode card, screen title, Statistics and Help section titles. Screen titles are shown in spaced capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Multijoueur'**
  String get modeMultiplayer;

  /// Difficulty of the computer opponent, on a small button (1/3 of the card width). Also shown in capitals in the game header ("SOLO · EASY"). Max ~9 chars.
  ///
  /// In fr, this message translates to:
  /// **'Facile'**
  String get difficultyEasy;

  /// Medium difficulty (see difficultyEasy). Max ~9 chars.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// Hardest difficulty (see difficultyEasy). Max ~9 chars.
  ///
  /// In fr, this message translates to:
  /// **'Difficile'**
  String get difficultyHard;

  /// Under the loading bar of the start screen, next to the percentage. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get splashLoading;

  /// Screen-reader name of the loading bar (the percentage is read after it).
  ///
  /// In fr, this message translates to:
  /// **'Chargement'**
  String get splashLoadingLabel;

  /// Tooltip / screen-reader label of the gear icon at the top right of the home screen.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get homeSettingsTooltip;

  /// Home screen greeting with the player nickname (up to 20 chars, shortened with … if needed).
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {name}'**
  String homeGreeting(String name);

  /// Error under the nickname field when the player taps Play with an empty nickname. Max ~32 chars.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un pseudo pour jouer'**
  String get homeNicknameRequired;

  /// Label above the nickname field (home screen) and title of the nickname dialog (Settings). Max ~18 chars.
  ///
  /// In fr, this message translates to:
  /// **'Ton pseudo'**
  String get nicknameFieldLabel;

  /// Placeholder inside the empty nickname field. Max ~24 chars.
  ///
  /// In fr, this message translates to:
  /// **'Entre ton pseudo'**
  String get nicknameFieldHint;

  /// Small section title above the Solo and Multiplayer cards, shown in spaced capitals. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Mode de jeu'**
  String get homeGameModeTitle;

  /// Subtitle of the selected Solo card. Max ~24 chars.
  ///
  /// In fr, this message translates to:
  /// **'Contre l\'ordinateur'**
  String get homeSoloSubtitle;

  /// Subtitle of the Solo card when it is not selected: reminds the chosen difficulty. Max ~34 chars.
  ///
  /// In fr, this message translates to:
  /// **'Contre l\'ordinateur · {difficulty}'**
  String homeSoloSubtitleWithDifficulty(String difficulty);

  /// Line above the three difficulty buttons in the Solo card. Max ~26 chars.
  ///
  /// In fr, this message translates to:
  /// **'Choisis la difficulté'**
  String get homeChooseDifficulty;

  /// Best solo score: line at the bottom of the Solo card (home) and tile title in Statistics (half the screen width). Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur score'**
  String get bestScore;

  /// Screen-reader text of the high score line (home).
  ///
  /// In fr, this message translates to:
  /// **'Meilleur score : {score}'**
  String bestScoreValue(String score);

  /// Subtitle of the Multiplayer card on the home screen. Keep "Wi‑Fi" with its non-breaking hyphen. Max ~28 chars.
  ///
  /// In fr, this message translates to:
  /// **'À deux, même Wi‑Fi'**
  String get homeMultiplayerSubtitle;

  /// Text inside the selected Multiplayer card (home). Up to 3 lines.
  ///
  /// In fr, this message translates to:
  /// **'Duel en {points} points, chacun sur son téléphone. Pas besoin d\'Internet.'**
  String homeMultiplayerDetail(int points);

  /// Line at the bottom of the Multiplayer card, followed by "3 / 1". Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Victoires / défaites'**
  String get homeDuelRecord;

  /// Screen-reader text of the duel record line (home).
  ///
  /// In fr, this message translates to:
  /// **'Victoires : {wins}, défaites : {losses}'**
  String duelRecordSemantics(int wins, int losses);

  /// Main pink button of the home screen (starts the selected mode); also on the empty leaderboard. Shown in capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Jouer'**
  String get homePlay;

  /// Leaderboard (top 10 solo scores): screen title in spaced capitals, home shortcut tile (1/3 of the width) and button on the game-over card. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Classement'**
  String get leaderboardTitle;

  /// Statistics: screen title in spaced capitals, home shortcut tile (1/3 of the width) and button on the game-over card. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statisticsTitle;

  /// Help screen: title and home shortcut tile. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get helpTitle;

  /// Game header before the first tap, shown in capitals ("SOLO · NORMAL").
  ///
  /// In fr, this message translates to:
  /// **'Solo · {difficulty}'**
  String hudSoloMode(String difficulty);

  /// Game header during play, next to 4 dots, shown in capitals: current ball speed level. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse {level}'**
  String hudSpeed(int level);

  /// Tooltip / screen-reader label of the pause button (top right during a solo game).
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pauseTooltip;

  /// Big instruction in the middle of the court before a solo game starts, in spaced capitals (font 20). Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Tape l\'écran'**
  String get courtTapToStart;

  /// Hint under "Tap the screen": the paddle is moved by tilting the phone. One line, max ~34 chars.
  ///
  /// In fr, this message translates to:
  /// **'Incline le téléphone pour bouger'**
  String get courtTiltHint;

  /// Previous high score shown on the court, in spaced capitals ("RECORD 2 400"). Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Record {score}'**
  String courtRecord(String score);

  /// Gold badge on the court when the player beats the high score during a game. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau record'**
  String get courtNewRecord;

  /// Title of the pause overlay, very big spaced capitals. Max ~8 chars.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pauseTitle;

  /// Under the pause title when there is no high score yet.
  ///
  /// In fr, this message translates to:
  /// **'Score {score}'**
  String pauseScore(String score);

  /// Under the pause title: current score and high score. One line, max ~32 chars.
  ///
  /// In fr, this message translates to:
  /// **'Score {score} · Record {record}'**
  String pauseScoreAndRecord(String score, String record);

  /// Main button of the pause overlay, in capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get pauseResume;

  /// Text button of the pause overlay: back to the home screen, the game is not counted. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la partie'**
  String get pauseQuit;

  /// Small spaced capitals at the top of the game-over card (not a record). Max ~18 chars.
  ///
  /// In fr, this message translates to:
  /// **'Partie terminée'**
  String get gameOverTitle;

  /// Gold badge at the top of the game-over card when the high score was beaten. Max ~18 chars.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau record !'**
  String get gameOverNewRecord;

  /// Under the big final score of the game-over card (no high score yet).
  ///
  /// In fr, this message translates to:
  /// **'points'**
  String get gameOverPoints;

  /// Under the big final score: reminds the high score.
  ///
  /// In fr, this message translates to:
  /// **'points · record {record}'**
  String gameOverPointsWithRecord(String record);

  /// Under the big final score of a record game; {gain} is shown in gold ("+250"). Max ~40 chars.
  ///
  /// In fr, this message translates to:
  /// **'points · {gain} sur l\'ancien record'**
  String gameOverPointsOverRecord(String gain);

  /// Label under the number of times the player hit the ball (small tile, 1/3 of the card). Only the word: the number is displayed above it. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{renvoi} other{renvois}}'**
  String gameOverHits(int count);

  /// Label under the game duration ("3m 20s") on the game-over card (small tile). Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'durée'**
  String get gameOverDuration;

  /// Label under the leaderboard position ("2nd") on the game-over card of a record game (small tile). Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'classement'**
  String get gameOverRank;

  /// Label under the highest speed level reached (small tile, 1/3 of the card). Max ~11 chars.
  ///
  /// In fr, this message translates to:
  /// **'vitesse max'**
  String get gameOverTopSpeed;

  /// Main pink button of the solo game-over card, in capitals. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Rejouer'**
  String get gameOverReplay;

  /// Text button at the bottom of the game-over card. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get gameOverHome;

  /// Leaderboard position, 1 to 10 only ("1" to "10"): game-over tile and screen-reader text of the leaderboard. Short ordinal; keep "{rank, select, ... other{...}}" (one case per number that needs a special form).
  ///
  /// In fr, this message translates to:
  /// **'{rank, select, 1{1er} other{{rank}e}}'**
  String rankOrdinal(String rank);

  /// Title of the empty leaderboard. Max ~26 chars.
  ///
  /// In fr, this message translates to:
  /// **'Aucun score enregistré'**
  String get leaderboardEmptyTitle;

  /// Text of the empty leaderboard, under the title.
  ///
  /// In fr, this message translates to:
  /// **'Joue une partie solo : tes {count} meilleurs scores apparaîtront ici.'**
  String leaderboardEmptyMessage(int count);

  /// Screen-reader text of a leaderboard row without a date. {rank} is an ordinal ("4th").
  ///
  /// In fr, this message translates to:
  /// **'{rank}, {name}, {score} points'**
  String leaderboardRowSemantics(String rank, String name, String score);

  /// Screen-reader text of a leaderboard row with the game date.
  ///
  /// In fr, this message translates to:
  /// **'{rank}, {name}, {score} points, le {date}'**
  String leaderboardRowSemanticsWithDate(String rank, String name, String score, String date);

  /// Shown instead of a nickname when an old leaderboard entry has none.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get leaderboardUnknownPlayer;

  /// Hint under the Solo section title while no game has been played.
  ///
  /// In fr, this message translates to:
  /// **'Joue ta première partie pour remplir ces chiffres.'**
  String get statsSoloEmpty;

  /// Statistics tile title (half the screen width). Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Parties jouées'**
  String get statsGamesPlayed;

  /// Statistics row title, followed by a duration on the right ("7m 29s"). Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Temps total de jeu'**
  String get statsTotalTime;

  /// Statistics row title: most hits in a row in one solo game, followed by "23 hits". Max ~18 chars.
  ///
  /// In fr, this message translates to:
  /// **'Meilleure série'**
  String get statsBestStreak;

  /// Number of hits (times a paddle sent the ball back). Keep the non-breaking space after {countText}. {countText} is {count} already formatted ("1 234"). Used for the best streak (Statistics) and the longest rally (end of duel).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{countText} renvoi} other{{countText} renvois}}'**
  String hitsCount(int count, String countText);

  /// Hint under the Multiplayer section title while no duel has been played.
  ///
  /// In fr, this message translates to:
  /// **'Joue ton premier duel pour remplir ces chiffres.'**
  String get statsMultiplayerEmpty;

  /// Small label above the number of duels won (Statistics). Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Victoires'**
  String get statsWins;

  /// Small label above the number of duels lost (Statistics). Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Défaites'**
  String get statsLosses;

  /// Total number of duels played, between wins and losses (Statistics). {countText} is {count} already formatted.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{countText} duel} other{{countText} duels}}'**
  String duelsCount(int count, String countText);

  /// Screen-reader text of the duel record card; {duels} is the duelsCount text ("19 duels").
  ///
  /// In fr, this message translates to:
  /// **'Victoires : {wins}, défaites : {losses}, {duels}'**
  String statsDuelSemantics(int wins, int losses, String duels);

  /// Help card title. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Contrôles'**
  String get helpControlsTitle;

  /// Help card text: how to control the paddle.
  ///
  /// In fr, this message translates to:
  /// **'Incline le téléphone à gauche ou à droite pour déplacer ta raquette.'**
  String get helpControlsText;

  /// Help card title. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get helpGoalTitle;

  /// Help card text: the aim of a solo game.
  ///
  /// In fr, this message translates to:
  /// **'Renvoie la balle le plus longtemps possible. Si elle passe derrière toi, c\'est fini.'**
  String get helpGoalText;

  /// Help card title. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Points'**
  String get helpPointsTitle;

  /// Help card text: scoring (50 points per hit, 100 when the computer misses).
  ///
  /// In fr, this message translates to:
  /// **'+50 par renvoi, +100 quand l\'adversaire rate.'**
  String get helpPointsText;

  /// Help card title. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse'**
  String get helpSpeedTitle;

  /// Help card text: the ball gets faster every 4 hits.
  ///
  /// In fr, this message translates to:
  /// **'La balle accélère tous les 4 renvois.'**
  String get helpSpeedText;

  /// Help card title. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get helpPauseTitle;

  /// Help card text: how to pause.
  ///
  /// In fr, this message translates to:
  /// **'Touche le bouton pause en haut à droite. Pas de pause en multijoueur.'**
  String get helpPauseText;

  /// Help card text: how a local duel works (two phones on the same network, no internet).
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous au même Wi‑Fi (ou au partage de connexion de l\'un de vous). L\'un crée la partie, l\'autre la rejoint. Premier à 5 points.'**
  String get helpMultiplayerText;

  /// Settings screen title, in spaced capitals. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// Settings section title, spaced capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get settingsSoundSection;

  /// Switch title (Settings). Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get settingsMusic;

  /// Under "Music": where music plays. Max ~26 chars.
  ///
  /// In fr, this message translates to:
  /// **'Accueil et pause'**
  String get settingsMusicSubtitle;

  /// Switch title (Settings). Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Effets sonores'**
  String get settingsEffects;

  /// Under "Sound effects": examples of sounds. Max ~28 chars.
  ///
  /// In fr, this message translates to:
  /// **'Renvois, record, défaite'**
  String get settingsEffectsSubtitle;

  /// Settings section title, spaced capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Jeu'**
  String get settingsGameSection;

  /// Switch title (Settings). Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Vibration'**
  String get settingsVibration;

  /// Under "Vibration": when the phone vibrates. Max ~28 chars.
  ///
  /// In fr, this message translates to:
  /// **'Au renvoi et au record'**
  String get settingsVibrationSubtitle;

  /// Title of the paddle sensitivity slider (0 to 100) and its screen-reader name. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Sensibilité'**
  String get settingsSensitivity;

  /// Explains the sensitivity slider. Must match the words of the slider ends (settingsSensitivityLow / High).
  ///
  /// In fr, this message translates to:
  /// **'Plus vive : la raquette va plus vite et demande moins d\'inclinaison.'**
  String get settingsSensitivityHint;

  /// Left end of the sensitivity slider (value 0). Max ~8 chars.
  ///
  /// In fr, this message translates to:
  /// **'Douce'**
  String get settingsSensitivityLow;

  /// Right end of the sensitivity slider (value 100). Max ~8 chars.
  ///
  /// In fr, this message translates to:
  /// **'Vive'**
  String get settingsSensitivityHigh;

  /// Above a small strip where a paddle follows the phone tilt with the chosen sensitivity. One line, max ~36 chars.
  ///
  /// In fr, this message translates to:
  /// **'Zone d\'essai · penche ton téléphone'**
  String get settingsTrialZone;

  /// Settings section title, spaced capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguageSection;

  /// Language choice that follows the phone language (button, 1/2 of the card width). The other choices are the language names, never translated (Français, English, Español). Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get settingsLanguageAutomatic;

  /// Under the language buttons when "Automatic" is selected; {language} is the language the app uses now, in its own name ("English").
  ///
  /// In fr, this message translates to:
  /// **'Suit la langue du téléphone : {language}'**
  String settingsLanguageAutomaticHint(String language);

  /// Settings section title, spaced capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get settingsProfileSection;

  /// Small label above the nickname (Settings). Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get settingsNickname;

  /// Shown instead of the nickname when none is saved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get settingsNicknameNone;

  /// Text button when no nickname is saved yet. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Choisir'**
  String get settingsNicknameChoose;

  /// Small line at the bottom of Settings and of the Studio page ("Tilto · version 1.1.0"). Do not translate {game}.
  ///
  /// In fr, this message translates to:
  /// **'{game} · version {version}'**
  String settingsVersion(String game, String version);

  /// Text of the nickname dialog (Settings), under the title.
  ///
  /// In fr, this message translates to:
  /// **'Il apparaît dans le classement.'**
  String get nicknameDialogMessage;

  /// Error under the field of the nickname dialog when it is empty.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un pseudo'**
  String get nicknameDialogRequired;

  /// Title of the page about the studio that made the game, in spaced capitals. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Le studio'**
  String get studioTitle;

  /// First sentence of the Studio page; {studio} is shown in bold. Do not translate {game} or {studio}.
  ///
  /// In fr, this message translates to:
  /// **'{game} est un jeu de {studio}.'**
  String studioIntro(String game, String studio);

  /// Button opening the studio website in the browser, in capitals. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Visiter le site'**
  String get studioVisitWebsite;

  /// Text button opening the contact page in the browser. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Écrire au studio'**
  String get studioContact;

  /// Message at the bottom of the screen when the browser cannot be opened; {host} is a web address ("tilto.fun").
  ///
  /// In fr, this message translates to:
  /// **'Le lien ne s\'ouvre pas. Va sur {host} depuis ton navigateur.'**
  String studioLinkFailed(String host);

  /// Small signature at the bottom of Settings and Help, followed by the studio logo: "A game by [logo]". Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Un jeu de'**
  String get studioSignaturePrefix;

  /// Screen-reader text of the signature (the logo is read as the studio name).
  ///
  /// In fr, this message translates to:
  /// **'Un jeu de {studio}'**
  String studioSignatureSemantics(String studio);

  /// Screen-reader text of the signature when it opens the Studio page.
  ///
  /// In fr, this message translates to:
  /// **'Le studio, {studio}'**
  String studioSignatureLink(String studio);

  /// Top of the multiplayer menu; {name} (the nickname) is shown in bold. One line.
  ///
  /// In fr, this message translates to:
  /// **'Tu joues en tant que {name}'**
  String mpPlayingAs(String name);

  /// Big card of the multiplayer menu: host a duel. Also quoted in joinTipCreate. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Créer une partie'**
  String get mpCreateTitle;

  /// Under "Create a game".
  ///
  /// In fr, this message translates to:
  /// **'Ton ami la rejoint depuis son téléphone.'**
  String get mpCreateSubtitle;

  /// Big card of the multiplayer menu: find a game nearby. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une partie'**
  String get mpJoinTitle;

  /// Under "Join a game".
  ///
  /// In fr, this message translates to:
  /// **'Trouve la partie d\'un ami à proximité.'**
  String get mpJoinSubtitle;

  /// Reminder at the bottom of the multiplayer menu: both phones must be on the same local network.
  ///
  /// In fr, this message translates to:
  /// **'Soyez sur le même Wi‑Fi, ou connecte-toi au partage de connexion de l\'autre. Pas besoin d\'Internet.'**
  String get mpNetworkHint;

  /// Title of the "find a game" screen, spaced capitals. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinTitle;

  /// Button: search for games again, in capitals. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get joinRefresh;

  /// Big text under the radar animation while searching. Max ~24 chars.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de parties…'**
  String get joinSearching;

  /// Under "Looking for games…".
  ///
  /// In fr, this message translates to:
  /// **'Reste près de l\'autre joueur, sur le même Wi‑Fi.'**
  String get joinSearchingHint;

  /// Title when the search found nothing. Max ~26 chars.
  ///
  /// In fr, this message translates to:
  /// **'Aucune partie trouvée'**
  String get joinNoGame;

  /// First numbered tip when no game is found.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie que vous êtes sur le même Wi‑Fi ou partage de connexion.'**
  String get joinTipNetwork;

  /// Second numbered tip when no game is found; {action} is the mpCreateTitle text. Use the quotation marks of your language.
  ///
  /// In fr, this message translates to:
  /// **'Demande à l\'autre joueur de toucher « {action} ».'**
  String joinTipCreate(String action);

  /// Status line above the list of games found. One line with joinStillSearching.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} partie à proximité} other{{count} parties à proximité}}'**
  String joinGamesNearby(int count);

  /// Status line while the search goes on; {found} is the joinGamesNearby text. One line, max ~40 chars.
  ///
  /// In fr, this message translates to:
  /// **'{found} · recherche en cours'**
  String joinStillSearching(String found);

  /// Grey badge instead of the Join button when a game already has 2 players. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Complète'**
  String get joinGameFull;

  /// Small pink button on a game row. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinJoin;

  /// Under the game name in the list ("1 / 2 players").
  ///
  /// In fr, this message translates to:
  /// **'{count} / {max} joueurs'**
  String joinPlayers(int count, int max);

  /// Replaces the Join button while connecting. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get joinConnecting;

  /// Name of a game, after the nickname of the player who created it. {elision} is only for French ("d'Inès" before a vowel): keep "{elision, select, other{...}}" around your text.
  ///
  /// In fr, this message translates to:
  /// **'{elision, select, yes{Partie d\'{name}} other{Partie de {name}}}'**
  String gameOf(String elision, String name);

  /// Name of a game when the host nickname is unknown (rare).
  ///
  /// In fr, this message translates to:
  /// **'Partie de ton adversaire'**
  String get gameOfOpponent;

  /// Title of the waiting room before a duel, spaced capitals. Max ~13 chars.
  ///
  /// In fr, this message translates to:
  /// **'Salon'**
  String get lobbyTitle;

  /// Under the game name in the lobby.
  ///
  /// In fr, this message translates to:
  /// **'Duel · premier à {points} points'**
  String lobbyDuelFormat(int points);

  /// Under my nickname in the lobby, when I created the game. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Toi · hôte'**
  String get lobbyYouHost;

  /// Under my nickname in the lobby, when I joined the game.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get lobbyYou;

  /// Under the other nickname: the player who created the game.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get lobbyHost;

  /// Under the other nickname: the player who joined my game.
  ///
  /// In fr, this message translates to:
  /// **'Invité'**
  String get lobbyGuest;

  /// Under the other nickname right after they joined. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Vient de rejoindre'**
  String get lobbyJustJoined;

  /// Green badge on a player row: this player is ready. Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get lobbyReadyStatus;

  /// Grey badge on a player row: not ready yet. Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get lobbyWaitingStatus;

  /// Empty slot of the lobby while nobody has joined. One line.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'un joueur…'**
  String get lobbyWaitingForPlayer;

  /// Under the radar animation while the host waits alone.
  ///
  /// In fr, this message translates to:
  /// **'Ta partie est visible par les joueurs à proximité.'**
  String get lobbyVisible;

  /// Above the disabled Ready button while the host is alone.
  ///
  /// In fr, this message translates to:
  /// **'Disponible dès qu\'un joueur te rejoint'**
  String get lobbyHintAlone;

  /// Above the Ready button when the other player is already ready.
  ///
  /// In fr, this message translates to:
  /// **'{name} t\'attend. À toi !'**
  String lobbyHintOtherReady(String name);

  /// Above the Ready button when nobody is ready yet.
  ///
  /// In fr, this message translates to:
  /// **'La partie démarre quand vous êtes prêts tous les deux'**
  String get lobbyHintBothReady;

  /// Lobby hint and pending button: waiting for the other player. {elision} is only for French: keep "{elision, select, other{...}}" around your text. Max ~30 chars.
  ///
  /// In fr, this message translates to:
  /// **'{elision, select, yes{En attente d\'{name}…} other{En attente de {name}…}}'**
  String waitingFor(String elision, String name);

  /// Same as waitingFor when the nickname is unknown (rare).
  ///
  /// In fr, this message translates to:
  /// **'En attente de ton adversaire…'**
  String get waitingForOpponent;

  /// Main pink button of the lobby, in capitals: I am ready to play. Max ~14 chars.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get lobbyReady;

  /// Secondary button replacing Ready once tapped (cancels it), in capitals. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Je ne suis plus prêt'**
  String get lobbyNotReady;

  /// Text button for the host: close the game. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la partie'**
  String get lobbyCancelGame;

  /// Between the two nicknames above the 3-2-1 countdown, in capitals ("LÉA  VS  TOM").
  ///
  /// In fr, this message translates to:
  /// **'contre'**
  String get countdownVersus;

  /// Under the 3-2-1 countdown, in spaced capitals. Max ~22 chars.
  ///
  /// In fr, this message translates to:
  /// **'Prends ton téléphone'**
  String get countdownGrabPhone;

  /// Small line at the bottom of the countdown. One line, max ~38 chars.
  ///
  /// In fr, this message translates to:
  /// **'À deux mains, prêt à incliner'**
  String get countdownHint;

  /// Duel header, in capitals ("DUEL · FIRST TO 5"). Max ~26 chars.
  ///
  /// In fr, this message translates to:
  /// **'Duel · premier à {points}'**
  String duelHudFormat(int points);

  /// Red warning in the duel header when the network is slow. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Connexion faible'**
  String get duelConnectionWeak;

  /// Screen-reader text of the Wi-Fi icon in the duel header when all is fine.
  ///
  /// In fr, this message translates to:
  /// **'Bonne connexion'**
  String get duelConnectionGood;

  /// Screen-reader text of the duel score ("Léa 3, Tom 2").
  ///
  /// In fr, this message translates to:
  /// **'{myName} {myScore}, {opponentName} {opponentScore}'**
  String duelScoreSemantics(String myName, int myScore, String opponentName, int opponentScore);

  /// Badge in the middle of the court right after a point. Max ~24 chars with the name.
  ///
  /// In fr, this message translates to:
  /// **'Point pour {name}'**
  String duelPointFor(String name);

  /// Under the score after a point, counting down the seconds before the next serve.
  ///
  /// In fr, this message translates to:
  /// **'Reprise dans {seconds}…'**
  String duelResumeIn(int seconds);

  /// Big spaced capitals title of the end-of-duel screen (winner). Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Victoire'**
  String get resultVictory;

  /// Big spaced capitals title of the end-of-duel screen (loser). Max ~10 chars.
  ///
  /// In fr, this message translates to:
  /// **'Défaite'**
  String get resultDefeat;

  /// Under the title of the end-of-duel screen.
  ///
  /// In fr, this message translates to:
  /// **'{name} gagne !'**
  String resultWinner(String name);

  /// Under the final score after a win; {duration} looks like "2m 14s", {rally} is the hitsCount text ("14 hits").
  ///
  /// In fr, this message translates to:
  /// **'{duration} · plus long échange : {rally}'**
  String resultDetail(String duration, String rally);

  /// Under the final score after a narrow loss (by 1 or 2 points).
  ///
  /// In fr, this message translates to:
  /// **'Si près ! La revanche ?'**
  String get resultCloseLoss;

  /// Under the final score after a clear loss.
  ///
  /// In fr, this message translates to:
  /// **'La revanche ?'**
  String get resultLoss;

  /// Status line above the buttons once I asked for a rematch.
  ///
  /// In fr, this message translates to:
  /// **'Tu veux rejouer · {name} n\'a pas encore répondu'**
  String rematchIAsked(String name);

  /// Status line when the other player asked for a rematch.
  ///
  /// In fr, this message translates to:
  /// **'{name} veut rejouer'**
  String rematchOpponentAsked(String name);

  /// End-of-duel status line and incident title: the other player left.
  ///
  /// In fr, this message translates to:
  /// **'{name} a quitté la partie'**
  String opponentLeftGame(String name);

  /// Main pink button of the end-of-duel screen (ask for or accept a rematch), in capitals. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Rejouer'**
  String get resultRematch;

  /// Dialog title (host side): the guest phone is gone.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue avec {name}'**
  String incidentOpponentLostTitle(String name);

  /// Dialog text under incidentOpponentLostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ta partie reste ouverte : {name} peut la rejoindre à nouveau.'**
  String incidentOpponentLostMessage(String name);

  /// Dialog button, in capitals. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour au salon'**
  String get incidentBackToLobby;

  /// Dialog text (guest side) when the host left on purpose.
  ///
  /// In fr, this message translates to:
  /// **'La partie est terminée. Tu peux en rejoindre une autre ou créer la tienne.'**
  String get incidentHostLeftMessage;

  /// Dialog button, in capitals. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour au menu'**
  String get incidentBackToMenu;

  /// Dialog title (guest side): the host stopped answering.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue'**
  String get incidentConnectionLostTitle;

  /// Dialog text under incidentConnectionLostTitle.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne répond plus. Vérifie que vous êtes toujours sur le même Wi‑Fi.'**
  String incidentConnectionLostMessage(String name);

  /// Dialog title: joining a game failed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get incidentConnectionFailedTitle;

  /// Dialog text under incidentConnectionFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie que vous êtes sur le même Wi‑Fi, puis réessaie.'**
  String get incidentConnectionFailedMessage;

  /// Dialog button, in capitals. Max ~16 chars.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get incidentRetry;

  /// Dialog text button (go back). Max ~12 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get incidentBack;

  /// Dialog title: the game already has 2 players.
  ///
  /// In fr, this message translates to:
  /// **'Partie complète'**
  String get incidentGameFullTitle;

  /// Dialog text under incidentGameFullTitle.
  ///
  /// In fr, this message translates to:
  /// **'{name} joue déjà avec quelqu\'un. Choisis une autre partie ou crée la tienne.'**
  String incidentGameFullMessage(String name);

  /// Dialog button, in capitals. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la liste'**
  String get incidentBackToList;

  /// Dialog title: the phone is on no local network.
  ///
  /// In fr, this message translates to:
  /// **'Pas de Wi‑Fi'**
  String get incidentNoWifiTitle;

  /// Dialog text under incidentNoWifiTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi à un Wi‑Fi ou au partage de connexion de l\'autre joueur, puis réessaie.'**
  String get incidentNoWifiMessage;

  /// Confirmation dialog title after the Android back button during a duel.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le duel ?'**
  String get incidentLeaveDuelTitle;

  /// Confirmation dialog text.
  ///
  /// In fr, this message translates to:
  /// **'Le duel s\'arrête pour {name} aussi.'**
  String incidentLeaveDuelMessage(String name);

  /// Main button of the leave confirmation (the safe choice), in capitals. Max ~20 chars.
  ///
  /// In fr, this message translates to:
  /// **'Continuer le duel'**
  String get incidentKeepPlaying;

  /// Dialog title: the two phones have different app versions.
  ///
  /// In fr, this message translates to:
  /// **'Versions différentes'**
  String get incidentVersionTitle;

  /// Dialog text under incidentVersionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Installe la même version du jeu sur les deux téléphones, puis réessaie.'**
  String get incidentVersionMessage;

  /// Dialog title: the duel stopped because the app went to the background.
  ///
  /// In fr, this message translates to:
  /// **'Partie fermée'**
  String get incidentClosedTitle;

  /// Dialog text under incidentClosedTitle.
  ///
  /// In fr, this message translates to:
  /// **'La partie s\'arrête quand le jeu passe en arrière-plan. Tu peux en créer ou en rejoindre une autre.'**
  String get incidentClosedMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
