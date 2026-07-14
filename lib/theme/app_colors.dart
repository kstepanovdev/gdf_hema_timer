import 'package:flutter/material.dart';

/// Semantic color palette for the app.
///
/// Widgets reference these names (e.g. [AppColors.danger]) instead of
/// hard-coding raw Material colors, so the palette can be tuned in one place.
class AppColors {
  AppColors._();

  /// Primary action accent (e.g. the START button, help icons).
  static const MaterialColor primary = Colors.deepPurple;

  /// Destructive / stop actions (Reset, Stop).
  static const Color danger = Colors.red;

  /// Secondary controls (the time +/- buttons).
  static const Color neutral = Colors.blueGrey;

  /// Muted hint text and affordances (the log handle).
  static const Color hint = Colors.grey;

  /// Full-screen "stage" background used by the running timer view.
  static const Color stage = Colors.black;

  /// Foreground on top of [stage].
  static const Color onStage = Colors.white;
}
