# Changelog

All notable changes to WinBar are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Roadmap
- English user interface (currently pt-BR)
- Badges and "wants attention" flash on app buttons
- Tray icons: volume, battery, Wi-Fi
- Homebrew cask

## [0.1.10] — 2026-10-16

### Fixed
- Show desktop on Macs whose shortcut entry stores modifiers 0: function keys (F1–F20) now always carry the fn bit in the synthetic event, whatever the plist says (verified live: F11 without it does nothing).

## [0.1.9] — 2026-10-16

### Fixed
- **Show desktop works.** Verified live on macOS: a synthetic F11 only triggers Mission Control's *Show Desktop* when it carries the fn bit, which 0.1.6 had stripped. The key is read from the system shortcut (fn bit kept) and posted after the user's modifiers are released. Control+Option+D and the bottom-right button use the same path.
- Clicking the active window's button minimizes it; verified live (log explains each decision).

## [0.1.7] — 2026-10-16

### Fixed
- Synthetic keys (show desktop, Mission Control, Spaces) fired while the user still held the hotkey's modifiers, so the system saw e.g. Control+Option+F11 and nothing happened. WinBar now waits (up to 1 s) for the modifiers to be released before posting.

### Changed
- Startup log line carries the version and the permission state; window-click log lines explain the decision (frontmost app, target, focused, minimized, hidden).

## [0.1.6] — 2026-10-16

### Fixed
- `install.sh` reset the Accessibility / Screen Recording grants on **every** update even though the signature was stable: the check used `codesign -dv`, which does not print the `Authority=` line (`-dvv` does), and `grep -q` under `pipefail` made the test fail anyway (SIGPIPE). Output is now captured and matched without a pipe. Permissions really survive updates.
- *Show desktop* did nothing: the synthesized F11 carried the "fn" modifier bit stored in the system shortcut, which changes how the key is interpreted. Only ⇧⌃⌥⌘ are sent now. (Wrong diagnosis — reverted in 0.1.9: the fn bit is required.)

### Added
- Clicking the button of the **active** window minimizes it (Windows behaviour), checked live (app frontmost + window focused), never from cached state; any other window comes to the front. Toggle in Settings › Cliques.
- Control+Option+D shows the desktop (like Win+D). Click paths and the show-desktop path write one log line each (no personal data) to make reports verifiable.

## [0.1.5] — 2026-10-16

### Fixed
- The double-arrow resize cursor still appeared at the window/bar boundary: macOS let the app under the bar own the cursor over the bar's first pixels. Windows kept above the bar now end 6 pt *above* it instead of 6 pt under it, so the app's resize zone ends before the bar — no cursor fight at all.

## [0.1.4] — 2026-10-16

### Changed
- **Show desktop** now triggers the native Mission Control *Show Desktop* shortcut (read from the system's keyboard shortcuts, default F11): every window leaves at once, the next click brings them back, and the bar stays put. The hide-all method remains only as a fallback when that shortcut is disabled.
- **Windowless apps quit** (Windows behaviour), whichever way the last window was closed — from the bar or with the red button / ⌘W — after a 3 s grace. From the bar, closing all of an app's windows now quits it directly instead of pressing ✕ and polling. Finder is never quit; new per-app exception *Keep running without windows* (context menu + Settings list) keeps e.g. Spotify playing, visible on the bar as an icon, and clicking it reopens its window like the Dock does.
- Apps that do not answer Accessibility in time (busy) keep their last known windows instead of vanishing from the bar.
- Desktop switching uses the key actually configured for *Switch to Desktop N*, not a hard-coded Control+digit.

### Removed
- Dead settings (`locked`, `onlyCurrentSpace`, `clickActiveMinimizes`), the one-off migrations, legacy `smallButtons` key, unused theme tokens and helpers. Unknown or removed keys in an existing settings file are ignored.

## [0.1.3] — 2026-10-16

### Added
- **Starts with macOS by default.** A per-user LaunchAgent (`~/Library/LaunchAgents/io.github.alsppg.winbar.plist`, RunAtLoad + KeepAlive on crash) replaces the `SMAppService` login item: it does not depend on code signing, its state is checkable with `launchctl`, and WinBar is reopened automatically if it ever crashes (a normal *Quit* is not). The app writes and repairs the agent on every launch when the setting is on; `install.sh` registers it too, so the first run is already supervised by launchd. `--uninstall` removes it.
- Single-instance guard: a second copy (agent + old login item + manual open) exits immediately.

### Changed
- *Relaunch* goes through `launchctl kickstart` when the agent is loaded, so the new instance stays managed by launchd.
- Migration 2 turns *start at login* on for existing installs and removes the old login-item registration.

## [0.1.2] — 2026-10-15

### Fixed
- After an update the bar showed no windows: macOS ties the Accessibility grant to the app signature and the ad-hoc signature changes with every build, while `AXIsProcessTrusted()` kept saying yes. The app now probes the API for real and reopens the welcome window with the fix (toggle WinBar off and on).

### Added
- `install.sh` signs the downloaded app with a local self-signed "WinBar Dev" identity (created once in the login keychain) so permissions survive updates; when the signature changes it clears the stale grants so macOS prompts cleanly. `--no-resign` opts out; `--uninstall` also removes the identity.

## [0.1.1] — 2026-10-15

### Changed
- **Closing the last window from the bar now quits the app** (Windows behaviour): thumbnail ✕, middle-click, *Close window* and *Close all windows* end the program instead of leaving it running in the Dock. Waits up to 10 s for "Save changes?" dialogs, only acts on a confirmed zero-window count (busy apps are left alone), never quits Finder. New toggle *Quit app on last window close* (bar menu and Settings), on by default.

### Added
- `install.sh --uninstall` now removes everything (app, settings, pins, logs, caches, Accessibility/Screen Recording grants); `--restore-dock` undoes `--dock-left`. `scripts/make-cert.sh --remove` deletes the local signing identity.

### Fixed
- One-line installer failed on macOS with `REPO?: unbound variable`: bash 3.2 swallowed the Unicode ellipsis after `$REPO` into the variable name. `install.sh` is now pure ASCII.

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
