import 'package:flutter/material.dart';

abstract final class SaydianColors {
  static const ink = Color(0xFF171B2B);
  static const muted = Color(0xFF5F6675);
  static const canvas = Color(0xFFF4F7FB);
  static const line = Color(0xFFDDE3EC);
  static const outline = Color(0xFF98A2B3);
  static const techBlue = Color(0xFF316EF5);
  static const techBlueSoft = Color(0xFFEAF1FF);
  static const techIndigo = Color(0xFF4F5FE7);
  static const techIndigoSoft = Color(0xFFEBEDFF);
  static const techCyan = Color(0xFF149FB3);
  static const techCyanDark = Color(0xFF0D7484);
  static const techCyanSoft = Color(0xFFE3F7FA);
  static const techViolet = Color(0xFF6A58E8);
  static const techVioletSoft = Color(0xFFF0EDFF);
  static const techBlueDark = Color(0xFF244BA8);

  // Compatibility aliases for older page code. Say Ring no longer uses red
  // and gold as interface chrome; semantic errors keep their own danger red.
  static const brandRed = techBlue;
  static const brandRedDark = techBlueDark;
  static const brandGold = techCyan;
  static const brandGoldDark = techCyanDark;
  static const goldText = techCyanDark;
  static const brandRedSoft = techBlueSoft;
  static const brandGoldSoft = techCyanSoft;

  // Semantic colors stay independent from the brand palette. This keeps a
  // successful/normal state green and a warning amber after the interface
  // chrome turns blue and cyan. All are dark enough for text on white.
  static const success = Color(0xFF287A3B);
  static const info = Color(0xFF2467A6);
  static const warning = Color(0xFF8A4B00);
  static const danger = Color(0xFFB3261E);
  static const heart = techViolet;
  static const temperature = Color(0xFF146A75);

  // Backwards-compatible metric aliases used by the existing pages.
  static const green = success;
  static const blue = info;
  static const orange = warning;
  static const pink = heart;
  static const cyan = temperature;
}

ThemeData buildSaydianTheme() {
  const scheme = ColorScheme.light(
    primary: SaydianColors.techBlue,
    onPrimary: Colors.white,
    primaryContainer: SaydianColors.techBlueSoft,
    onPrimaryContainer: Color(0xFF173A82),
    secondary: SaydianColors.techViolet,
    onSecondary: Colors.white,
    secondaryContainer: SaydianColors.techVioletSoft,
    onSecondaryContainer: SaydianColors.ink,
    surface: Colors.white,
    onSurface: SaydianColors.ink,
    error: SaydianColors.danger,
    onError: Colors.white,
    outline: SaydianColors.outline,
    outlineVariant: SaydianColors.line,
  );

  const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 34, height: 1.2),
    displayMedium: TextStyle(fontSize: 31, height: 1.22),
    displaySmall: TextStyle(fontSize: 28, height: 1.25),
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.28,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.32,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.35,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.55),
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodySmall: TextStyle(fontSize: 14, height: 1.45),
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SaydianColors.canvas,
    useMaterial3: true,
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
    textTheme: textTheme.apply(
      bodyColor: SaydianColors.ink,
      displayColor: SaydianColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: SaydianColors.canvas,
      foregroundColor: SaydianColors.ink,
      titleTextStyle: TextStyle(
        color: SaydianColors.ink,
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: const Color(0x12316EF5),
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDCE7F5)),
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: SaydianColors.muted, fontSize: 16),
      labelStyle: const TextStyle(color: SaydianColors.muted, fontSize: 16),
      helperStyle: const TextStyle(color: SaydianColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SaydianColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SaydianColors.techBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SaydianColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: SaydianColors.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: SaydianColors.techBlue,
        side: const BorderSide(color: Color(0xFFB8CCED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundColor: SaydianColors.techBlue,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        iconSize: 24,
        foregroundColor: SaydianColors.ink,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: SaydianColors.techBlue,
      textColor: SaydianColors.ink,
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: TextStyle(
        color: SaydianColors.ink,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(
        color: SaydianColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: SaydianColors.line,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 78,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: SaydianColors.techBlueSoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? SaydianColors.techBlue
              : SaydianColors.muted,
          size: states.contains(WidgetState.selected) ? 29 : 27,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? SaydianColors.techBlue
              : SaydianColors.muted,
          fontSize: 14,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SaydianColors.techBlue,
      linearTrackColor: SaydianColors.techBlueSoft,
      circularTrackColor: SaydianColors.techBlueSoft,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: SaydianColors.techBlueSoft,
      side: const BorderSide(color: Color(0xFFDCE7F5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(
        color: SaydianColors.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : SaydianColors.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SaydianColors.techBlue
            : SaydianColors.line,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SaydianColors.techBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
  );
}

const saydianSoftGradient = LinearGradient(
  colors: [Color(0xFFF2F6FF), SaydianColors.canvas, SaydianColors.techCyanSoft],
  stops: [0, 0.5, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const saydianPanelGradient = LinearGradient(
  colors: [Colors.white, Color(0xFFF0F6FF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const saydianHeroGradient = LinearGradient(
  colors: [SaydianColors.techBlue, SaydianColors.techIndigo],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
