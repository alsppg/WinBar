#!/bin/bash
# WinBar installer - downloads the latest release from GitHub and installs it in /Applications.
#   curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash
# Options:  --dock-left     also moves the macOS Dock to the left edge, enables auto-hide and
#                           disables the bottom-right Hot Corner (so the bottom edge belongs to WinBar)
#           --uninstall     removes WinBar completely: app, settings, pinned apps, logs, caches and the
#                           Accessibility / Screen Recording grants
#           --restore-dock  (with --uninstall) puts the Dock back at the bottom and re-enables the Hot Corner
# Everything stays local: no telemetry, no accounts. Run without sudo.
set -euo pipefail

REPO="alsppg/WinBar"
APP_NAME="WinBar"
BUNDLE_ID="io.github.alsppg.winbar"
DEST="/Applications/$APP_NAME.app"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "WinBar runs on macOS only."

restore_dock() {
  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock autohide -bool false
  defaults delete com.apple.dock wvous-br-corner 2>/dev/null || true
  defaults delete com.apple.dock wvous-br-modifier 2>/dev/null || true
  killall Dock 2>/dev/null || true
  say "Dock back at the bottom; bottom-right Hot Corner restored to the macOS default."
}

if [ "${1:-}" = "--uninstall" ]; then
  say "Quitting ${APP_NAME}..."
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  say "Removing app, settings, pinned apps, logs and caches..."
  rm -rf "$DEST" "$HOME/Applications/$APP_NAME.app" \
         "$HOME/Library/Application Support/$APP_NAME" \
         "$HOME/Library/Logs/$APP_NAME" \
         "$HOME/Library/Caches/$BUNDLE_ID" \
         "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  say "Revoking Accessibility and Screen Recording grants..."
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset AppleEvents "$BUNDLE_ID" >/dev/null 2>&1 || true
  if [ "${2:-}" = "--restore-dock" ]; then restore_dock; fi
  say "$APP_NAME removed. If it still shows under System Settings > General > Login Items, toggle it off there."
  exit 0
fi

major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 14 ] || die "macOS 14 (Sonoma) or newer is required (found $(sw_vers -productVersion))."

say "Looking up the latest release of ${REPO}..."
json="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")" || die "Could not reach GitHub."
url="$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*'"$APP_NAME"'-[^"]*\.zip"' | head -1 | cut -d'"' -f4)"
[ -n "$url" ] || die "No release asset found. Build from source instead: see README."
tag="$(printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
say "Downloading $APP_NAME ${tag}..."
curl -fsSL "$url" -o "$tmp/app.zip"
if curl -fsSL "$url.sha256" -o "$tmp/app.zip.sha256" 2>/dev/null; then
  expected="$(cut -d' ' -f1 "$tmp/app.zip.sha256")"
  actual="$(shasum -a 256 "$tmp/app.zip" | cut -d' ' -f1)"
  [ "$expected" = "$actual" ] || die "Checksum mismatch - download corrupted. Try again."
  say "Checksum OK."
fi

ditto -x -k "$tmp/app.zip" "$tmp/out"
[ -d "$tmp/out/$APP_NAME.app" ] || die "Unexpected archive layout."
# The app is signed ad-hoc (no Apple Developer certificate), so Gatekeeper would block it.
# Clearing the quarantine flag is the same as the manual "Open Anyway" in System Settings.
xattr -dr com.apple.quarantine "$tmp/out/$APP_NAME.app" 2>/dev/null || true

if [ "${1:-}" = "--dock-left" ]; then
  defaults write com.apple.dock orientation -string left
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock wvous-br-corner -int 1
  defaults write com.apple.dock wvous-br-modifier -int 0
  killall Dock 2>/dev/null || true
  say "Dock moved to the left (auto-hide on); bottom-right Hot Corner disabled."
fi

pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$DEST"
cp -R "$tmp/out/$APP_NAME.app" "$DEST"
open -n "$DEST"
say "Installed $DEST"
cat <<'EOF'
Next: in the welcome window grant Accessibility (required) and Screen Recording (window thumbnails),
then click "Relaunch". Right-click the bar for settings. Uninstall: install.sh --uninstall
EOF
