/// Pure timing logic for the candle countdown.
///
/// Candle boundaries are aligned to the UTC epoch, which is how exchanges
/// align their candles. Every supported timeframe divides 60 minutes, so the
/// boundaries also line up with the local wall clock in every timezone whose
/// UTC offset is a whole or half hour.
library;

/// Timeframes the user can pick, in minutes.
const List<int> kTimeframes = [30, 15, 10, 5, 3, 2, 1];

class CandleState {
  const CandleState({
    required this.timeframeMinutes,
    required this.now,
    required this.candleOpen,
    required this.candleClose,
  });

  final int timeframeMinutes;
  final DateTime now;

  /// Local time at which the current candle opened.
  final DateTime candleOpen;

  /// Local time at which the current candle closes (the next milestone).
  final DateTime candleClose;

  Duration get period => Duration(minutes: timeframeMinutes);

  /// Time left until the candle closes. Never negative.
  Duration get remaining {
    final d = candleClose.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// Fraction of the candle already elapsed, 0.0 .. 1.0.
  double get progress {
    final elapsed = now.difference(candleOpen).inMilliseconds;
    return (elapsed / period.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Whole seconds left, rounded up so the display reads 1 until the
  /// boundary actually passes and then flips straight to the new candle.
  int get remainingSeconds {
    final ms = remaining.inMilliseconds;
    return (ms + 999) ~/ 1000;
  }
}

/// Computes the candle that contains [now] for the given timeframe.
CandleState candleStateAt(DateTime now, int timeframeMinutes) {
  assert(timeframeMinutes > 0);
  final periodMs = timeframeMinutes * 60 * 1000;
  final epochMs = now.toUtc().millisecondsSinceEpoch;
  final openMs = epochMs - (epochMs % periodMs);
  final closeMs = openMs + periodMs;
  return CandleState(
    timeframeMinutes: timeframeMinutes,
    now: now,
    candleOpen: DateTime.fromMillisecondsSinceEpoch(
      openMs,
      isUtc: true,
    ).toLocal(),
    candleClose: DateTime.fromMillisecondsSinceEpoch(
      closeMs,
      isUtc: true,
    ).toLocal(),
  );
}

/// Formats a number of seconds as `mm:ss`.
String formatCountdown(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = s ~/ 60;
  final sec = s % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// Formats a time of day as `HH:mm:ss` (24-hour).
String formatClock(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
