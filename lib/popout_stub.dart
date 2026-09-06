/// Non-web implementation: popping out is a browser-only feature.
bool get canPopOut => false;

/// Whether this page is itself a popped-out window.
bool get isPoppedOut => false;

/// Returns true if a popup window was opened.
bool popOut(int width, int height) => false;

/// Resize this window's content area (only possible for popped-out windows).
void resizeSelf(int width, int height) {}
