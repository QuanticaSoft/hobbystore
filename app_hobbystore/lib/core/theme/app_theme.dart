import 'package:flutter/material.dart';

class AppTheme {
  // Rojo "hobby" de las referencias de tiendas de modelismo (Horizon Hobby).
  static const _seedColor = Color(0xFFA83232);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
