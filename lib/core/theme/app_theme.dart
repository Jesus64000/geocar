import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 1. Definición central de colores corporativos
  static const Color primaryColor = Color(0xFF1E3A8A); // Azul Geocar
  static const Color accentColor = Color(0xFF3B82F6); // Azul más vibrante para destellos

  // 2. Tema Claro (Light Mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        surface: const Color(0xFFF8FAFC), // Fondo gris muy claro casi blanco
        onSurface: const Color(0xFF0F172A), // Texto oscuro
        surfaceContainerHighest: const Color(0xFFF1F5F9), // Fondo de los TextFields
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );
  }

  // 3. Tema Oscuro (Dark Mode) - Estilo Premium "Midnight"
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF60A5FA), // Azul primario más claro para resaltar en fondo oscuro
        secondary: accentColor,
        surface: const Color(0xFF0F172A), // Azul marino súper oscuro (Casi negro)
        onSurface: const Color(0xFFF8FAFC), // Texto blanco hueso
        surfaceContainerHighest: const Color(0xFF1E293B), // Fondo de los TextFields en oscuro
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );
  }
}