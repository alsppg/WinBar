# WinBar

**A Windows 10–style taskbar for macOS.** Open apps and windows in a bar at the bottom of the screen, pinned apps next to a Start menu, live window thumbnails, a clock with calendar, desktop (Spaces) switcher and a "show desktop" button — 100 % local, no accounts, no telemetry, free and open source.

🇧🇷 [Leia em Português (Brasil)](README.pt-BR.md)

[![CI](https://github.com/alsppg/WinBar/actions/workflows/ci.yml/badge.svg)](https://github.com/alsppg/WinBar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/alsppg/WinBar?display_name=tag)](https://github.com/alsppg/WinBar/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey)

## Features

- **Taskbar at the bottom edge**, on every Space and every display, above all windows; hides automatically in full-screen apps; optional auto-hide.
- **App buttons** with the Windows 10 look: running indicator, active state, stacked indicator for multiple windows. Three styles: icons only (combined), icons with app name, or **classic** — one wide button per window with its title.
- **Pinned apps** glued to the Start button (right-click any app → *Add to taskbar*; drag a `.app` from Finder onto the bar). Drag to reorder.
- **Window thumbnails** on hover (ScreenCaptureKit) — click to activate, ✕ or middle-click to close.
- **Click brings to front**, always (never minimizes). Right-click → new window, pin/unpin, show in Finder, hide, force quit, close window(s), quit.
- **Start menu** with search, A–Z list of every installed app (same coverage as the macOS *Apps* app, Finder included), Documents/Downloads shortcuts and power actions (sleep, lock, log out, restart, shut down). Shortcut: Control + Esc.
- **Desktops (Spaces) switcher** left of the clock: current/total, click to pick, scroll to cycle, right-click for Mission Control.
- **Clock** in two lines with a month calendar fly-out; **Show desktop** button in the bottom-right corner (also: click any empty area of the bar).
- **Windows stay above the bar**: maximized or moved windows are resized to end at the bar, like the Windows work area.
- Bar heights 30/40/48/56 pt, dark or accent-colour variant, transparency on/off. Control+Option+1…9 activates button N.

## Install

Requires **macOS 14 Sonoma or newer** (Apple Silicon or Intel).

### Option 1 — one line (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --dock-left
```

It downloads the latest [release](https://github.com/alsppg/WinBar/releases/latest), verifies its SHA-256, installs `/Applications/WinBar.app` and opens it. `--dock-left` moves the macOS Dock to the left edge with auto-hide and turns off the bottom-right Hot Corner, so the bottom edge belongs to WinBar (omit it to leave the Dock alone).

### Option 2 — download

1. Download `WinBar-vX.Y.Z.zip` from the [latest release](https://github.com/alsppg/WinBar/releases/latest) and unzip it.
2. Move `WinBar.app` to `/Applications`.
3. WinBar is signed ad-hoc (no paid Apple certificate), so Gatekeeper will warn once. Either run `xattr -dr com.apple.quarantine /Applications/WinBar.app` in Terminal, or open it and then allow it in *System Settings › Privacy & Security › Open Anyway*.

### Option 3 — build from source

Needs the Xcode Command Line Tools (`xcode-select --install`). No Xcode project, no dependencies.

```bash
git clone https://github.com/alsppg/WinBar.git && cd WinBar
./scripts/make-cert.sh                      # once: local signing identity, keeps permissions stable across builds
./scripts/make-app.sh release               # builds build/WinBar.app with swiftc
./scripts/install-from-source.sh --dock-left
```

### First launch

WinBar asks for two permissions in its welcome window:

| Permission | Why | Required |
| --- | --- | --- |
| **Accessibility** | list, activate, resize and close other apps' windows | yes |
| **Screen Recording** | live window thumbnails (without it the card shows icon + title only) | no |

Grant them in *System Settings › Privacy & Security*, then click **Relaunch**. The app has no Dock icon; it lives in the bar and in a small menu-bar icon (Settings / Relaunch / Quit).

## Using it

| Action | Result |
| --- | --- |
| Click an app | brings its window(s) to the front; launches it if closed |
| Hover an app | thumbnails of its windows (click = activate, ✕ / middle-click = close) |
| Right-click an app | New window · Add/Remove from taskbar · Show in Finder · Hide · Force quit · Close window(s) · Quit |
| Right-click the bar | Show desktop · Mission Control · Auto-hide · Keep windows above the bar · Button style · Bar height · Settings |
| Click an empty area | show desktop / restore |
| Start button or Control + Esc | app list with search; Enter opens the first match |
| Desktops button | pick a Space; scroll to cycle; right-click = Mission Control |
| Shift+click / middle-click | new window · Cmd+click: show in Finder · Option+click: hide |

Tip: `scripts/fast-animations.sh` shortens the macOS minimize/restore animations (reversible with `--undo`).

## Privacy & security

- No network access at all, no analytics, no accounts, no update checker. Verify with `nettop -p WinBar`.
- Data lives only in `~/Library/Preferences/io.github.alsppg.winbar.plist`, `~/Library/Application Support/WinBar/pins.json` (mode 600) and `~/Library/Logs/WinBar/winbar.log` (1 MB rotation; never contains window titles or personal paths).

## Uninstall

One line removes everything WinBar created — the app, settings, pinned apps, logs, caches and the Accessibility / Screen Recording grants:

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --uninstall
```

Add `--restore-dock` to also put the macOS Dock back at the bottom and re-enable the bottom-right Hot Corner (undoing `--dock-left`):

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --uninstall --restore-dock
```

Manual equivalent, if you prefer to see every step:

```bash
pkill -x WinBar
rm -rf /Applications/WinBar.app ~/Library/Application\ Support/WinBar ~/Library/Logs/WinBar ~/Library/Caches/io.github.alsppg.winbar
defaults delete io.github.alsppg.winbar
tccutil reset Accessibility io.github.alsppg.winbar && tccutil reset ScreenCapture io.github.alsppg.winbar
```

If WinBar still appears under *System Settings › General › Login Items*, toggle it off there. Built from source? Also run `./scripts/make-cert.sh --remove` to delete the local "WinBar Dev" signing identity, and delete the cloned folder.

## Known limitations

- macOS does not let third-party apps reserve screen space; WinBar instead resizes windows that overlap it (can be turned off: *Keep windows above the bar*). Windows end 6 pt under the bar so their resize handle never shows on it.
- Switching Spaces uses the system shortcuts: if *Switch to Desktop N* (Control+N) is enabled in *System Settings › Keyboard › Shortcuts › Mission Control* the jump is direct; otherwise WinBar steps with Control+←/→.
- The user interface is currently in Portuguese (pt-BR). English UI is on the [roadmap](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The reference behaviour is always the Windows 10 taskbar. Please read the [Code of Conduct](CODE_OF_CONDUCT.md) and the [security policy](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Alessandro (alsppg). WinBar is an independent project, not affiliated with Microsoft or Apple; "Windows" and "macOS" are trademarks of their owners.
