import 'package:flutter/material.dart';

import 'fontStyle.dart';

class CustomColorTheme {
  static const Color warningColor = Colors.red;
  static const Color primaryColor = Color(0xFF12233D); // Dark Blue
  static const Color accentColor = Color(0xFF4CA1AF); // Light Blue
  static const Color backgroundColor = Color(0xFF1B2A49); // Dark Background
  static const Color cardColor = Color(0xFF2E3B55); // Card Background
  static const Color textColor = Colors.white;
  static const Color textSecondaryColor = Colors.white70;
  static const Color iconColor = Colors.white;
  static const Color CustomPrimaryAppColor = Color(0xffEC1D28);

  static final ThemeData themeData = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    hintColor: accentColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      iconTheme: IconThemeData(color: iconColor),
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.mainFont,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: accentColor,
      ),
    ),
    iconTheme: const IconThemeData(color: iconColor),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textColor, fontFamily: AppFonts.mainFont),
      bodyMedium:
          TextStyle(color: textSecondaryColor, fontFamily: AppFonts.mainFont),
      titleLarge: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      titleMedium:
          TextStyle(color: textSecondaryColor, fontFamily: AppFonts.mainFont),
      titleSmall:
          TextStyle(color: textSecondaryColor, fontFamily: AppFonts.mainFont),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle:
          TextStyle(color: textSecondaryColor, fontFamily: AppFonts.mainFont),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: textSecondaryColor),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: textColor),
      ),
    ),
    colorScheme: const ColorScheme.dark()
        .copyWith(
          primary: primaryColor,
          secondary: accentColor,
          surface: backgroundColor,
        )
        .copyWith(surface: backgroundColor),
  );
}
