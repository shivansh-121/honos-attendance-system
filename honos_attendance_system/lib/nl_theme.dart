import 'package:flutter/material.dart';

class NLTheme {
  static const Color background = Color(0xFFEFECE5); // Light beige background
  static const Color surface = Color(0xFFF7F6F2); // Slightly lighter for cards
  static const Color sidebar = Color(0xFF161616); // Dark sidebar
  static const Color primaryText = Color(0xFF1E1E1E);
  static const Color secondaryText = Color(0xFF6B6B6B);
  
  static const Color accentGreen = Color(0xFFB5D466); // For active items, progress bars
  static const Color accentCyan = Color(0xFF6AC9C9);
  static const Color accentPink = Color(0xFFD3A4BE);

  static const Color cardShadow = Color(0x1A000000); // Soft shadow
  
  static const TextStyle headerStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primaryText,
    letterSpacing: -0.5,
  );
  
  static const TextStyle subheaderStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryText,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    color: secondaryText,
  );
}
