import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pong_game/game_sound.dart';
import 'package:pong_game/settings/pong_settings.dart';
import 'package:pong_game/ui/pong_ui.dart';

/// Réglages, ouverts par l'icône ⚙ de l'accueil.
///
/// Chaque réglage s'applique et s'enregistre au toucher : pas de bouton
/// « Enregistrer », donc pas de rose plein sur l'écran. Ordre : ce qu'on
/// change le plus souvent d'abord (son), puis le jeu, puis le profil.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.settings});

  /// Réglages à afficher (tests) ; par défaut ceux de la boîte Hive.
  final PongSettings? settings;

  /// Version affichée en bas : la même que `version:` dans pubspec.yaml
  /// (vérifié par test/settings_test.dart).
  static const String appVersion = '1.0.0';

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

  void _setSensitivity(int value) {
    if (value == _sensitivity) return;
    setState(() => _sensitivity = value);
    _settings.paddleSensitivity = value;
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
    return PongPageScaffold(
      title: 'Réglages',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PongSpacing.screen, PongSpacing.xxs,
            PongSpacing.screen, PongSpacing.screen),
        children: [
          const PongOverline('Son'),
          const SizedBox(height: PongSpacing.sm),
          PongCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PongSwitchRow(
                  icon: Icons.music_note_rounded,
                  title: 'Musique',
                  subtitle: 'Accueil et pause',
                  value: _music,
                  onChanged: _setMusic,
                ),
                const PongCardDivider(),
                PongSwitchRow(
                  icon: Icons.volume_up_rounded,
                  title: 'Effets sonores',
                  subtitle: 'Renvois, record, défaite',
                  value: _effects,
                  onChanged: _setEffects,
                ),
              ],
            ),
          ),
          const SizedBox(height: PongSpacing.lg),
          const PongOverline('Jeu'),
          const SizedBox(height: PongSpacing.sm),
          PongCard(
            padding: EdgeInsets.zero,
            child: PongSwitchRow(
              icon: Icons.vibration_rounded,
              title: 'Vibration',
              subtitle: 'Au renvoi et au record',
              value: _vibration,
              onChanged: _setVibration,
            ),
          ),
          const SizedBox(height: PongSpacing.sm),
          _SensitivityCard(
            selected: _sensitivity,
            onChanged: _setSensitivity,
          ),
          const SizedBox(height: PongSpacing.lg),
          const PongOverline('Profil'),
          const SizedBox(height: PongSpacing.sm),
          _PseudoCard(pseudo: _pseudo, onEdit: _editPseudo),
          const SizedBox(height: PongSpacing.xl),
          Text(
            'PONG · version ${SettingsPage.appVersion}',
            textAlign: TextAlign.center,
            style: PongText.caption.copyWith(
                fontSize: 12, color: PongColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Sensibilité de la raquette : 5 crans en barres croissantes (plus haut =
/// plus vif), le cran choisi encadré de rose, son nom en haut à droite.
class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = PongSettings.paddleSensitivityLabels;
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
                child: Text('Sensibilité',
                    style: PongText.cardTitle.copyWith(fontSize: 16)),
              ),
              Text(
                labels[selected],
                style: PongText.caption.copyWith(
                    fontWeight: FontWeight.w700, color: PongColors.pinkLight),
              ),
            ],
          ),
          const SizedBox(height: PongSpacing.sm),
          Text(
            'Plus vive : la raquette va plus vite pour la même inclinaison.',
            style: PongText.caption
                .copyWith(fontSize: 12, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: PongSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _SensitivityStep(
                    index: i,
                    count: labels.length,
                    label: labels[i],
                    lit: i <= selected,
                    selected: i == selected,
                    onTap: () => onChanged(i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: PongSpacing.xs),
          ExcludeSemantics(
            child: Row(
              children: [
                Text('Douce', style: edgeStyle),
                const Spacer(),
                Text('Vive', style: edgeStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un cran : barre verticale dont la hauteur grandit avec le cran.
class _SensitivityStep extends StatelessWidget {
  const _SensitivityStep({
    required this.index,
    required this.count,
    required this.label,
    required this.lit,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final int count;
  final String label;

  /// Barre allumée : crans jusqu'au cran choisi.
  final bool lit;
  final bool selected;
  final VoidCallback onTap;

  static const double _minBar = 8;
  static const double _maxBar = 28;

  @override
  Widget build(BuildContext context) {
    final barHeight = _minBar + (_maxBar - _minBar) * index / (count - 1);
    return PongPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: 'Sensibilité $label',
      height: PongSizes.touchTarget,
      width: double.infinity,
      minWidth: 0,
      borderRadius: PongRadii.segmentAll,
      decoration: BoxDecoration(
        color: selected ? PongColors.pinkTintSolid : PongColors.surfaceHigh,
        border: Border.all(
          color: selected ? PongColors.pink : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: selected ? PongShadows.selected : null,
      ),
      child: AnimatedContainer(
        duration: PongDurations.normal,
        width: 6,
        height: barHeight,
        decoration: BoxDecoration(
          color: lit ? PongColors.pinkLight : PongColors.textDisabled,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
        ),
      ),
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
                Text('Pseudo',
                    style: PongText.caption
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text(
                  pseudo ?? 'Aucun',
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
            label: pseudo == null ? 'Choisir' : 'Modifier',
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
        _error = 'Choisis un pseudo';
        _shake++;
      });
      return;
    }
    Navigator.of(context).pop(pseudo);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PongDialogCard(
        title: 'Ton pseudo',
        message: 'Il apparaît dans le classement.',
        content: PongTextField(
          controller: _controller,
          hintText: 'Entre ton pseudo',
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
          PongPrimaryButton(label: 'Enregistrer', onPressed: _save),
          PongTextButton(
            label: 'Annuler',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
