import 'package:flutter/material.dart';

/// Design tokens for the "Workora"-inspired look: an off-white page ground,
/// white rounded cards with soft shadows, near-black text/primary actions,
/// and a small set of pastel accent colors for status (success/warning/
/// error/info). Kept as plain static fields (not a ThemeExtension) since
/// every value here is used directly by name in bespoke widgets, not just
/// through the ambient Theme.
class AppColors {
  AppColors._();

  // Light palette.
  static const pageBackground = Color(0xFFF4F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFAFAFB);
  static const border = Color(0xFFE7E7EB);
  static const borderStrong = Color(0xFFD8D8DE);

  static const textPrimary = Color(0xFF121214);
  static const textSecondary = Color(0xFF6E6E76);
  static const textTertiary = Color(0xFFA1A1AA);

  /// The near-black used for primary buttons and the active nav pill.
  static const ink = Color(0xFF141416);
  static const inkOn = Color(0xFFFFFFFF);

  /// The lime/chartreuse accent used sparingly for a single standout CTA.
  static const accent = Color(0xFFD6F24E);
  static const accentOn = Color(0xFF1B2400);

  static const success = Color(0xFF1FA463);
  static const successBg = Color(0xFFE6F7ED);
  static const warning = Color(0xFFB4790A);
  static const warningBg = Color(0xFFFBF0DC);
  static const danger = Color(0xFFE0405F);
  static const dangerBg = Color(0xFFFCE9EC);
  static const info = Color(0xFF3B7EF0);
  static const infoBg = Color(0xFFE9F0FE);

  // Dark palette - same roles, inverted ground.
  static const darkPageBackground = Color(0xFF0C0C0E);
}

/// Dark-mode counterparts of the surface/text roles above (kept in a
/// private class so callers always go through [buildAppTheme] rather than
/// picking light/dark fields by hand).
class _DarkPalette {
  static const surface = Color(0xFF19191C);
  static const surfaceMuted = Color(0xFF141416);
  static const border = Color(0xFF2A2A2E);
  static const borderStrong = Color(0xFF37373C);
  static const textPrimary = Color(0xFFF2F2F3);
  static const textSecondary = Color(0xFFA1A1AA);
  static const ink = Color(0xFFF2F2F3);
  static const inkOn = Color(0xFF141416);
}

class AppRadius {
  AppRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> card(Brightness brightness) => [
        BoxShadow(
          color: (brightness == Brightness.dark ? Colors.black : const Color(0xFF1A1A2E))
              .withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final pageBg = isDark ? AppColors.darkPageBackground : AppColors.pageBackground;
  final surface = isDark ? _DarkPalette.surface : AppColors.surface;
  final surfaceMuted = isDark ? _DarkPalette.surfaceMuted : AppColors.surfaceMuted;
  final border = isDark ? _DarkPalette.border : AppColors.border;
  final borderStrong = isDark ? _DarkPalette.borderStrong : AppColors.borderStrong;
  final textPrimary = isDark ? _DarkPalette.textPrimary : AppColors.textPrimary;
  final textSecondary = isDark ? _DarkPalette.textSecondary : AppColors.textSecondary;
  final ink = isDark ? _DarkPalette.ink : AppColors.ink;
  final inkOn = isDark ? _DarkPalette.inkOn : AppColors.inkOn;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: ink,
    onPrimary: inkOn,
    secondary: AppColors.accent,
    onSecondary: AppColors.accentOn,
    error: AppColors.danger,
    onError: Colors.white,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: surfaceMuted,
    outline: border,
    outlineVariant: border,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: colorScheme);

  final textTheme = base.textTheme
      .apply(fontFamily: 'Inter', bodyColor: textPrimary, displayColor: textPrimary)
      .copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontFamily: 'Inter', color: textPrimary),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontFamily: 'Inter', color: textSecondary),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: pageBg,
    textTheme: textTheme,
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: textSecondary, size: 20),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: inkOn,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: borderStrong),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: surfaceMuted,
        foregroundColor: textPrimary,
        padding: const EdgeInsets.all(10),
        shape: const CircleBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMuted,
      selectedColor: ink,
      disabledColor: surfaceMuted,
      labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: textPrimary, fontSize: 12.5),
      secondaryLabelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: inkOn, fontSize: 12.5),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: textSecondary, fontFamily: 'Inter', fontSize: 13),
      labelStyle: TextStyle(color: textSecondary, fontFamily: 'Inter', fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: ink, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: textPrimary,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: border),
      ),
      textStyle: TextStyle(fontFamily: 'Inter', color: textPrimary, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontFamily: 'Inter', color: inkOn, fontSize: 12),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textSecondary,
      textColor: textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: textSecondary,
      ),
      dataTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: textPrimary),
      dividerThickness: 1,
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      dataRowColor: WidgetStateProperty.all(Colors.transparent),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? ink : border,
      ),
    ),
  );
}
