import 'package:flutter/material.dart';

/// Brand palette. Was a light Glassdoor-style white/black/gray base;
/// flipped to a black-background dark palette (per request), keeping the
/// same Glassdoor Green (#0CAA41) brand accent for CTAs, ratings, and
/// "positive" states.
///
/// Kept as a standalone class (rather than only living inside
/// [AppTheme.light]) so screens that need a color the [ColorScheme]
/// doesn't expose a slot for (e.g. star ratings, chip backgrounds) can
/// reference it directly instead of hardcoding a new hex value — several
/// screens do exactly that (see e.g. `public_job_board_screen.dart`,
/// `cv_builder_shared.dart`), so changing these values alone is enough to
/// re-theme the whole app without touching every call site.
class AppColors {
  const AppColors._();

  // Brand
  static const green = Color(0xFF0CAA41);
  static const greenDark = Color(0xFF3FD474);
  static const greenSurface = Color(0xFF123A22);

  // Ink, inverted for dark mode: near-white text, dimmer grays for
  // secondary/tertiary content.
  static const ink = Color(0xFFF2F4F3);
  static const inkMuted = Color(0xFFA7AEB0);
  static const inkFaint = Color(0xFF6E7477);

  // Neutrals — true black page background, with a slightly-raised
  // near-black for cards/surfaces so content still reads as separated
  // from the page instead of blending flat into it.
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const border = Color(0xFF2A2C2D);
  static const divider = Color(0xFF232526);

  // Semantic
  static const rating = green;
  static const warning = Color(0xFFE0AC4E);
  static const warningSurface = Color(0xFF3A2E10);
  static const error = Color(0xFFE8776F);
  static const errorSurface = Color(0xFF3A1613);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.green,
          onPrimary: Colors.black,
          primaryContainer: AppColors.greenSurface,
          onPrimaryContainer: AppColors.greenDark,
          secondary: AppColors.ink,
          onSecondary: Colors.black,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          error: AppColors.error,
          onError: Colors.black,
          outline: AppColors.inkMuted,
          outlineVariant: AppColors.border,
        ),
        background: AppColors.background,
        surface: AppColors.surface,
        border: AppColors.border,
        divider: AppColors.divider,
        ink: AppColors.ink,
        inkMuted: AppColors.inkMuted,
        inkFaint: AppColors.inkFaint,
        green: AppColors.green,
        greenDark: AppColors.greenDark,
        greenSurface: AppColors.greenSurface,
        error: AppColors.error,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color background,
    required Color surface,
    required Color border,
    required Color divider,
    required Color ink,
    required Color inkMuted,
    required Color inkFaint,
    required Color green,
    required Color greenDark,
    required Color greenSurface,
    required Color error,
  }) {
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
        backgroundColor: surface,
        indicatorColor: greenSurface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? greenDark : inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? greenDark : inkMuted,
          ),
        ),
      ),
    );
  }
}
