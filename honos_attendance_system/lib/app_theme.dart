import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color bgBase;
  final Color bgSurface;
  final Color bgCard;
  final Color bgElevated;
  final Color txtPrimary;
  final Color txtSec;
  final Color txtMuted;
  final Color green;
  final Color red;
  final Color yellow;
  final Color purple;
  final Color bord;
  final Color cardBg;
  final Color glass;
  final Color glassBorder;
  final Color blue;
  final Color shimmer;

  const AppColors({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.bgBase,
    required this.bgSurface,
    required this.bgCard,
    required this.bgElevated,
    required this.txtPrimary,
    required this.txtSec,
    required this.txtMuted,
    required this.green,
    required this.red,
    required this.yellow,
    required this.purple,
    required this.bord,
    required this.cardBg,
    required this.glass,
    required this.glassBorder,
    required this.blue,
    required this.shimmer,
  });

  @override
  ThemeExtension<AppColors> copyWith() {
    return this; // Simplification, not typically needed to copy uniquely here
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      txtPrimary: Color.lerp(txtPrimary, other.txtPrimary, t)!,
      txtSec: Color.lerp(txtSec, other.txtSec, t)!,
      txtMuted: Color.lerp(txtMuted, other.txtMuted, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      bord: Color.lerp(bord, other.bord, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      shimmer: Color.lerp(shimmer, other.shimmer, t)!,
    );
  }

  LinearGradient get accentGradient => LinearGradient(
        colors: [primary, primary.withValues(alpha: 0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get darkHeaderGradient => LinearGradient(colors: [bgBase, bgSurface]);

  BoxDecoration get glassDecoration => BoxDecoration(
    color: glass,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glassBorder),
  );
}

extension ThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  // Existing static constants for fallback/backward compatibility if absolutely needed,
  // but we shouldn't use them in UI directly anymore.
  static const primary      = Color(0xFF3B82F6);
  static const primaryDark  = Color(0xFF1D4ED8);
  static const secondary    = Color(0xFFE63946); 

  // Dark Theme Colors
  static const AppColors darkColors = AppColors(
    primary: Color(0xFF3B82F6),
    primaryDark: Color(0xFF1D4ED8),
    secondary: Color(0xFFE63946),
    bgBase: Color(0xFF0F172A),
    bgSurface: Color(0xFF1E293B),
    bgCard: Color(0xFF1E293B),
    bgElevated: Color(0xFF334155),
    txtPrimary: Color(0xFFFFFFFF),
    txtSec: Color(0xFFCAD4E0),
    txtMuted: Color(0xFF94A3B8),
    green: Color(0xFF10B981),
    red: Color(0xFFE63946),
    yellow: Color(0xFFF59E0B),
    purple: Color(0xFF8B5CF6),
    bord: Color(0x10FFFFFF),
    cardBg: Color(0xFF1E202B),
    glass: Color(0x30FFFFFF),
    glassBorder: Color(0x20FFFFFF),
    blue: Color(0xFF3B82F6),
    shimmer: Colors.white24,
  );

  // Light Theme Colors
  static const AppColors lightColors = AppColors(
    primary: Color(0xFF2563EB), // slightly darker blue for contrast on light
    primaryDark: Color(0xFF1E40AF),
    secondary: Color(0xFFE63946),
    bgBase: Color(0xFFF1F5F9), // Slate 100
    bgSurface: Color(0xFFFFFFFF), // White
    bgCard: Color(0xFFFFFFFF), // White
    bgElevated: Color(0xFFE2E8F0), // Slate 200
    txtPrimary: Color(0xFF0F172A), // Slate 900
    txtSec: Color(0xFF475569), // Slate 600
    txtMuted: Color(0xFF64748B), // Slate 500
    green: Color(0xFF059669),
    red: Color(0xFFDC2626),
    yellow: Color(0xFFD97706),
    purple: Color(0xFF7C3AED),
    bord: Color(0x1A000000), // Light border
    cardBg: Color(0xFFFFFFFF),
    glass: Color(0x90FFFFFF),
    glassBorder: Color(0x20000000),
    blue: Color(0xFF3B82F6),
    shimmer: Colors.black12,
  );

  static ThemeData get dark {
    final b = ThemeData.dark(useMaterial3: true);
    return b.copyWith(
      scaffoldBackgroundColor: darkColors.bgBase,
      extensions: [darkColors],
      colorScheme: ColorScheme.dark(
        primary: darkColors.primary, 
        surface: darkColors.bgCard, 
        onPrimary: Colors.white, 
        onSurface: darkColors.txtPrimary,
        secondary: darkColors.secondary,
      ),
      cardColor: darkColors.bgCard,
      dividerColor: darkColors.bord,
      textTheme: GoogleFonts.interTextTheme(b.textTheme).apply(bodyColor: darkColors.txtPrimary, displayColor: darkColors.txtPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.bgSurface, 
        elevation: 0, 
        foregroundColor: darkColors.txtPrimary,
        titleTextStyle: GoogleFonts.plusJakartaSans(color: darkColors.txtPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: darkColors.bgSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColors.primary, 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        )
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkColors.primary,
          side: BorderSide(color: darkColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, 
        fillColor: darkColors.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkColors.primary, width: 1.5)),
        labelStyle: TextStyle(color: darkColors.txtSec), 
        hintStyle: TextStyle(color: darkColors.txtMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: darkColors.bgCard, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: darkColors.bord))
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkColors.bgSurface, 
        indicatorColor: darkColors.primary.withValues(alpha: 0.15),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: darkColors.txtSec,
        textColor: Colors.white,
        selectedColor: darkColors.secondary,
        selectedTileColor: const Color(0x1F2563EB),
      ),
    );
  }

  static ThemeData get light {
    final b = ThemeData.light(useMaterial3: true);
    return b.copyWith(
      scaffoldBackgroundColor: lightColors.bgBase,
      extensions: [lightColors],
      colorScheme: ColorScheme.light(
        primary: lightColors.primary, 
        surface: lightColors.bgCard, 
        onPrimary: Colors.white, 
        onSurface: lightColors.txtPrimary,
        secondary: lightColors.secondary,
      ),
      cardColor: lightColors.bgCard,
      dividerColor: lightColors.bord,
      textTheme: GoogleFonts.interTextTheme(b.textTheme).apply(bodyColor: lightColors.txtPrimary, displayColor: lightColors.txtPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: lightColors.bgSurface, 
        elevation: 0, 
        foregroundColor: lightColors.txtPrimary,
        iconTheme: IconThemeData(color: lightColors.txtPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(color: lightColors.txtPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: lightColors.bgSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColors.primary, 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        )
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightColors.primary,
          side: BorderSide(color: lightColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, 
        fillColor: lightColors.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightColors.primary, width: 1.5)),
        labelStyle: TextStyle(color: lightColors.txtSec), 
        hintStyle: TextStyle(color: lightColors.txtMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: lightColors.bgCard, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: lightColors.bord))
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightColors.bgSurface, 
        indicatorColor: lightColors.primary.withValues(alpha: 0.15),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: lightColors.txtSec,
        textColor: lightColors.txtPrimary,
        selectedColor: lightColors.secondary,
        selectedTileColor: const Color(0x1F2563EB),
      ),
    );
  }
}
