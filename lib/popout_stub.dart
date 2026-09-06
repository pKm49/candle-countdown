/// Non-web implementation: popping out is a browser-only feature.
bool get canPopOut => false;

/// Whether this page is itself a popped-out window.
bool get isPoppedOut => false;

void popOut(int width, int height) {}
