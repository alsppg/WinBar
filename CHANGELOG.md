# Changelog

All notable changes to WinBar are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `install.sh --uninstall` now removes everything (app, settings, pins, logs, caches, Accessibility/Screen Recording grants); `--restore-dock` undoes `--dock-left`. `scripts/make-cert.sh --remove` deletes the local signing identity.

### Fixed
- One-line installer failed on macOS with `REPO?: unbound variable`: bash 3.2 swallowed the Unicode ellipsis after `$REPO` into the variable name. `install.sh` is now pure ASCII.

### Roadmap
- English user interface (currently pt-BR)
- Badges and "wants attention" flash on app buttons
- Tray icons: volume, battery, Wi-Fi
- Homebrew cask

## [0.1.0] — 2026-10-15

First public release.

### Added
- Bottom taskbar on every Space/display, auto-hide, full-screen awareness, 4 heights, dark/accent variants.
- App buttons (icons / icons+name / classic per-window), pinned apps glued to Start, drag to reorder, drop `.app` to pin.
- Window thumbnails on hover (ScreenCaptureKit), click-to-front, context menu (new window, pin, Finder, hide, force quit, close, quit).
- Start menu: search, A–Z list of all installed apps (Finder included), Documents/Downloads, power actions, Control+Esc.
- Desktops (Spaces) switcher, two-line clock with calendar, show-desktop button and empty-area click.
- "Keep windows above the bar": windows are resized to end at the bar (Windows work-area behaviour).
- One-line installer with SHA-256 verification; GitHub Actions CI and release builds.
