// Champ de texte : défaut · focus · erreur (maquette, section 05).
//
// 56 px, rayon 14, surface #15151C. Focus : contour rose 1,5 px + anneau
// rose 4 px. Erreur : contour rouge + anneau rouge + message en clair sous
// le champ, et le champ tremble (comme le champ pseudo actuel).
//
// Le champ tremble quand `errorText` apparaît, et à chaque changement de
// `shakeTrigger` (pour redemander l'attention si l'erreur est déjà affichée) :
//
// ```dart
// PongTextField(
//   controller: _name,
//   label: 'Ton pseudo',
//   hintText: 'Entre ton pseudo',
//   errorText: _error,              // null = pas d'erreur
//   shakeTrigger: _errorCount,      // ++ à chaque tentative refusée
// )
// ```
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pong_colors.dart';
import '../pong_text.dart';
import '../pong_tokens.dart';

class PongTextField extends StatefulWidget {
  const PongTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.errorText,
    this.shakeTrigger = 0,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Libellé au-dessus du champ (« Ton pseudo »).
  final String? label;

  /// Texte d'exemple dans le champ vide (« Entre ton pseudo »).
  final String? hintText;

  /// Message d'erreur en clair ; `null` = pas d'erreur.
  final String? errorText;

  /// Change cette valeur pour faire trembler le champ à nouveau.
  final int shakeTrigger;
  final bool enabled;
  final bool autofocus;

  /// Nombre maximal de caractères (sans compteur affiché).
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PongTextField> createState() => _PongTextFieldState();
}

class _PongTextFieldState extends State<PongTextField>
    with SingleTickerProviderStateMixin {
  FocusNode? _ownFocusNode;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: PongDurations.shake);

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PongTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
    final errorAppeared =
        oldWidget.errorText == null && widget.errorText != null;
    if (errorAppeared || oldWidget.shakeTrigger != widget.shakeTrigger) {
      _shake.forward(from: 0);
    }
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    final Color borderColor = hasError
        ? PongColors.error
        : focused
            ? PongColors.pink
            : PongColors.border;
    final Color? ringColor = hasError
        ? PongColors.errorRing
        : focused
            ? PongColors.pinkRing
            : null;
    final label = widget.label;
    final errorText = widget.errorText;

    final field = AnimatedContainer(
      duration: PongDurations.normal,
      height: PongSizes.field,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: PongSpacing.md),
      decoration: BoxDecoration(
        color: PongColors.surface,
        borderRadius: PongRadii.fieldAll,
        border: Border.all(
          color: borderColor,
          width: hasError || focused ? 1.5 : 1,
        ),
        boxShadow: ringColor == null
            ? null
            : [BoxShadow(color: ringColor, spreadRadius: 4)],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        inputFormatters: widget.maxLength == null
            ? null
            : [LengthLimitingTextInputFormatter(widget.maxLength)],
        cursorColor: PongColors.pinkLight,
        style: PongText.body.copyWith(
          fontSize: 16,
          height: 1.25,
          color: widget.enabled
              ? PongColors.textPrimary
              : PongColors.textDisabled,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hintText,
          hintStyle: PongText.body.copyWith(
            fontSize: 16,
            height: 1.25,
            color: PongColors.textTertiary,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label,
              style: PongText.caption.copyWith(fontWeight: FontWeight.w400)),
          const SizedBox(height: PongSpacing.xs),
        ],
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: field,
        ),
        if (errorText != null) ...[
          const SizedBox(height: PongSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.error_rounded,
                      size: 16, color: PongColors.errorText),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText,
                    style: PongText.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: PongColors.errorText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
