// Thème Material sombre de l'app, construit sur les jetons PongColors,
// PongText et PongTokens. Branché dans `MaterialApp(theme: PongTheme.dark())`.
//
// Le thème donne des valeurs par défaut cohérentes (police Archivo, fond,
// curseur rose, dialogues sombres, barres de progression roses…) aux widgets
// Material qu'on utilise encore directement. Pour les éléments de la maquette,
// préférer les composants `Pong…` de lib/ui/widgets/, qui ne dépendent pas
// du thème pour leur rendu.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pong_colors.dart';
import 'pong_text.dart';
import 'pong_tokens.dart';

abstract final class PongTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: PongColors.pink,
      onPrimary: Colors.white,
      primaryContainer: PongColors.pinkTint,
      onPrimaryContainer: PongColors.textPrimary,
      secondary: PongColors.pinkLight,
      onSecondary: Colors.white,
      tertiary: PongColors.player,
      onTertiary: Colors.white,
      error: PongColors.error,
      onError: Colors.white,
      surface: PongColors.surface,
      onSurface: PongColors.textPrimary,
      onSurfaceVariant: PongColors.textSecondary,
      surfaceContainerLowest: PongColors.black,
      surfaceContainerLow: PongColors.background,
      surfaceContainer: PongColors.surface,
      surfaceContainerHigh: PongColors.surfaceHigh,
      surfaceContainerHighest: PongColors.surfaceHigh,
      outline: PongColors.border,
      outlineVariant: PongColors.borderSubtle,
      shadow: Colors.black,
      scrim: PongColors.scrim,
      inverseSurface: PongColors.textPrimary,
      onInverseSurface: PongColors.background,
      surfaceTint: Colors.transparent,
    );

    const textTheme = TextTheme(
      displayLarge: PongText.gameScore,
      displayMedium: PongText.logo,
      displaySmall: PongText.keyFigure,
      headlineMedium: PongText.headline,
      headlineSmall: PongText.dialogTitle,
      titleLarge: PongText.cardTitle,
      titleMedium: PongText.buttonLabelPlain,
      titleSmall: PongText.screenTitle,
      bodyLarge: PongText.body,
      // Style par défaut de tout `Text` sans style : on ne fixe que la
      // couleur pour ne pas changer l'interligne des écrans existants.
      bodyMedium: TextStyle(color: PongColors.textBody),
      bodySmall: PongText.caption,
      labelLarge: PongText.buttonLabelPlain,
      labelMedium: PongText.caption,
      labelSmall: PongText.overline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: PongText.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: PongColors.background,
      canvasColor: PongColors.background,
      dividerColor: PongColors.borderSubtle,
      splashFactory: InkRipple.splashFactory,
      highlightColor: const Color(0x0FFFFFFF),
      splashColor: const Color(0x1AFFFFFF),
      iconTheme: const IconThemeData(color: PongColors.textPrimary, size: 24),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: PongColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: PongSizes.headerBar,
        titleTextStyle: PongText.screenTitle,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: PongColors.surface,
        surfaceTintColor: Colors.transparent,
        barrierColor: PongColors.scrim,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: PongRadii.dialogAll,
          side: BorderSide(color: PongColors.border),
        ),
        titleTextStyle: PongText.dialogTitle,
        contentTextStyle: PongText.body,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: PongColors.surface,
        hintStyle: TextStyle(color: PongColors.textTertiary, fontSize: 16),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: PongRadii.fieldAll,
          borderSide: BorderSide(color: PongColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PongRadii.fieldAll,
          borderSide: BorderSide(color: PongColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PongRadii.fieldAll,
          borderSide: BorderSide(color: PongColors.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PongRadii.fieldAll,
          borderSide: BorderSide(color: PongColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: PongRadii.fieldAll,
          borderSide: BorderSide(color: PongColors.error, width: 1.5),
        ),
        errorStyle: TextStyle(color: PongColors.errorText, fontSize: 13),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: PongColors.pinkLight,
        selectionColor: Color(0x66E91E63),
        selectionHandleColor: PongColors.pink,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PongColors.pink,
        linearTrackColor: PongColors.surfaceHigh,
        circularTrackColor: PongColors.surfaceHigh,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PongColors.surfaceHigh,
        contentTextStyle: PongText.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: PongRadii.fieldAll),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: PongColors.surfaceHigh,
          borderRadius: PongRadii.segmentAll,
        ),
        textStyle: PongText.caption,
      ),
    );
  }
}
