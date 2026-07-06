import 'package:flutter/material.dart';

/// Retro terminal look: monospace-by-default, square corners, hairline
/// borders instead of shadows, near-black/off-white backgrounds with a
/// configurable accent color (Claude orange by default) -- an actual
/// console, not a Material app wearing terminal colors.
class AppTheme {
  AppTheme._();

  static const _darkBackground = Color(0xFF0A0C0A);
  static const _darkSurface = Color(0xFF111411);
  static const _darkText = Color(0xFFE6E6E1);
  static const _darkBorder = Color(0xFF2E322E);

  static const _lightBackground = Color(0xFFF2F1E6);
  static const _lightSurface = Color(0xFFE9E8D8);
  static const _lightText = Color(0xFF1B1C17);
  static const _lightBorder = Color(0xFFBFBBA0);

  static (String, List<String>) _fontFor(String choice) => switch (choice) {
        'comicSans' => ('Comic Sans MS', const ['Comic Sans MS', 'Chalkboard SE', 'sans-serif']),
        'consolas' => ('Consolas', const ['Consolas', 'Courier New', 'monospace']),
        'courierNew' => ('Courier New', const ['Courier New', 'Courier', 'monospace']),
        'georgia' => ('Georgia', const ['Georgia', 'Times New Roman', 'serif']),
        _ => (
            'monospace',
            const ['Consolas', 'Courier New', 'DejaVu Sans Mono', 'Liberation Mono', 'Ubuntu Mono'],
          ),
      };

  static ThemeData light({int accentColor = 0xFFD97757, String fontChoice = 'monospace'}) =>
      _build(Brightness.light, Color(accentColor), fontChoice);

  static ThemeData dark({int accentColor = 0xFFD97757, String fontChoice = 'monospace'}) =>
      _build(Brightness.dark, Color(accentColor), fontChoice);

  static ThemeData _build(Brightness brightness, Color accent, String fontChoice) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? _darkBackground : _lightBackground;
    final surface = isDark ? _darkSurface : _lightSurface;
    final border = isDark ? _darkBorder : _lightBorder;
    final onSurface = isDark ? _darkText : _lightText;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: background,
      secondary: accent,
      onSecondary: background,
      error: const Color(0xFFFF5555),
      onError: background,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: border,
      onSurfaceVariant: onSurface.withValues(alpha: 0.7),
      outline: border,
      outlineVariant: border,
      primaryContainer: surface,
      onPrimaryContainer: accent,
      tertiary: accent,
    );

    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final (fontFamily, fontFallback) = _fontFor(fontChoice);
    final monoText = base.textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );
    const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: accent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: monoText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: square.copyWith(side: BorderSide(color: border)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: square.copyWith(side: BorderSide(color: border)),
        side: BorderSide(color: border),
        selectedColor: accent.withValues(alpha: 0.2),
        labelStyle: monoText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      textTheme: monoText.copyWith(
        titleMedium: monoText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: monoText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        bodySmall: monoText.bodySmall?.copyWith(color: onSurface.withValues(alpha: 0.65)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: square,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: square,
          side: BorderSide(color: accent),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: square,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: accent,
          shape: square.copyWith(side: BorderSide(color: border)),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: square,
          side: BorderSide(color: border),
          selectedBackgroundColor: accent.withValues(alpha: 0.2),
          selectedForegroundColor: accent,
          foregroundColor: onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: square.copyWith(side: BorderSide(color: border)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: square.copyWith(side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      switchTheme: SwitchThemeData(
        // Material's default OFF track blends into a near-black background
        // -- make both states clearly readable: OFF is an outlined track on
        // `surface`, ON is filled with the accent color.
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : border,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? background : onSurface,
        ),
      ),
    );
  }
}
