import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0F1117);
  static const surface = Color(0xFF171A23);
  static const surface2 = Color(0xFF1E2230);
  static const border = Color(0xFF2A2F3F);

  static const text1 = Color(0xFFE7EAF2);
  static const text2 = Color(0xFFA7AFC3);

  static const accent = Color(0xFF7C6E7F);

  static ThemeData theme() {
    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(
        primary: accent,
        surface: surface,
        secondary: surface2,
        outline: border,
      ),
      scaffoldBackgroundColor: bg,

      // ✅ Esto controla el cursor y el color al seleccionar texto
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: text1,
        selectionColor: Color(0x557C6E7F),
        selectionHandleColor: accent,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),

        // ICONOS
        prefixIconColor: text2,
        suffixIconColor: text2,

        // LABEL/HINT
        hintStyle: const TextStyle(color: text2),
        labelStyle: const TextStyle(color: text2),
        floatingLabelStyle: const TextStyle(color: text1),

        // BORDES
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: text1,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text1,
        ),
        bodyLarge: TextStyle(fontSize: 14, color: text1),
        bodyMedium: TextStyle(fontSize: 13, color: text2),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: text1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
