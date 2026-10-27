import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF0A0D0B);
  static const obsidian = Color(0xFF080B09);
  static const glowDeep = Color(0xFF1B4332);
  static const glowIvory = Color(0xFFD8F3DC);
  static const glowSoft = Color(0xFFB7E4C7);
  static const surface = Color(0xFF111714);
  static const elevated = Color(0xFF16201B);
  static const border = Color(0xFF1E2621);
  static const ivory = Color(0xFFF2F0E8);
  static const sage = Color(0xFF95A39B);
  static const accent = Color(0xFF2D6A4F);
  static const accentBright = Color(0xFF40916C);
  static const mint = Color(0xFF52B788);
}

class AppTheme {
  static ThemeData dark() {
    const text = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 64,
        fontWeight: FontWeight.w500,
        height: 0.96,
        letterSpacing: -1.4,
        color: AppColors.ivory,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 34,
        fontWeight: FontWeight.w500,
        height: 1.05,
        letterSpacing: -0.6,
        color: AppColors.ivory,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: AppColors.ivory,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.ivory,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 16,
        height: 1.45,
        color: AppColors.ivory,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 14,
        height: 1.45,
        color: AppColors.ivory,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 13,
        height: 1.4,
        color: AppColors.sage,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: AppColors.sage,
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.mint,
        secondary: AppColors.accentBright,
        onSurface: AppColors.ivory,
        onPrimary: AppColors.background,
        outline: AppColors.border,
      ),
      textTheme: text,
      iconTheme: const IconThemeData(color: AppColors.sage, size: 22),
      dividerColor: AppColors.border,
      splashColor: AppColors.mint.withValues(alpha: 0.08),
      highlightColor: AppColors.mint.withValues(alpha: 0.05),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.mint,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.ivory,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        trackHeight: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: text.bodySmall?.copyWith(color: AppColors.ivory),
      ),
    );
  }

  static const tabular = TextStyle(
    fontFamily: 'Outfit',
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.sage,
  );
}

InputDecoration xernoField(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: AppColors.sage, fontFamily: 'Outfit'),
    hintStyle: const TextStyle(color: AppColors.sage),
    filled: true,
    fillColor: AppColors.elevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.mint),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}
