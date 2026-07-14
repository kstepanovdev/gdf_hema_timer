import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Light and dark [ThemeData] for the app, kept out of `main.dart` so theming
/// lives in one place.
class AppTheme {
  AppTheme._();

  static const TextTheme _baseText = TextTheme(
    bodyMedium: TextStyle(fontFamily: 'Roboto'),
  );

  static ThemeData get light => ThemeData(
    primarySwatch: AppColors.primary,
    textTheme: _baseText,
  );

  static ThemeData get dark => ThemeData.dark().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    textTheme: ThemeData.dark().textTheme.merge(_baseText),
  );
}
