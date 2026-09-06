# Candle Countdown Dock

A small always-on-top desktop dock (Linux and Windows), plus a web version,
that counts down to the close of the current trading candle.

**Live web version:** https://pkm49.github.io/candle-countdown/ (deployed from
`main` by `.github/workflows/deploy-pages.yml`).

- Timeframes: **30, 15, 10, 5, 3, 2, 1 minutes**
- Uses the device clock. Candle boundaries are aligned to the UTC epoch, the
  same grid exchanges use, so the countdown always targets the next real
  milestone (e.g. with 5m selected at 10:07:30 it shows `02:30` to 10:10:00).
- Shows time left as `mm:ss`, the wall-clock close time, the current time and
  a progress bar for the candle. Turns amber under 30 s and red under 10 s.
- Frameless, always on top, draggable by its title bar.
- Dock menu snaps the window to a screen corner (or leave it free-floating).
- Mini mode (double-click the title bar or use the shrink button) collapses
  the dock to a one-line bar with just the timeframe and the countdown.
- Timeframe, dock corner and mini mode persist between launches.
- Web version: the dock is centred on a dark page. The "pop out" button opens
  it in a small chromeless browser popup you can park next to your charts.
  Chrome/Edge also let you install it as an app (address bar > Install).

## Requirements

Flutter 3.44.x (Dart 3.12). The repo pins `3.44.4` in `.fvmrc`; with
[fvm](https://fvm.app) run `fvm use` and prefix commands with `fvm`.

### Linux build dependencies (Debian/Ubuntu)

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Windows

Visual Studio 2022 with the "Desktop development with C++" workload.

## Run / build

```bash
flutter pub get
flutter test

# Linux
flutter run -d linux
flutter build linux --release      # -> build/linux/x64/release/bundle/

# Windows (from a Windows machine)
flutter run -d windows
flutter build windows --release    # -> build/windows/x64/runner/Release/

# Web
flutter run -d chrome
flutter build web --release        # -> build/web/
```

The `build/web/` folder is static and can be served by any web server or
static host (GitHub Pages, Netlify, nginx, S3...). To try it locally:

```bash
cd build/web && python3 -m http.server 8765   # then open http://localhost:8765
```

Note: Flutter web must be served over http(s); opening `index.html` directly
from the filesystem does not work.

## Layout

- `lib/candle_clock.dart` – pure timing logic (candle open/close, remaining,
  progress, formatting). Unit-tested in `test/candle_clock_test.dart`.
- `lib/main.dart` – the dock UI and window management (`window_manager`),
  settings persistence (`shared_preferences`).
- `lib/popout_web.dart` / `lib/popout_stub.dart` – browser pop-out window
  (conditionally imported so desktop builds never touch `package:web`).
