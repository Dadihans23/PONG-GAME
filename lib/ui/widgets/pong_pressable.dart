// Base commune de tous les éléments tactiles du système de design.
//
// Usage interne aux composants Pong… : un fond décoré (animé quand il change,
// par exemple à la sélection), l'ondulation Material au toucher, un léger
// enfoncement (échelle 0,97) et la sémantique « bouton ». `onTap == null`
// rend l'élément désactivé. On ne l'utilise directement que pour un élément
// tactile qui n'existe pas encore dans le kit.
import 'package:flutter/material.dart';

import '../pong_tokens.dart';

class PongPressable extends StatefulWidget {
  const PongPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.decoration = const BoxDecoration(),
    this.borderRadius = PongRadii.buttonAll,
    this.padding = EdgeInsets.zero,
    this.height,
    this.width,
    this.minHeight = PongSizes.touchTarget,
    this.minWidth = PongSizes.touchTarget,
    this.pressedScale = 0.97,
    this.semanticLabel,
    this.selected,
    this.alignment = Alignment.center,
  });

  /// Action au toucher ; `null` = désactivé.
  final VoidCallback? onTap;
  final Widget child;
  final BoxDecoration decoration;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;

  /// Zone tactile minimale (48 px par défaut).
  final double minHeight;
  final double minWidth;

  /// Échelle pendant l'appui (1 = pas d'enfoncement).
  final double pressedScale;

  /// Libellé lu par le lecteur d'écran, si le contenu n'est pas un texte.
  final String? semanticLabel;

  /// État sélectionné annoncé au lecteur d'écran (`null` = non concerné).
  final bool? selected;
  final AlignmentGeometry alignment;

  @override
  State<PongPressable> createState() => _PongPressableState();
}

class _PongPressableState extends State<PongPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && enabled ? widget.pressedScale : 1,
        duration: PongDurations.fast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: PongDurations.normal,
          curve: Curves.easeOut,
          height: widget.height,
          width: widget.width,
          constraints: BoxConstraints(
            minHeight: widget.minHeight,
            minWidth: widget.minWidth,
          ),
          decoration: widget.decoration.copyWith(
            borderRadius: widget.borderRadius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              borderRadius: widget.borderRadius,
              splashColor: const Color(0x1FFFFFFF),
              highlightColor: const Color(0x0FFFFFFF),
              child: Padding(
                padding: widget.padding,
                child: Align(
                  alignment: widget.alignment,
                  widthFactor: widget.width == null ? 1 : null,
                  heightFactor: widget.height == null ? 1 : null,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
