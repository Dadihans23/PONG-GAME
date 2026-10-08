// Curseur (écran Réglages, sensibilité de la raquette).
//
// Règle de sélection du kit : la partie choisie de la piste est rose, le
// bouton rose clair avec un halo rose léger, jamais un bloc rose plein. La
// zone tactile du bouton fait 48 px (halo de 24 px de rayon).
//
// ```dart
// PongSlider(
//   value: _sensitivity,
//   max: 100,
//   semanticLabel: 'Sensibilité',
//   onChanged: (v) => setState(() => _sensitivity = v),
//   onChangeEnd: _save,
// )
// ```
import 'package:flutter/material.dart';

import '../pong_colors.dart';
import '../pong_tokens.dart';

class PongSlider extends StatelessWidget {
  const PongSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.semanticLabel,
  }) : assert(min < max);

  /// Valeur entière, de [min] à [max] (ramenée dans ces bornes).
  final int value;
  final int min;
  final int max;

  /// Appelé à chaque cran franchi pendant le glissement. `null` = désactivé.
  final ValueChanged<int>? onChanged;

  /// Appelé au relâchement (pour enregistrer une seule fois).
  final ValueChanged<int>? onChangeEnd;

  /// Nom lu par le lecteur d'écran, suivi de la valeur.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final onChangeEnd = this.onChangeEnd;
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: PongColors.pink,
        inactiveTrackColor: PongColors.surfaceHigh,
        disabledActiveTrackColor: PongColors.textDisabled,
        disabledInactiveTrackColor: PongColors.surfaceDisabled,
        // Pas de points de cran sur la piste : 100 crans feraient un pointillé
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        thumbColor: PongColors.pinkLight,
        disabledThumbColor: PongColors.textDisabled,
        overlayColor: PongColors.alpha(PongColors.pink, 0.16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        overlayShape: const RoundSliderOverlayShape(
            overlayRadius: PongSizes.touchTarget / 2),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max).toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        label: '${value.clamp(min, max)}',
        onChanged: onChanged == null ? null : (v) => onChanged(v.round()),
        onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd(v.round()),
      ),
    );
    final label = semanticLabel;
    if (label == null) return slider;
    return Semantics(label: label, container: true, child: slider);
  }
}
