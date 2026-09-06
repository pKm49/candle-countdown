import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'candle_clock.dart';
import 'popout_stub.dart'
    if (dart.library.js_interop) 'popout_web.dart'
    as popout;

const Size kFullSize = Size(300, 168);
const Size kMiniSize = Size(170, 56);

/// Screen positions the dock can snap to.
enum DockCorner {
  topLeft('Top left', Alignment.topLeft),
  topRight('Top right', Alignment.topRight),
  bottomLeft('Bottom left', Alignment.bottomLeft),
  bottomRight('Bottom right', Alignment.bottomRight),
  free('Free (drag anywhere)', null);

  const DockCorner(this.label, this.alignment);
  final String label;
  final Alignment? alignment;
}

bool get _isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = DockSettings.load(prefs);

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    final size = settings.mini ? kMiniSize : kFullSize;
    final options = WindowOptions(
      size: size,
      minimumSize: size,
      maximumSize: size,
      center: settings.corner == DockCorner.free,
      alwaysOnTop: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Candle Countdown',
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      await _applyCorner(settings.corner);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(CandleDockApp(prefs: prefs, initial: settings));
}

Future<void> _applyCorner(DockCorner corner) async {
  final alignment = corner.alignment;
  if (alignment != null) {
    await windowManager.setAlignment(alignment);
  }
}

class DockSettings {
  DockSettings({
    required this.timeframe,
    required this.corner,
    required this.mini,
  });

  int timeframe;
  DockCorner corner;
  bool mini;

  static const _kTimeframe = 'timeframe';
  static const _kCorner = 'corner';
  static const _kMini = 'mini';

  static DockSettings load(SharedPreferences prefs) {
    final tf = prefs.getInt(_kTimeframe) ?? 5;
    final cornerName = prefs.getString(_kCorner);
    return DockSettings(
      timeframe: kTimeframes.contains(tf) ? tf : 5,
      corner: DockCorner.values.firstWhere(
        (c) => c.name == cornerName,
        orElse: () => DockCorner.topRight,
      ),
      mini: prefs.getBool(_kMini) ?? false,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt(_kTimeframe, timeframe);
    await prefs.setString(_kCorner, corner.name);
    await prefs.setBool(_kMini, mini);
  }
}

class CandleDockApp extends StatelessWidget {
  const CandleDockApp({super.key, required this.prefs, required this.initial});

  final SharedPreferences prefs;
  final DockSettings initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candle Countdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF26A69A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CandleDock(prefs: prefs, settings: initial),
    );
  }
}

class CandleDock extends StatefulWidget {
  const CandleDock({super.key, required this.prefs, required this.settings});

  final SharedPreferences prefs;
  final DockSettings settings;

  @override
  State<CandleDock> createState() => _CandleDockState();
}

class _CandleDockState extends State<CandleDock> {
  late final DockSettings _s = widget.settings;
  late CandleState _state = candleStateAt(DateTime.now(), _s.timeframe);
  Timer? _ticker;
  int _lastShownSecond = -1;

  /// Web only: whether the dock was opened in a floating window on load.
  bool _autoPoppedOut = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && popout.canPopOut && !popout.isPoppedOut) {
      // Try to open the floating window straight away. This only succeeds if
      // the browser allows pop-ups for this site; otherwise the page shows a
      // button so a click (a user gesture) can open it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = _s.mini ? kMiniSize : kFullSize;
        final ok = popout.popOut(size.width.round(), size.height.round());
        if (ok && mounted) setState(() => _autoPoppedOut = true);
      });
    }
    // Poll the device clock a few times a second and only repaint when the
    // displayed second changes. Polling (rather than a 1 s periodic timer)
    // keeps the display locked to the real clock even if the timer drifts
    // or the machine sleeps.
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final next = candleStateAt(DateTime.now(), _s.timeframe);
    final shown = next.remainingSeconds;
    if (shown != _lastShownSecond || next.candleOpen != _state.candleOpen) {
      _lastShownSecond = shown;
      setState(() => _state = next);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _setTimeframe(int tf) async {
    setState(() {
      _s.timeframe = tf;
      _state = candleStateAt(DateTime.now(), tf);
      _lastShownSecond = _state.remainingSeconds;
    });
    await _s.save(widget.prefs);
  }

  Future<void> _setCorner(DockCorner corner) async {
    setState(() => _s.corner = corner);
    await _s.save(widget.prefs);
    if (_isDesktop) await _applyCorner(corner);
  }

  Future<void> _toggleMini() async {
    setState(() => _s.mini = !_s.mini);
    await _s.save(widget.prefs);
    if (kIsWeb && popout.isPoppedOut) {
      final size = _s.mini ? kMiniSize : kFullSize;
      popout.resizeSelf(size.width.round(), size.height.round());
    }
    if (_isDesktop) {
      final size = _s.mini ? kMiniSize : kFullSize;
      await windowManager.setMinimumSize(size);
      await windowManager.setMaximumSize(size);
      await windowManager.setSize(size);
      await _applyCorner(_s.corner);
    }
  }

  Future<void> _close() async {
    if (_isDesktop) {
      await windowManager.close();
    }
  }

  Color _accentFor(int secondsLeft) {
    if (secondsLeft <= 10) return const Color(0xFFEF5350); // red
    if (secondsLeft <= 30) return const Color(0xFFFFB74D); // amber
    return const Color(0xFF26A69A); // teal
  }

  @override
  Widget build(BuildContext context) {
    final secs = _state.remainingSeconds;
    final accent = _accentFor(secs);
    final body = _s.mini ? _buildMini(accent, secs) : _buildFull(accent, secs);

    final dock = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171C),
        borderRadius: BorderRadius.circular(_s.mini ? 10 : 12),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );

    if (!kIsWeb) {
      return Scaffold(backgroundColor: Colors.transparent, body: dock);
    }

    // On the web the dock sits at its native size in the middle of the page
    // (or fills the window when popped out into a small popup).
    if (popout.isPoppedOut) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0D10),
        body: Center(child: dock),
      );
    }

    final size = _s.mini ? kMiniSize : kFullSize;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.fromSize(size: size, child: dock),
            const SizedBox(height: 20),
            if (popout.canPopOut) _buildPopOutPrompt(accent),
          ],
        ),
      ),
    );
  }

  /// Shown under the dock on the web landing page.
  Widget _buildPopOutPrompt(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _popOut,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(
            _autoPoppedOut
                ? 'Opened in a floating window \u2013 open again'
                : 'Open as floating window',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _autoPoppedOut
              ? 'Keep the floating window on top of your charts. '
                    'You can close this tab.'
              : 'Allow pop-ups for this site and the floating window '
                    'will open automatically next time.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  void _popOut() {
    final size = _s.mini ? kMiniSize : kFullSize;
    final ok = popout.popOut(size.width.round(), size.height.round());
    if (ok) setState(() => _autoPoppedOut = true);
  }

  Widget _buildMini(Color accent, int secs) {
    return DragToMoveArea(
      child: GestureDetector(
        onDoubleTap: _toggleMini,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(width: 4, color: accent),
            const SizedBox(width: 10),
            Text(
              '${_s.timeframe}m',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatCountdown(secs),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.open_in_full,
              tooltip: 'Expand',
              onTap: _toggleMini,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildFull(Color accent, int secs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title bar: draggable handle plus window controls.
        DragToMoveArea(
          child: GestureDetector(
            onDoubleTap: _toggleMini,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
              child: Row(
                children: [
                  Icon(Icons.candlestick_chart, size: 14, color: accent),
                  const SizedBox(width: 6),
                  const Text(
                    'CANDLE CLOSE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (popout.canPopOut && !popout.isPoppedOut)
                    _IconBtn(
                      icon: Icons.open_in_new,
                      tooltip: 'Pop out into a small window',
                      onTap: _popOut,
                    ),
                  if (_isDesktop)
                    PopupMenuButton<DockCorner>(
                      tooltip: 'Dock position',
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(24, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.dock, color: Colors.white54),
                      initialValue: _s.corner,
                      onSelected: _setCorner,
                      itemBuilder: (_) => [
                        for (final c in DockCorner.values)
                          PopupMenuItem(
                            value: c,
                            height: 32,
                            child: Text(
                              c.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  _IconBtn(
                    icon: Icons.close_fullscreen,
                    tooltip: 'Mini mode (double-click title)',
                    onTap: _toggleMini,
                  ),
                  if (_isDesktop)
                    _IconBtn(icon: Icons.close, tooltip: 'Quit', onTap: _close),
                ],
              ),
            ),
          ),
        ),
        // Countdown.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCountdown(secs),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_s.timeframe} min',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'closes ${formatClock(_state.candleClose)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'now ${formatClock(_state.now)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Candle progress.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _state.progress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              color: accent,
            ),
          ),
        ),
        // Timeframe picker.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final tf in kTimeframes)
                _TimeframeChip(
                  minutes: tf,
                  selected: tf == _s.timeframe,
                  accent: accent,
                  onTap: () => _setTimeframe(tf),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeframeChip extends StatelessWidget {
  const _TimeframeChip({
    required this.minutes,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${minutes}m',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white54),
        ),
      ),
    );
  }
}
