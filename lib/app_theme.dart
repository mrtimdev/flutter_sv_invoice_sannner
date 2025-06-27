import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme
  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1565C0),  // Blue 800
      secondary: Color(0xFF1E88E5), // Blue 600
      surface: Colors.white,
      background: Color(0xFFF5F5F5), // Grey 100
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      onBackground: Colors.black,
      error: Colors.red,
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 2,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),
    textTheme: _textTheme.apply(
      displayColor: Colors.black,
      bodyColor: Colors.black87,
    ),
  );

  // Dark Theme
  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64B5F6),  // Blue 300
      secondary: Color(0xFF90CAF9), // Blue 200
      surface: Color(0xFF121212),
      background: Color(0xFF424242), // Grey 800
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
      error: Colors.redAccent,
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 2,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),
    textTheme: _textTheme.apply(
      displayColor: Colors.white,
      bodyColor: Colors.white70,
    ),
  );

  // Shared Text Theme
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    bodySmall: TextStyle(fontSize: 12),
  );

  // Additional Theme Extensions (Optional)
  static ThemeExtension<CustomColors> lightCustomColors = CustomColors(
    success: Colors.green.shade800,
    warning: Colors.orange.shade800,
  );

  static ThemeExtension<CustomColors> darkCustomColors = CustomColors(
    success: Colors.green.shade300,
    warning: Colors.orange.shade300,
  );
}

// Custom Theme Extension for additional colors
class CustomColors extends ThemeExtension<CustomColors> {
  final Color? success;
  final Color? warning;

  const CustomColors({
    required this.success,
    required this.warning,
  });

  @override
  ThemeExtension<CustomColors> copyWith({
    Color? success,
    Color? warning,
  }) {
    return CustomColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  ThemeExtension<CustomColors> lerp(
    ThemeExtension<CustomColors>? other, 
    double t,
  ) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
    );
  }
}