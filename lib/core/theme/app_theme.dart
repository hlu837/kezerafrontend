import 'package:flutter/material.dart';

/// One named color palette (light or dark). Kept as a plain data holder so
/// [AppColors] can hold two `const` instances of it and just switch which
/// one it reads from at runtime.
class _Palette {
  const _Palette({
    required this.green,
    required this.greenDark,
    required this.greenSurface,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.background,
    required this.surface,
    required this.border,
    required this.divider,
    required this.warning,
    required this.warningSurface,
    required this.error,
    required this.errorSurface,
  });

  final Color green;
  final Color greenDark;
  final Color greenSurface;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color background;
  final Color surface;
  final Color border;
  final Color divider;
  final Color warning;
  final Color warningSurface;
  final Color error;
  final Color errorSurface;
}

/// Default palette: white background, near-black text, the same brand
/// green used everywhere for CTAs/ratings/"positive" states. Matches the
/// reference "Jobs based on your activity" mock — this is what a
/// first-time / theme-unset user sees.
const _lightPalette = _Palette(
  green: Color(0xFF0CAA41),
  greenDark: Color(0xFF0A8E37),
  greenSurface: Color(0xFFE3F6E9),
  ink: Color(0xFF16181A),
  inkMuted: Color(0xFF5B6266),
  inkFaint: Color(0xFF8B9296),
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  border: Color(0xFFE3E5E7),
  divider: Color(0xFFECEDEE),
  warning: Color(0xFFB3791C),
  warningSurface: Color(0xFFFBF0DC),
  error: Color(0xFFC0392B),
  errorSurface: Color(0xFFFBEAE7),
);

/// Black-background palette — same brand green, inverted ink/surfaces.
const _darkPalette = _Palette(
  green: Color(0xFF0CAA41),
  greenDark: Color(0xFF3FD474),
  greenSurface: Color(0xFF123A22),
  ink: Color(0xFFF2F4F3),
  inkMuted: Color(0xFFA7AEB0),
  inkFaint: Color(0xFF6E7477),
  background: Color(0xFF000000),
  surface: Color(0xFF121212),
  border: Color(0xFF2A2C2D),
  divider: Color(0xFF232526),
  warning: Color(0xFFE0AC4E),
  warningSurface: Color(0xFF3A2E10),
  error: Color(0xFFE8776F),
  errorSurface: Color(0xFF3A1613),
);

/// Brand palette, readable as `AppColors.background` etc. from anywhere —
/// several screens reach for a color the [ColorScheme] doesn't expose a
/// slot for (star ratings, chip backgrounds) and read these fields
/// directly instead of going through `Theme.of(context)`.
///
/// Backed by [AppThemeController.isDark] rather than fixed `const`
/// values, so those call sites automatically follow the light/dark
/// toggle in Settings without needing to be rewritten — as soon as the
/// controller flips and the app rebuilds, every getter here starts
/// returning the other palette's colors.
class AppColors {
  const AppColors._();

  static _Palette get _active =>
      AppThemeController.isDark ? _darkPalette : _lightPalette;

  static Color get green => _active.green;
  static Color get greenDark => _active.greenDark;
  static Color get greenSurface => _active.greenSurface;
  static Color get ink => _active.ink;
  static Color get inkMuted => _active.inkMuted;
  static Color get inkFaint => _active.inkFaint;
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get border => _active.border;
  static Color get divider => _active.divider;
  static Color get rating => _active.green;
  static Color get warning => _active.warning;
  static Color get warningSurface => _active.warningSurface;
  static Color get error => _active.error;
  static Color get errorSurface => _active.errorSurface;
}

/// The single source of truth for which palette is active. A plain static
/// flag (not a ChangeNotifier itself) — [ThemeModeNotifier]
/// (theme_mode_controller.dart) is what persists the choice and triggers
/// the rebuild that makes the new value visible; this just holds the
/// current value so [AppColors] and [AppTheme] can read it synchronously
/// during that rebuild, including for widgets that don't go through
/// `Theme.of(context)` at all.
class AppThemeController {
  const AppThemeController._();
  static bool isDark = false;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        colorScheme: ColorScheme.light(
          primary: _lightPalette.green,
          onPrimary: Colors.white,
          primaryContainer: _lightPalette.greenSurface,
          onPrimaryContainer: _lightPalette.greenDark,
          secondary: _lightPalette.ink,
          onSecondary: Colors.white,
          surface: _lightPalette.surface,
          onSurface: _lightPalette.ink,
          error: _lightPalette.error,
          onError: Colors.white,
          outline: _lightPalette.inkMuted,
          outlineVariant: _lightPalette.border,
        ),
        palette: _lightPalette,
      );

  static ThemeData get dark => _build(
        colorScheme: ColorScheme.dark(
          primary: _darkPalette.green,
          onPrimary: Colors.black,
          primaryContainer: _darkPalette.greenSurface,
          onPrimaryContainer: _darkPalette.greenDark,
          secondary: _darkPalette.ink,
          onSecondary: Colors.black,
          surface: _darkPalette.surface,
          onSurface: _darkPalette.ink,
          error: _darkPalette.error,
          onError: Colors.black,
          outline: _darkPalette.inkMuted,
          outlineVariant: _darkPalette.border,
        ),
        palette: _darkPalette,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required _Palette palette,
  }) {
    final background = palette.background;
    final surface = palette.surface;
    final border = palette.border;
    final divider = palette.divider;
    final ink = palette.ink;
    final inkMuted = palette.inkMuted;
    final inkFaint = palette.inkFaint;
    final green = palette.green;
    final greenDark = palette.greenDark;
    final greenSurface = palette.greenSurface;
    final error = palette.error;

    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

    final textTheme = base.textTheme
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.3,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.2,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(color: ink),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: ink,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: inkMuted,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(fontFamily: 'Roboto');

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: ink),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: green.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: green.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: border, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: inkMuted),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: background,
        disabledColor: background,
        selectedColor: greenSurface,
        secondarySelectedColor: greenSurface,
        labelStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: greenDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error),
        ),
        labelStyle: TextStyle(color: inkMuted),
        hintStyle: TextStyle(color: inkFaint),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? green : border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? green : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: green,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),

      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: green,
        unselectedLabelColor: inkMuted,
        indicatorColor: green,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: surface,
        indicatorColor: greenSurface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? greenDark : inkMuted,
          ),
        ),
        // Default NavigationBar icon size is 24 (selected gets a larger
        // indicator pill around it, which reads as "too big" against the
        // 11px label). Sizing both states down to 20 keeps the bar compact
        // without the icons looking cramped next to the label text.
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected) ? greenDark : inkMuted,
          ),
        ),
      ),
    );
  }
}
