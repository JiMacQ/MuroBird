import 'package:flutter/material.dart';

// Paleta
const kBrand = Color(0xFF10A37F);
const kBrandDark = Color(0xFF0C7D60);
const kBg = Color(0xFFF4FAF8); // fondo muy claro (mint)
const kNavBg = Color(0xFFEAF6F2); // barra inferior estilo maqueta
const kText = Color(0xFF2F3B3A);
const kDivider = Color(0xFFDAE7E3);

ThemeData buildBirbyTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    primary: kBrand,
    onPrimary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: kText),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: kText),
      bodyMedium: TextStyle(color: kText, height: 1.36),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
