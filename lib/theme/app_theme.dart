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

  /// Condensed typeface used for the Ukrainian UI, where long Cyrillic labels
  /// (e.g. "Попередження") don't fit comfortably in the default font.
  static const String ukFontFamily = 'PTSansNarrow';

  /// Returns [base] with every inherited text style switched to the condensed
  /// [ukFontFamily]. Widgets that hard-code a family (the monospace timer and
  /// score digits) are unaffected, so those stay jitter-free.
  static ThemeData withUkFont(ThemeData base) => base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: ukFontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: ukFontFamily),
  );
}
