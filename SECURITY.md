# Security Policy

WinBar runs with two sensitive macOS permissions (Accessibility and, optionally, Screen Recording), so we take reports seriously.

## Supported versions

Only the latest release on the [Releases page](https://github.com/alsppg/WinBar/releases) is supported.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private reporting: *Security › Report a vulnerability* on this repository. You will get an acknowledgement within 7 days.

Include: macOS version, WinBar version, steps to reproduce and the impact you see.

## What WinBar does and does not do

- Makes **no network connections** (verify: `nettop -p WinBar`).
- Stores data only in `~/Library/Preferences/io.github.alsppg.winbar.plist`, `~/Library/Application Support/WinBar/` (mode 600) and `~/Library/Logs/WinBar/` (rotated at 1 MB, no window titles, no personal paths).
- Uses Accessibility only to list/activate/resize/close windows and Screen Recording only to render window thumbnails while a fly-out is open.
- Release binaries are built by GitHub Actions from the tagged source and signed ad-hoc; every release ships a `.sha256` next to the zip.
