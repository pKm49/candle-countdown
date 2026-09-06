import 'package:web/web.dart' as web;

bool get canPopOut => true;

/// A popup opened by [popOut] carries `?popout=1` so it can hide the
/// pop-out button and skip the page chrome.
bool get isPoppedOut => web.window.location.search.contains('popout=1');

/// Opens the dock in a small, chromeless browser popup window.
void popOut(int width, int height) {
  final loc = web.window.location;
  final base = '${loc.origin}${loc.pathname}';
  // Some browsers add a title bar; give a little vertical slack for it.
  final features =
      'popup=yes,width=$width,height=${height + 8},'
      'menubar=no,toolbar=no,location=no,status=no,resizable=no';
  web.window.open('$base?popout=1', 'candle_dock', features);
}
