import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_event.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_event_formatter.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_log.dart';
import 'package:gdf_hema_timer/utils/time_utils.dart';

void main() {
  const clock = Duration(minutes: 1, seconds: 15, milliseconds: 429);

  test('formatTime shows mm:ss.cc', () {
    expect(formatTime(clock), '01:15.42');
    expect(formatTime(Duration.zero), '00:00.00');
  });

  test(
    'FightLog drops penalty/double corrections but keeps score decrements',
    () {
      final log = FightLog()
        ..emit(const ScoreChanged(clock, leftTotal: 0, rightTotal: 0))
        ..emit(const DoubleHitChanged(clock, delta: -1, total: 0))
        ..emit(
          const PenaltyChanged(
            clock,
            fighter: 'F1',
            kind: PenaltyKind.warning,
            delta: -1,
            total: 0,
          ),
        )
        ..emit(const DoubleHitChanged(clock, delta: 1, total: 1));
      expect(log.events.map((e) => e.runtimeType), [
        ScoreChanged,
        DoubleHitChanged,
      ]);
    },
  );

  test('FightLog marks the start once per bout', () {
    final log = FightLog()
      ..markStarted(clock)
      ..markStarted(Duration.zero);
    expect(log.events, hasLength(1));
    log
      ..reset()
      ..markStarted(clock);
    expect(log.events.single, isA<FightStarted>());
  });

  test('formatFightEvent renders localized lines', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      formatFightEvent(
        const ScoreChanged(clock, leftTotal: 2, rightTotal: 0),
        l10n,
      ),
      '01:15.42 - 2 : 0',
    );
    expect(
      formatFightEvent(
        const PenaltyChanged(
          clock,
          fighter: 'F2',
          kind: PenaltyKind.caution,
          delta: 1,
          total: 1,
        ),
        l10n,
      ),
      '01:15.42 - Caution to F2',
    );
  });
}
