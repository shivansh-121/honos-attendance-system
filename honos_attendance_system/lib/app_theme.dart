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

  // Dark Theme Colors — true charcoal/black, no blue tint
  static const AppColors darkColors = AppColors(
    primary: Color(0xFF4ADE80),       // Vibrant green accent
    primaryDark: Color(0xFF22C55E),
    secondary: Color(0xFFE63946),
    bgBase: Color(0xFF111111),        // Near-black background
    bgSurface: Color(0xFF1C1C1C),     // Dark card surface
    bgCard: Color(0xFF1C1C1C),
    bgElevated: Color(0xFF2A2A2A),    // Sidebar / elevated elements
    txtPrimary: Color(0xFFFFFFFF),    // Pure white text
    txtSec: Color(0xFFAAAAAA),        // Light grey secondary text
    txtMuted: Color(0xFF666666),
    green: Color(0xFF4ADE80),
    red: Color(0xFFFF5C5C),
    yellow: Color(0xFFFBBF24),
    purple: Color(0xFFA78BFA),
    bord: Color(0x20FFFFFF),
    cardBg: Color(0xFF1C1C1C),
    glass: Color(0x20FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    blue: Color(0xFF60A5FA),
    shimmer: Colors.white24,
  );

  // Light Theme Colors — clean white with sharp dark text
  static const AppColors lightColors = AppColors(
    primary: Color(0xFF1A1A1A),       // Near-black sidebar/accent
    primaryDark: Color(0xFF000000),
    secondary: Color(0xFF5CB85C),     // Green accent
    bgBase: Color(0xFFF4F4F4),        // Light grey background
    bgSurface: Color(0xFFFFFFFF),     // White card surface
    bgCard: Color(0xFFFFFFFF),
    bgElevated: Color(0xFF1A1A1A),    // Dark sidebar (stays dark)
    txtPrimary: Color(0xFF111111),    // Near-black text — highly readable
    txtSec: Color(0xFF555555),        // Dark grey secondary text
    txtMuted: Color(0xFF999999),
    green: Color(0xFF2E7D32),         // Dark green for light mode
    red: Color(0xFFD32F2F),           // Dark red for light mode
    yellow: Color(0xFFF59E0B),
    purple: Color(0xFF7C3AED),
    bord: Color(0x18000000),
    cardBg: Color(0xFFFFFFFF),
    glass: Color(0x90FFFFFF),
    glassBorder: Color(0x25000000),
    blue: Color(0xFF2563EB),
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
        onPrimary: Colors.black, 
        onSurface: darkColors.txtPrimary,
        secondary: darkColors.secondary,
      ),
      cardColor: darkColors.bgCard,
      dividerColor: darkColors.bord,
      textTheme: GoogleFonts.interTextTheme(b.textTheme).apply(bodyColor: darkColors.txtPrimary, displayColor: darkColors.txtPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.bgBase, 
        elevation: 0, 
        foregroundColor: darkColors.txtPrimary,
        iconTheme: IconThemeData(color: darkColors.txtPrimary),
        titleTextStyle: GoogleFonts.inter(color: darkColors.txtPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: darkColors.bgElevated),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColors.primary, 
          foregroundColor: Colors.black,
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
        textColor: darkColors.txtPrimary,
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
        backgroundColor: lightColors.bgBase, 
        elevation: 0, 
        foregroundColor: lightColors.txtPrimary,
        iconTheme: IconThemeData(color: lightColors.txtPrimary),
        titleTextStyle: GoogleFonts.inter(color: lightColors.txtPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: lightColors.bgElevated),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: lightColors.bgBase, backgroundColor: lightColors.primary, 
          
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        )
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightColors.primary,
          side: BorderSide(color: lightColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          minimumSize: const Size(double.infinity, 50),
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, 
        fillColor: lightColors.bgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: lightColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: lightColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: lightColors.secondary, width: 1.5)),
        labelStyle: TextStyle(color: lightColors.txtSec), 
        hintStyle: TextStyle(color: lightColors.txtMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: lightColors.bgCard, 
        elevation: 0, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide.none)
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightColors.bgSurface, 
        indicatorColor: lightColors.secondary.withValues(alpha: 0.2),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: lightColors.txtSec,
        textColor: lightColors.txtPrimary,
        selectedColor: lightColors.secondary,
        selectedTileColor: lightColors.secondary.withValues(alpha: 0.1),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GLOBAL RESPONSIVE HELPERS
// ─────────────────────────────────────────────

/// Wraps [child] in a centered ConstrainedBox so content never
/// stretches beyond [maxWidth] pixels on wide/desktop screens.
Widget responsiveBody(Widget child, {double maxWidth = 900}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Returns horizontal padding that grows as the screen gets wider,
/// keeping content comfortably centred on laptops / desktops.
EdgeInsets responsivePadding(BuildContext context, {
  double base = 20,
  double maxWidth = 900,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth <= maxWidth) return EdgeInsets.symmetric(horizontal: base);
  final extra = (screenWidth - maxWidth) / 2;
  return EdgeInsets.symmetric(horizontal: extra + base);
}

/// A SliverPadding whose horizontal insets auto-centre content.
class ResponsiveSliverPadding extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final EdgeInsets extraPadding;

  const ResponsiveSliverPadding({
    super.key,
    required this.sliver,
    this.maxWidth = 900,
    this.extraPadding = const EdgeInsets.only(bottom: 100),
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth > maxWidth ? (screenWidth - maxWidth) / 2 + 20 : 20.0;
    return SliverPadding(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: extraPadding.top,
        bottom: extraPadding.bottom,
      ),
      sliver: sliver,
    );
  }
}
