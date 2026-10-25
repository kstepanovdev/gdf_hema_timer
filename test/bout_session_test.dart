import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/bout_session/fight_clock.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_event.dart';

void main() {
  group('monotonic clock', () {
    test('delayed refreshes measure time instead of counting callbacks', () {
      var elapsed = Duration.zero;
      final session = BoutSessionController(elapsed: () => elapsed);
      addTearDown(session.dispose);
      session.start();
      elapsed = const Duration(milliseconds: 6543);
      session.refresh(); // a single callback after a long event-loop delay
      expect(session.remaining, const Duration(milliseconds: 83457));
      for (var i = 0; i < 100; i++) {
        session.refresh();
      }
      expect(session.remaining, const Duration(milliseconds: 83457));
      elapsed = const Duration(minutes: 2);
      expect(session.refresh(), isTrue);
      expect(session.remaining, Duration.zero);
      expect(session.refresh(), isFalse);
      expect(
        session.fightLog.events.whereType<SessionChanged>().where(
          (e) => e.action == SessionAction.elapsed,
        ),
        hasLength(1),
      );
    });

    test('pause/resume excludes paused time', () {
      var elapsed = Duration.zero;
      final session = BoutSessionController(elapsed: () => elapsed);
      addTearDown(session.dispose);
      session.start();
      elapsed = const Duration(seconds: 12);
      session.pause();
      elapsed = const Duration(hours: 1);
      expect(session.remaining, const Duration(seconds: 78));
      session.start();
      elapsed += const Duration(seconds: 3);
      expect(session.remaining, const Duration(seconds: 75));
      expect(session.fightLog.events.whereType<FightStarted>(), hasLength(1));
      expect(
        session.fightLog.events.whereType<SessionChanged>().map(
          (e) => e.action,
        ),
        [SessionAction.paused, SessionAction.resumed],
      );
    });

    test(
      'background/sleep interruption stays paused until explicit resume',
      () {
        var elapsed = Duration.zero;
        final session = BoutSessionController(elapsed: () => elapsed);
        addTearDown(session.dispose);
        session.start();
        elapsed = const Duration(seconds: 8);
        session.interrupt();
        session.interrupt();
        elapsed = const Duration(days: 1);
        session.refresh();
        expect(session.interrupted, isTrue);
        expect(session.running, isFalse);
        expect(session.remaining, const Duration(seconds: 82));
        expect(
          session.fightLog.events.whereType<SessionChanged>(),
          hasLength(1),
        );
        session.adjustTime(const Duration(seconds: -1));
        expect(session.interrupted, isTrue);
        session.start();
        expect(session.interrupted, isFalse);
        elapsed += const Duration(seconds: 2);
        expect(session.remaining, const Duration(seconds: 79));
      },
    );

    test('clamps at zero and can restart after a time adjustment', () {
      var elapsed = Duration.zero;
      final clock = FightClock(
        const Duration(seconds: 1),
        elapsed: () => elapsed,
      );
      clock.start();
      clock.start();
      elapsed = const Duration(seconds: 3);
      expect(clock.remaining, Duration.zero);
      expect(clock.running, isFalse);
      clock.setRemaining(const Duration(seconds: 5));
      clock.start();
      elapsed += const Duration(seconds: 1);
      expect(clock.remaining, const Duration(seconds: 4));
      clock.pause();
      clock.setRemaining(const Duration(seconds: -1));
      clock.start();
      expect(clock.running, isFalse);
    });
  });

  test(
    'swapping screen sides never swaps logical IDs, scores or sanctions',
    () {
      final session = BoutSessionController();
      addTearDown(session.dispose);
      final a = session.session.a.id;
      final b = session.session.b.id;
      session.setScore(DisplaySide.left, 5);
      session.setScore(DisplaySide.right, 2);
      session.setPenalty(DisplaySide.left, PenaltyKind.warning, 1);
      session.setPenalty(DisplaySide.right, PenaltyKind.caution, 2);
      session.swapSides();
      expect(session.at(DisplaySide.left).id, b);
      expect(session.at(DisplaySide.left).score, 2);
      expect(session.at(DisplaySide.left).caution, 2);
      expect(session.at(DisplaySide.right).id, a);
      expect(session.at(DisplaySide.right).warning, 1);
      session.setScore(DisplaySide.left, 3);
      expect(session.session.a.score, 5);
      expect(session.session.b.score, 3);
      final event = session.fightLog.events.last as ScoreChanged;
      expect(event.fighterId, b);
      expect(event.scoreA, 5);
      expect(event.scoreB, 3);
      expect(event.leftTotal, 3);
      expect(event.rightTotal, 5);
      session.swapSides();
      expect(session.at(DisplaySide.left).id, a);
      expect(session.at(DisplaySide.right).score, 3);
    },
  );

  test(
    'corrections remain attributable and visible, with no negative counters',
    () {
      final session = BoutSessionController();
      addTearDown(session.dispose);
      session.setScore(DisplaySide.left, 2);
      session.setScore(DisplaySide.left, 1);
      session.setPenalty(DisplaySide.right, PenaltyKind.warning, 2);
      session.setPenalty(DisplaySide.right, PenaltyKind.warning, 1);
      session.setPenalty(DisplaySide.left, PenaltyKind.caution, 1);
      session.setMutualHits(2);
      session.setMutualHits(1);
      expect(session.fightLog.events.whereType<ScoreChanged>().last.delta, -1);
      final penalty = session.fightLog.events
          .whereType<PenaltyChanged>()
          .elementAt(1);
      expect(penalty.delta, -1);
      expect(penalty.fighterId, session.session.b.id);
      expect(
        session.fightLog.events.whereType<DoubleHitChanged>().last.delta,
        -1,
      );
      final count = session.fightLog.events.length;
      session.setScore(DisplaySide.left, -1);
      session.setPenalty(DisplaySide.left, PenaltyKind.caution, -1);
      session.setMutualHits(-1);
      session.setMutualHits(1);
      expect(session.fightLog.events, hasLength(count));
      expect(() => session.fightLog.events.clear(), throwsUnsupportedError);
    },
  );

  test('full reset clears bout state, mapping, history and running clock', () {
    var elapsed = Duration.zero;
    final session = BoutSessionController(elapsed: () => elapsed);
    addTearDown(session.dispose);
    final previousId = session.session.id;
    session.setScore(DisplaySide.left, 9);
    session.setPenalty(DisplaySide.right, PenaltyKind.caution, 4);
    session.setMutualHits(6);
    session.swapSides();
    session.start();
    elapsed = const Duration(seconds: 20);
    session.reset(duration: const Duration(minutes: 2));
    expect(session.session.id, isNot(previousId));
    expect(session.session.leftIsA, isTrue);
    expect(session.session.a.score, 0);
    expect(session.session.b.caution, 0);
    expect(session.session.mutualHits, 0);
    expect(session.running, isFalse);
    expect(session.remaining, const Duration(minutes: 2));
    expect(session.fightLog.events, hasLength(1));
    expect(
      (session.fightLog.events.single as SessionChanged).action,
      SessionAction.reset,
    );
    session.start();
    expect(session.fightLog.events.whereType<FightStarted>(), hasLength(1));
  });

  test(
    'score-only reset keeps time and fresh controllers have no shared state',
    () {
      final session = BoutSessionController();
      final other = BoutSessionController();
      addTearDown(session.dispose);
      addTearDown(other.dispose);
      session.setScore(DisplaySide.left, 8);
      session.setMutualHits(3);
      session.adjustTime(const Duration(seconds: 5));
      session.reset(duration: Duration.zero, keepTime: true);
      expect(session.remaining, const Duration(seconds: 95));
      expect(session.session.a.score, 0);
      expect(session.session.mutualHits, 0);
      expect(other.remaining, const Duration(seconds: 90));
      expect(other.fightLog.isEmpty, isTrue);
      expect(other.session.a.score, 0);
    },
  );
  test(
    'score-only reset pauses an active clock without carrying a running bout',
    () {
      var elapsed = Duration.zero;
      final session = BoutSessionController(elapsed: () => elapsed);
      addTearDown(session.dispose);
      session.start();
      elapsed = const Duration(seconds: 10);
      session.reset(duration: Duration.zero, keepTime: true);
      expect(session.running, isFalse);
      expect(session.remaining, const Duration(seconds: 80));
      elapsed = const Duration(minutes: 2);
      expect(session.remaining, const Duration(seconds: 80));
      session.start();
      expect(session.fightLog.events.whereType<FightStarted>(), hasLength(1));
    },
  );
}
