# Changelog

All notable changes to WinBar are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Roadmap
- English user interface (currently pt-BR)
- Badges and "wants attention" flash on app buttons
- Tray icons: volume, battery, Wi-Fi
- Homebrew cask

## [1.0.0] — 2026-10-16

First public release.

### Taskbar
- Bottom taskbar on every Space and display, above all windows; hides in full-screen apps; optional auto-hide; four heights; dark or accent-colour variant; transparency on/off.
- App buttons in three styles: icons only (combined), icons with app name, or classic — one wide button per window with its title. Running/active/stacked indicators.
- Pinned apps glued to the Start button (right-click → *Add to taskbar*, or drop a `.app` from Finder); drag to reorder.
- Window thumbnails on hover (ScreenCaptureKit); click = activate, ✕ or middle-click = close.
- Click brings a window to the front; clicking the **active** window's button minimizes it (checked live: app frontmost + window focused). Control+Option+1…9 presses button N.
- Windows kept above the bar: windows that invade it are resized to end 6 pt above it, so their resize zone (double-arrow cursor) never reaches the bar. *Adjust windows to the bar now* in the bar menu.

### Windows semantics
- **No app lingers without a window**: closing an app's last window — from the bar or any other way — quits it after a 3 s grace; from the bar, closing all of an app's windows quits it directly. Finder is never quit. Per-app exception *Keep running without windows* (e.g. Spotify playing) keeps it on the bar as an icon; clicking reopens its window.
- **Show desktop** (bottom-right corner, empty bar area, Control+Option+D) triggers the native Mission Control *Show Desktop* shortcut read from the system settings; windows leave at once and return on the next click. Falls back to hiding every app if the shortcut is disabled.

### Start menu, tray, clock
- Start menu (Control+Esc): search, A–Z list of every installed app (same coverage as the macOS *Apps* app, Finder included), Documents/Downloads shortcuts, power actions.
- Desktops (Spaces) switcher left of the clock; two-line clock with calendar fly-out.

### System integration
- Starts with macOS by default and reopens after a crash: per-user LaunchAgent, visible under *Login Items › Allow in the Background*; toggle in Settings. Single-instance guard.
- Apps that do not answer Accessibility in time keep their last known windows instead of vanishing from the bar.
- Welcome window asks for Accessibility (required) and Screen Recording (thumbnails); it reopens with guidance whenever the grant is missing or stale.

### Installer
- One-line installer: downloads the latest release, verifies its SHA-256, signs the app with a local self-signed "WinBar Dev" identity (created once in the login keychain) so Accessibility / Screen Recording grants survive updates, registers the LaunchAgent and starts the app. `--dock-left` moves the Dock aside; `--no-resign` keeps the ad-hoc signature.
- `--uninstall` removes everything (app, agent, settings, pins, logs, caches, local certificate, grants); `--restore-dock` undoes `--dock-left`.
- Pure ASCII script (macOS ships bash 3.2, which swallows Unicode characters adjacent to variables).

### Privacy
- No network access, no analytics, no accounts, no update checker. Log rotates at 1 MB and never contains window titles or personal paths.
