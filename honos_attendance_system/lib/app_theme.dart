import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary      = Color(0xFF3B82F6); // Bright Blue for high contrast in dark mode
  static const primaryDark  = Color(0xFF1D4ED8);
  static const secondary    = Color(0xFFE63946); 
  static const bgBase       = Color(0xFF0F172A);
  static const bgSurface    = Color(0xFF1E293B);
  static const bgCard       = Color(0xFF1E293B);
  static const bgElevated   = Color(0xFF334155);
  static const txtPrimary   = Color(0xFFFFFFFF); // High-contrast White
  static const txtSec       = Color(0xFFCAD4E0); // Light Grey
  static const txtMuted     = Color(0xFF94A3B8);
  static const green        = Color(0xFF10B981);
  static const red          = Color(0xFFE63946);
  static const yellow       = Color(0xFFF59E0B);
  static const purple     = Color(0xFF8B5CF6);
  static const bord       = Color(0x10FFFFFF);
  static const cardBg     = Color(0xFF1E202B);
  static const glass      = Color(0x30FFFFFF);
  static const glassBorder = Color(0x20FFFFFF);

  static BoxDecoration get glassDecoration => BoxDecoration(
    color: glass,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glassBorder),
  );

  static ThemeData get dark {
    final b = ThemeData.dark(useMaterial3: true);
    return b.copyWith(
      scaffoldBackgroundColor: bgBase,
      colorScheme: const ColorScheme.dark(
        primary: primary, 
        surface: bgCard, 
        onPrimary: Colors.white, 
        onSurface: txtPrimary,
        secondary: secondary,
      ),
      cardColor: bgCard,
      dividerColor: bord,
      textTheme: GoogleFonts.interTextTheme(b.textTheme).apply(bodyColor: txtPrimary, displayColor: txtPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: bgSurface, 
        elevation: 0, 
        foregroundColor: txtPrimary,
        titleTextStyle: GoogleFonts.plusJakartaSans(color: txtPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: bgSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        )
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50),
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, 
        fillColor: bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        labelStyle: const TextStyle(color: txtSec), 
        hintStyle: const TextStyle(color: txtMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: bgCard, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: bord))
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgSurface, 
        indicatorColor: primary.withValues(alpha: 0.15),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFCAD4E0),
        textColor: Colors.white,
        selectedColor: Color(0xFFE63946),
        selectedTileColor: Color(0x1F2563EB),
      ),
    );
  }
}
