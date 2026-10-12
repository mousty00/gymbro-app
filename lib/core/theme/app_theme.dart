import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette: chiara, pulita, con gradienti azzurro/lilla morbidi.
class AppColors {
  const AppColors._();

  static const ink = Color(0xFF111322);
  static const inkSoft = Color(0xFF5B6075);
  static const muted = Color(0xFF9A9FB2);
  static const bg = Color(0xFFF3F5FA);
  static const card = Colors.white;
  static const stroke = Color(0xFFE9ECF3);

  static const blue = Color(0xFF4C7CF5);
  static const blueSoft = Color(0xFFE3EBFE);
  static const lilac = Color(0xFF8E7CF8);
  static const lilacSoft = Color(0xFFEDE8FE);
  static const pink = Color(0xFFF39BDF);
  static const pinkSoft = Color(0xFFFCE4F6);
  static const mint = Color(0xFF2FB475);
  static const mintSoft = Color(0xFFDFF5EA);
  static const amber = Color(0xFFF2B33D);
  static const danger = Color(0xFFE5484D);

  static const skyTop = Color(0xFFD6E2FB);
  static const skyMid = Color(0xFFEAE7FB);

  static const brandGradient = LinearGradient(
    colors: [blue, lilac],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadius {
  const AppRadius._();
  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 28.0;
}

class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x0F1B2559), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const float = [
    BoxShadow(color: Color(0x1F1B2559), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.lilac,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );

  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.6, height: 1.05),
      displayMedium: text.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.4, height: 1.05),
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.0, height: 1.1),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.6),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      bodyMedium: text.bodyMedium?.copyWith(color: AppColors.inkSoft, height: 1.45),
      bodySmall: text.bodySmall?.copyWith(color: AppColors.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.ink,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        textStyle: text.titleMedium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.stroke),
        shape: const StadiumBorder(),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.stroke),
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge?.copyWith(color: AppColors.ink),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.stroke, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.blue),
  );
}
