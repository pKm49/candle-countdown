import 'package:web/web.dart' as web;

bool get canPopOut => true;

/// A popup opened by [popOut] carries `?popout=1` so it can hide the
/// pop-out button, fill its window, and not try to pop out again.
bool get isPoppedOut => web.window.location.search.contains('popout=1');

/// Opens the dock in a small, chromeless browser popup window.
///
/// Returns true if the window opened. Browsers refuse popups that are not
/// triggered by a user gesture unless the user has allowed pop-ups for the
/// site, in which case `window.open` returns null.
bool popOut(int width, int height) {
  final loc = web.window.location;
  final base = '${loc.origin}${loc.pathname}';
  // Some browsers add a title bar; give a little vertical slack for it.
  final features =
      'popup=yes,width=$width,height=${height + 8},'
      'menubar=no,toolbar=no,location=no,status=no,resizable=no';
  final win = web.window.open('$base?popout=1', 'candle_dock', features);
  if (win == null) return false;
  win.focus();
  return true;
}

/// Resize this popup so its content area is [width] x [height]. Browsers only
/// allow this for windows that were opened by script, i.e. our popup.
void resizeSelf(int width, int height) {
  if (!isPoppedOut) return;
  final w = web.window;
  final chromeW = w.outerWidth - w.innerWidth;
  final chromeH = w.outerHeight - w.innerHeight;
  w.resizeTo(width + chromeW, height + chromeH);
}
