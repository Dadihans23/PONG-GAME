import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/game/game_tuning.dart';
import 'package:pong_game/game/paddle_sensitivity.dart';
import 'package:pong_game/game/tilt_control.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/l10n/l10n.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/studio/studio_page.dart';
import 'package:pong_game/ui/pong_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Réglages, ouverts par l'icône ⚙ de l'accueil.
///
/// Chaque réglage s'applique et s'enregistre au toucher : pas de bouton
/// « Enregistrer », donc pas de rose plein sur l'écran. Ordre : ce qu'on
/// change le plus souvent d'abord (son), puis le jeu, le profil, et la
/// langue, réglée une fois pour toutes.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.settings, this.accelerometer});

  /// Réglages à afficher (tests) ; par défaut ceux de la boîte Hive.
  final PongSettings? settings;

  /// Mesures de l'accéléromètre pour la zone d'essai (tests) ; par défaut
  /// le capteur du téléphone.
  final Stream<AccelerometerEvent>? accelerometer;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final PongSettings _settings = widget.settings ?? PongSettings();

  // Aperçu des effets sonores : le clic de l'accueil
  final GameSound _clickSound = GameSound('sounds/shoot.mp3');

  late bool _music = _settings.musicEnabled;
  late bool _effects = _settings.soundEffectsEnabled;
  late bool _vibration = _settings.vibrationEnabled;
  late int _sensitivity = _settings.paddleSensitivity;
  late String? _pseudo = _settings.pseudo;
  late AppLanguage _language = _settings.language;

  @override
  void dispose() {
    _clickSound.dispose();
    super.dispose();
  }

  void _setMusic(bool value) {
    setState(() => _music = value);
    _settings.musicEnabled = value;
    // Arrête ou relance tout de suite la musique de l'accueil
    GameSound.musicEnabled = value;
  }

  void _setEffects(bool value) {
    setState(() => _effects = value);
    _settings.soundEffectsEnabled = value;
    GameSound.effectsEnabled = value;
    // Le joueur entend tout de suite ce qu'il vient de réactiver
    if (value) _clickSound.play();
  }

  void _setVibration(bool value) {
    setState(() => _vibration = value);
    _settings.vibrationEnabled = value;
    if (value) HapticFeedback.lightImpact();
  }

  // Pendant le glissement : affichage et zone d'essai seulement, petit
  // retour haptique toutes les 10 unités
  void _setSensitivity(int value) {
    if (value == _sensitivity) return;
    setState(() => _sensitivity = value);
    if (_vibration && value % 10 == 0) HapticFeedback.selectionClick();
  }

  // Au relâchement : une seule écriture dans Hive
  void _saveSensitivity(int value) {
    if (value != _sensitivity) setState(() => _sensitivity = value);
    _settings.paddleSensitivity = value;
  }

  // Langue : enregistrée et appliquée tout de suite à toute l'app
  void _setLanguage(AppLanguage value) {
    if (value == _language) return;
    setState(() => _language = value);
    _settings.language = value;
    AppLanguageSetting.current.value = value;
    if (_vibration) HapticFeedback.selectionClick();
  }

  Future<void> _editPseudo() async {
    final pseudo = await showPongDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _PseudoDialog(initial: _pseudo ?? ''),
    );
    if (pseudo == null || !mounted) return;
    final saved = _settings.savePseudo(pseudo);
    if (saved != null) setState(() => _pseudo = saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PongPageScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        children: [
          PongOverline(l10n.settingsSoundSection),
          const SizedBox(height: PongSpacing.sm),
          PongCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PongSwitchRow(
                  icon: Icons.music_note_rounded,
                  title: l10n.settingsMusic,
                  subtitle: l10n.settingsMusicSubtitle,
                  value: _music,
                  onChanged: _setMusic,
                ),
                const PongCardDivider(),
                PongSwitchRow(
                  icon: Icons.volume_up_rounded,
                  title: l10n.settingsEffects,
                  subtitle: l10n.settingsEffectsSubtitle,
                  value: _effects,
                  onChanged: _setEffects,
                ),
              ],
            ),
          ),
          const SizedBox(height: PongSpacing.lg),
          PongOverline(l10n.settingsGameSection),
          const SizedBox(height: PongSpacing.sm),
          PongCard(
            padding: EdgeInsets.zero,
            child: PongSwitchRow(
              icon: Icons.vibration_rounded,
              title: l10n.settingsVibration,
              subtitle: l10n.settingsVibrationSubtitle,
              value: _vibration,
              onChanged: _setVibration,
            ),
          ),
          const SizedBox(height: PongSpacing.sm),
          _SensitivityCard(
            value: _sensitivity,
            onChanged: _setSensitivity,
            onChangeEnd: _saveSensitivity,
            accelerometer: widget.accelerometer,
          ),
          const SizedBox(height: PongSpacing.lg),
          PongOverline(l10n.settingsProfileSection),
          const SizedBox(height: PongSpacing.sm),
          _PseudoCard(pseudo: _pseudo, onEdit: _editPseudo),
          const SizedBox(height: PongSpacing.lg),
          PongOverline(l10n.settingsLanguageSection),
          const SizedBox(height: PongSpacing.sm),
          _LanguageCard(selected: _language, onChanged: _setLanguage),
          const SizedBox(height: PongSpacing.xl),
          // Pied de page : la signature ouvre la page « Le studio »
          PongStudioSignature(
            caption: l10n.settingsVersion(Brand.gameName, Brand.appVersion),
            onTap: () => StudioPage.open(context),
          ),
        ],
      ),
    );
  }
}

/// Langue : Automatique (celle du téléphone), Français, English, Español,
/// en grille de 2 × 2. Chaque langue est écrite dans sa propre langue, pour
/// que le joueur reconnaisse la sienne même dans une app qu'il ne lit pas.
/// Sous « Automatique », la langue que le téléphone donne à l'app.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.selected, required this.onChanged});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  Widget _button(BuildContext context, AppLanguage language) {
    return Expanded(
      child: PongSelectableButton(
        key: ValueKey('langue-${language.code}'),
        label: language.nativeName ?? context.l10n.settingsLanguageAutomatic,
        selected: language == selected,
        onPressed: () => onChanged(language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String current = AppLanguage.ofLanguageCode(
            Localizations.localeOf(context).languageCode)
        .nativeName!;
    const gap = SizedBox(width: PongSpacing.xs);
    return PongCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _button(context, AppLanguage.system),
            gap,
            _button(context, AppLanguage.french),
          ]),
          const SizedBox(height: PongSpacing.xs),
          Row(children: [
            _button(context, AppLanguage.english),
            gap,
            _button(context, AppLanguage.spanish),
          ]),
          if (selected == AppLanguage.system) ...[
            const SizedBox(height: PongSpacing.sm),
            Text(
              l10n.settingsLanguageAutomaticHint(current),
              style: PongText.caption
                  .copyWith(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sensibilité de la raquette : curseur de 0 (« Douce ») à 100 (« Vive »),
/// valeur en haut à droite, puis la zone d'essai.
class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.accelerometer,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  final Stream<AccelerometerEvent>? accelerometer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edgeStyle =
        PongText.caption.copyWith(fontSize: 12, color: PongColors.textTertiary);
    return PongCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PongIconBadge(
                icon: Icons.screen_rotation_rounded,
                size: 40,
                iconSize: 22,
                color: PongColors.textSecondary,
                background: PongColors.surfaceHigh,
              ),
              const SizedBox(width: PongSpacing.sm),
              Expanded(
                child: Text(l10n.settingsSensitivity,
                    style: PongText.cardTitle.copyWith(fontSize: 16)),
              ),
              Text(
                '$value',
                key: const ValueKey('sensibilite-valeur'),
                style: PongText.listValue.copyWith(color: PongColors.pinkLight),
              ),
            ],
          ),
          const SizedBox(height: PongSpacing.sm),
          Text(
            l10n.settingsSensitivityHint,
            style: PongText.caption
                .copyWith(fontSize: 12, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: PongSpacing.xs),
          PongSlider(
            value: value,
            min: PaddleSensitivity.min,
            max: PaddleSensitivity.max,
            semanticLabel: l10n.settingsSensitivity,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PongSpacing.xs),
              child: Row(
                children: [
                  Text(l10n.settingsSensitivityLow, style: edgeStyle),
                  const Spacer(),
                  Text(l10n.settingsSensitivityHigh, style: edgeStyle),
                ],
              ),
            ),
          ),
          const SizedBox(height: PongSpacing.md),
          _TiltTrial(sensitivity: value, accelerometer: accelerometer),
        ],
      ),
    );
  }
}

/// Zone d'essai : une mini-raquette bleue, comme celle du jeu, qui suit
/// l'inclinaison du téléphone avec la sensibilité affichée.
///
/// L'accéléromètre n'est écouté que tant que cette zone est affichée (donc
/// l'écran Réglages ouvert) et que l'app est au premier plan ; il est libéré
/// en sortie. La raquette avance à chaque image, comme en partie, et ne
/// bouge qu'après la première mesure du capteur.
class _TiltTrial extends StatefulWidget {
  const _TiltTrial({required this.sensitivity, this.accelerometer});

  final int sensitivity;
  final Stream<AccelerometerEvent>? accelerometer;

  /// Hauteur de la piste d'essai.
  static const double height = 56;

  @override
  State<_TiltTrial> createState() => _TiltTrialState();
}

class _TiltTrialState extends State<_TiltTrial>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TiltControl _tilt = PaddleSensitivity.tiltControl(widget.sensitivity);
  late final Ticker _ticker;
  StreamSubscription<AccelerometerEvent>? _subscription;
  Duration _lastElapsed = Duration.zero;
  AccelerometerEvent? _lastEvent; // Dernière mesure, pour changer de réglage
  double _x = 0; // Position de la raquette, de -1 à 1

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(_TiltTrial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensitivity != widget.sensitivity) {
      // Nouveau réglage : même inclinaison, nouvelle courbe
      _tilt = PaddleSensitivity.tiltControl(widget.sensitivity);
      final event = _lastEvent;
      if (event != null) {
        _tilt.setAcceleration(event.x, event.y, event.z);
        _tilt.reset();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _ticker.dispose();
    super.dispose();
  }

  void _listen() {
    _subscription ??= (widget.accelerometer ??
            accelerometerEventStream(samplingPeriod: GameTuning.sensorPeriod))
        .listen(
      _onSensor,
      onError: (Object e) => debugPrint('Accéléromètre indisponible : $e'),
    );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    if (_ticker.isActive) _ticker.stop();
  }

  void _onSensor(AccelerometerEvent event) {
    _lastEvent = event;
    _tilt.setAcceleration(event.x, event.y, event.z);
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _tilt.reset();
      _ticker.start();
    }
  }

  void _onFrame(Duration elapsed) {
    // Image très longue : plafonnée comme le rattrapage du jeu
    final double dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000)
        .clamp(0.0, GameTuning.maxStepsPerFrame / GameTuning.stepsPerSecond);
    _lastElapsed = elapsed;
    final double x = (_x + _tilt.update(dt) * dt).clamp(-1.0, 1.0);
    if (x != _x && mounted) setState(() => _x = x);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.settingsTrialZone,
          style: PongText.caption
              .copyWith(fontSize: 12, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: PongSpacing.xs),
        Container(
          key: const ValueKey('zone-essai'),
          height: _TiltTrial.height,
          decoration: const BoxDecoration(
            color: PongColors.background,
            borderRadius: PongRadii.segmentAll,
            border: Border.fromBorderSide(
                BorderSide(color: PongColors.borderSubtle)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: PongSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double travel = (constraints.maxWidth - PongSizes.paddleWidth)
                  .clamp(0.0, double.infinity);
              return Stack(
                children: [
                  // Repère du centre
                  const Center(
                    child: SizedBox(
                      width: 1,
                      height: 20,
                      child: ColoredBox(color: PongColors.courtMidline),
                    ),
                  ),
                  Positioned(
                    key: const ValueKey('raquette-essai'),
                    left: (_x + 1) / 2 * travel,
                    top: (_TiltTrial.height - PongSizes.paddleHeight) / 2 - 1,
                    child: Container(
                      width: PongSizes.paddleWidth,
                      height: PongSizes.paddleHeight,
                      decoration: BoxDecoration(
                        color: PongColors.player,
                        borderRadius:
                            BorderRadius.circular(PongSizes.paddleHeight / 2),
                        boxShadow: PongShadows.playerPaddle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pseudo actuel (bleu : c'est toi) et « Modifier ».
class _PseudoCard extends StatelessWidget {
  const _PseudoCard({required this.pseudo, required this.onEdit});

  final String? pseudo;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final pseudo = this.pseudo;
    final l10n = context.l10n;
    return PongCard(
      padding: const EdgeInsets.fromLTRB(
          PongSpacing.md, PongSpacing.sm, PongSpacing.xxs, PongSpacing.sm),
      child: Row(
        children: [
          const PongIconBadge(
            icon: Icons.person_rounded,
            size: 40,
            iconSize: 22,
            color: PongColors.playerLight,
          ),
          const SizedBox(width: PongSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.settingsNickname,
                    style: PongText.caption
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text(
                  pseudo ?? l10n.settingsNicknameNone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PongText.cardTitle.copyWith(
                    fontSize: 16,
                    color: pseudo == null
                        ? PongColors.textSecondary
                        : PongColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PongTextButton(
            label: pseudo == null
                ? l10n.settingsNicknameChoose
                : l10n.commonEdit,
            icon: Icons.edit_rounded,
            color: PongColors.pinkLight,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// Dialogue de saisie du pseudo. Renvoie le pseudo nettoyé, ou `null` si
/// le joueur annule.
class _PseudoDialog extends StatefulWidget {
  const _PseudoDialog({required this.initial});

  final String initial;

  @override
  State<_PseudoDialog> createState() => _PseudoDialogState();
}

class _PseudoDialogState extends State<_PseudoDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final pseudo = PongSettings.cleanPseudo(_controller.text);
    if (pseudo == null) {
      setState(() {
        _error = context.l10n.nicknameDialogRequired;
        _shake++;
      });
      return;
    }
    Navigator.of(context).pop(pseudo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: PongDialogCard(
        title: l10n.nicknameFieldLabel,
        message: l10n.nicknameDialogMessage,
        content: PongTextField(
          controller: _controller,
          hintText: l10n.nicknameFieldHint,
          errorText: _error,
          shakeTrigger: _shake,
          autofocus: true,
          maxLength: PongSettings.pseudoMaxLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
        ),
        actions: [
          PongPrimaryButton(label: l10n.commonSave, onPressed: _save),
          PongTextButton(
            label: l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
