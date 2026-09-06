import 'package:count_down_timer/candle_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('candleStateAt', () {
    test('aligns 5m candles to the hour', () {
      final now = DateTime.utc(2026, 9, 7, 10, 7, 30);
      final s = candleStateAt(now, 5);
      expect(s.candleOpen.toUtc(), DateTime.utc(2026, 9, 7, 10, 5));
      expect(s.candleClose.toUtc(), DateTime.utc(2026, 9, 7, 10, 10));
      expect(s.remaining, const Duration(minutes: 2, seconds: 30));
      expect(s.progress, closeTo(0.5, 1e-9));
    });

    test('every supported timeframe lands on the hour boundary', () {
      final now = DateTime.utc(2026, 9, 7, 10, 59, 59, 500);
      for (final tf in kTimeframes) {
        final s = candleStateAt(now, tf);
        expect(
          s.candleClose.toUtc(),
          DateTime.utc(2026, 9, 7, 11),
          reason: '$tf minute candle should close at 11:00',
        );
        expect(s.remainingSeconds, 1, reason: '$tf minute rounding');
      }
    });

    test('exactly on the boundary starts a fresh candle', () {
      final now = DateTime.utc(2026, 9, 7, 10, 30);
      final s = candleStateAt(now, 30);
      expect(s.candleOpen.toUtc(), now);
      expect(s.candleClose.toUtc(), DateTime.utc(2026, 9, 7, 11));
      expect(s.remainingSeconds, 30 * 60);
      expect(s.progress, 0.0);
    });

    test('3m and 2m candles align to their own grid', () {
      final now = DateTime.utc(2026, 9, 7, 10, 16, 10);
      expect(
        candleStateAt(now, 3).candleClose.toUtc(),
        DateTime.utc(2026, 9, 7, 10, 18),
      );
      expect(
        candleStateAt(now, 2).candleClose.toUtc(),
        DateTime.utc(2026, 9, 7, 10, 18),
      );
      expect(
        candleStateAt(now, 15).candleClose.toUtc(),
        DateTime.utc(2026, 9, 7, 10, 30),
      );
      expect(
        candleStateAt(now, 10).candleClose.toUtc(),
        DateTime.utc(2026, 9, 7, 10, 20),
      );
      expect(
        candleStateAt(now, 1).candleClose.toUtc(),
        DateTime.utc(2026, 9, 7, 10, 17),
      );
    });

    test('remainingSeconds rounds up partial seconds', () {
      final now = DateTime.utc(2026, 9, 7, 10, 4, 59, 1);
      expect(candleStateAt(now, 5).remainingSeconds, 1);
      final now2 = DateTime.utc(2026, 9, 7, 10, 4, 58, 999);
      expect(candleStateAt(now2, 5).remainingSeconds, 2);
    });
  });

  group('formatting', () {
    test('formatCountdown', () {
      expect(formatCountdown(0), '00:00');
      expect(formatCountdown(59), '00:59');
      expect(formatCountdown(60), '01:00');
      expect(formatCountdown(30 * 60), '30:00');
      expect(formatCountdown(-5), '00:00');
    });

    test('formatClock', () {
      expect(formatClock(DateTime(2026, 1, 1, 9, 5, 7)), '09:05:07');
    });
  });
}
