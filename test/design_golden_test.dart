// Screenshots of the established design; any visual change fails these.
// After an intended design change: flutter test --update-goldens --tags golden
// Rendering differs slightly between OSes, so CI skips them (see dart_test.yaml).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/utils/touch_number.dart';
import 'package:gdf_hema_timer/widgets/fight_in_progress.dart';

import 'support/app_harness.dart';

/// Icons come from the Flutter SDK; flutter_tester lives in
/// `<sdk>/bin/cache/artifacts/engine/<platform>/`.
Future<void> _loadIconFont() async {
  final cache = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final file = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
}

Future<void> _matches(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await _loadIconFont();
  });

  testWidgets('main screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(TouchNumber).first);
    await tester.pump();
    await _matches('main');
  });

  testWidgets('main screen, dark, Ukrainian', (tester) async {
    await pumpApp(tester, prefs: {'dark_theme': true, 'locale': 'uk'});
    await _matches('main_dark_uk');
  });

  testWidgets('running timer', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('START'));
    await tester.pump();
    await _matches('running');
    await tester.tap(find.byType(ActiveTimerBoard));
    await tester.pump();
  });

  testWidgets('fight log', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(TouchNumber).first);
    await tester.pump();
    await tester.drag(find.text('Drag up for logs'), const Offset(0, -200));
    await tester.pumpAndSettle();
    await _matches('fight_log');
  });

  testWidgets('settings drawer', (tester) async {
    await pumpApp(tester);
    tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await _matches('drawer');
  });

  testWidgets('tutorial', (tester) async {
    await pumpApp(tester, prefs: {'show_help_on_launch': true});
    await _matches('tutorial');
  });
}
