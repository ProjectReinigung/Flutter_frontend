import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => _theme(
    brightness: Brightness.light,
    seed: const Color(0xFF0E7490),
    surface: const Color(0xFFF7FAFA),
    extension: AppColors.light,
  );

  static ThemeData get dark => _theme(
    brightness: Brightness.dark,
    seed: const Color(0xFF2DD4BF),
    surface: const Color(0xFF0F172A),
    extension: AppColors.dark,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required AppColors extension,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final textTheme =
        GoogleFonts.interTextTheme(
          brightness == Brightness.dark
              ? ThemeData.dark().textTheme
              : ThemeData.light().textTheme,
        ).copyWith(
          headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w800),
          headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w700),
          titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(surface: surface),
      textTheme: textTheme,
      extensions: [extension],
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
