import 'package:count_down_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  testWidgets('full dock renders at 300x168 without overflow and switches '
      'timeframe', (tester) async {
    tester.view.physicalSize = kFullSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await prefsWith({'timeframe': 5});
    await tester.pumpWidget(
      CandleDockApp(prefs: prefs, initial: DockSettings.load(prefs)),
    );
    await tester.pump();

    expect(find.text('5 min'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
    for (final tf in [30, 15, 10, 5, 3, 2, 1]) {
      expect(find.text('${tf}m'), findsOneWidget);
    }

    await tester.tap(find.text('30m'));
    await tester.pump();
    expect(find.text('30 min'), findsOneWidget);
    expect(prefs.getInt('timeframe'), 30);

    // Let the ticker fire a few times, then tear it down.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mini dock renders at 170x56 without overflow', (tester) async {
    tester.view.physicalSize = kMiniSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await prefsWith({'timeframe': 1, 'mini': true});
    await tester.pumpWidget(
      CandleDockApp(prefs: prefs, initial: DockSettings.load(prefs)),
    );
    await tester.pump();

    expect(find.text('1m'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('DockSettings falls back to defaults on bad values', () async {
    final prefs = await prefsWith({'timeframe': 7, 'corner': 'nope'});
    final s = DockSettings.load(prefs);
    expect(s.timeframe, 5);
    expect(s.corner, DockCorner.topRight);
    expect(s.mini, false);
  });
}
