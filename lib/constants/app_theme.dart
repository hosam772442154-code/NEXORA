import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Nexora IT — Unified Design System
/// ─────────────────────────────────────────────────────────────────────────────
/// A single source of truth for every visual property in the application.
/// Import this file instead of hard-coding colors, radii, or text styles
/// anywhere in the widget tree.
///
/// Usage:
///   import 'package:nexora_it/constants/app_theme.dart';
///
///   // Colors
///   AppTheme.primaryColor
///   AppTheme.accentColor
///
///   // Full MaterialApp theme
///   MaterialApp(theme: AppTheme.lightTheme, ...)
/// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._(); // Prevent instantiation.

  // ───────────────────────────── COLORS ─────────────────────────────

  /// Deep Royal Blue — main active cards and prominent elements.
  static const Color primaryColor = Color(0xFF003399);

  /// Neon Cyan — glowing highlights, active text, and special buttons.
  static const Color accentColor = Color(0xFF00F0FF);

  /// Clean Off-White — uniform background for all application screens.
  static const Color backgroundColor = Color(0xFFF8F9FA);

  /// Soft Silver Gray — grid tiles, form fields, and card surfaces.
  static const Color cardColor = Color(0xFFF0F2F5);

  /// Dark Navy Black — high-contrast titles and body text.
  static const Color textColor = Color(0xFF0A1931);

  // ──────────────── DERIVED / SEMANTIC COLORS ──────────────────────

  /// Slightly muted version of [textColor] for subtitles and captions.
  static const Color secondaryTextColor = Color(0xFF3D4F6F);

  /// Divider / subtle border color — derived from the silver-gray family.
  static const Color dividerColor = Color(0xFFD6DAE0);

  /// Success feedback color.
  static const Color successColor = Color(0xFF00C853);

  /// Error / destructive action color.
  static const Color errorColor = Color(0xFFE53935);

  /// Warning / attention color.
  static const Color warningColor = Color(0xFFFFA726);

  /// A deeper shade of [primaryColor] for pressed / hover states.
  static const Color primaryDark = Color(0xFF002270);

  /// A lighter tint of [primaryColor] used for subtle highlights.
  static const Color primaryLight = Color(0xFFE8EEFF);

  /// Semi-transparent overlay used for glass-morphism / shimmer effects.
  static const Color overlayColor = Color(0x26003399); // 15 % primary

  // ─────────────────── BORDER RADIUS (uniform) ─────────────────────

  /// The single, canonical border radius shared by every card, button,
  /// text field, dialog, and bottom sheet in the application.
  static const double borderRadiusValue = 20.0;

  /// Pre-built [BorderRadius] for convenience.
  static final BorderRadius borderRadius =
      BorderRadius.circular(borderRadiusValue);

  /// Pre-built [RoundedRectangleBorder] for convenience.
  static final RoundedRectangleBorder roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadiusValue),
  );

  // ────────────────────── SPACING TOKENS ───────────────────────────

  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ──────────────────── ELEVATION / SHADOW ─────────────────────────

  /// Standard card shadow — soft, non-intrusive elevation.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  /// Stronger shadow for modals, dialogs, and floating action buttons.
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  /// Neon-glow shadow used for accent-highlighted elements.
  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.35),
          blurRadius: 20,
          spreadRadius: -4,
        ),
      ];

  // ───────────────────── TYPOGRAPHY ────────────────────────────────

  static const String _fontFamily = 'Roboto'; // Default material font

  static const TextStyle headingLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textColor,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textColor,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textColor,
    letterSpacing: 0.0,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textColor,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textColor,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: secondaryTextColor,
    height: 1.45,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textColor,
    letterSpacing: 0.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
    letterSpacing: 0.3,
  );

  // ─────────────── COMMON DECORATIONS (helpers) ────────────────────

  /// Standard card decoration — rounded, soft shadow, silver-gray fill.
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        boxShadow: cardShadow,
      );

  /// Active / selected card decoration with primary-blue border and glow.
  static BoxDecoration get activeCardDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(color: primaryColor, width: 2),
        boxShadow: glowShadow,
      );

  /// Input field decoration base.
  static BoxDecoration get inputDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(color: dividerColor, width: 1),
      );

  // ═══════════════════════════════════════════════════════════════════
  //  FULL MATERIAL THEME
  // ═══════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: cardColor,

      // ── Color Scheme ──────────────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryColor,
        secondary: accentColor,
        onSecondary: textColor,
        surface: cardColor,
        onSurface: textColor,
        error: errorColor,
        onError: Colors.white,
        outline: dividerColor,
      ),

      // ── Divider ───────────────────────────────────────────────────
      dividerColor: dividerColor,
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 0,
      ),

      // ── AppBar ────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),

      // ── Card ──────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Input / Text Field ────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: secondaryTextColor,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: secondaryTextColor,
          fontSize: 14,
        ),
        prefixIconColor: secondaryTextColor,
        suffixIconColor: secondaryTextColor,
      ),

      // ── SnackBar ──────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textColor,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Bottom Navigation ─────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Progress Indicators ───────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: dividerColor,
      ),

      // ── Icons ─────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: textColor, size: 24),

      // ── Dialog ────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: secondaryTextColor,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadiusValue),
            topRight: Radius.circular(borderRadiusValue),
          ),
        ),
      ),

      // ── Floating Action Button ────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
      ),

      // ── Chip ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: primaryLight,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        side: const BorderSide(color: dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
      ),

      // ── Tooltip ───────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textColor,
          borderRadius: BorderRadius.circular(borderRadiusValue / 2),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}
