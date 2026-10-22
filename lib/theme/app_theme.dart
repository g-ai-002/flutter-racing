import 'package:flutter/material.dart';

const _primary = Color(0xFF1E88E5);

const _lightSurface = Color(0xFFFFFFFF);
const _lightBackground = Color(0xFFF5F5F5);
const _lightSurfaceVariant = Color(0xFFE8E8E8);
const _lightOnSurface = Color(0xFF212121);
const _lightOnSurfaceVariant = Color(0xFF757575);
const _lightOutline = Color(0xFFE0E0E0);

const _darkSurface = Color(0xFF1E1E1E);
const _darkBackground = Color(0xFF121212);
const _darkSurfaceVariant = Color(0xFF2C2C2C);
const _darkOnSurface = Color(0xFFE0E0E0);
const _darkOnSurfaceVariant = Color(0xFF9E9E9E);
const _darkOutline = Color(0xFF333333);

ThemeData buildLightTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.light(
    primary: _primary,
    primaryContainer: Color(0xFFBBDEFB),
    onPrimaryContainer: Color(0xFF0D47A1),
    secondary: Color(0xFFFFC107),
    onSecondary: Color(0xFF212121),
    onSurface: _lightOnSurface,
    surfaceContainerHighest: _lightSurfaceVariant,
    onSurfaceVariant: _lightOnSurfaceVariant,
    error: Color(0xFFE53935),
    outline: _lightOutline,
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: _lightBackground,
    surface: _lightSurface,
    surfaceVariant: _lightSurfaceVariant,
    outline: _lightOutline,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceVariant,
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.dark(
    primary: Color(0xFF64B5F6),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1565C0),
    onPrimaryContainer: Color(0xFFBBDEFB),
    secondary: Color(0xFFFFCA28),
    onSecondary: Color(0xFF212121),
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    surfaceContainerHighest: _darkSurfaceVariant,
    onSurfaceVariant: _darkOnSurfaceVariant,
    error: Color(0xFFEF5350),
    onError: Color(0xFF212121),
    outline: _darkOutline,
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: _darkBackground,
    surface: _darkSurface,
    surfaceVariant: _darkSurfaceVariant,
    outline: _darkOutline,
    onSurface: _darkOnSurface,
    onSurfaceVariant: _darkOnSurfaceVariant,
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  required Color surface,
  required Color surfaceVariant,
  required Color outline,
  required Color onSurface,
  required Color onSurfaceVariant,
  String? fontFamily,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 48,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
        fontFamily: fontFamily,
      ),
      shape: Border(bottom: BorderSide(color: outline, width: 0.5)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, fontFamily: fontFamily),
      bodyLarge: TextStyle(fontSize: 15, color: onSurface, fontFamily: fontFamily),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface, fontFamily: fontFamily),
      bodySmall: TextStyle(fontSize: 12, color: onSurfaceVariant, fontFamily: fontFamily),
    ),
  );
}
