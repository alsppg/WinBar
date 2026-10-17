#!/bin/bash
# WinBar installer - downloads the latest release from GitHub and installs it in /Applications.
#   curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash
# Options:  --dock-left     also moves the macOS Dock to the left edge, enables auto-hide and
#                           disables the bottom-right Hot Corner (so the bottom edge belongs to WinBar)
#           --no-resign     keep the ad-hoc signature of the release (see "Signing" below)
#           --uninstall     removes WinBar completely: app, start-at-login agent, settings, pinned apps, logs,
#                           caches, the local signing certificate and the Accessibility / Screen Recording grants
#           --restore-dock  (with --uninstall) puts the Dock back at the bottom and re-enables the Hot Corner
# Signing: the release is signed ad-hoc (no paid Apple certificate). macOS ties the Accessibility and
# Screen Recording grants to the signature, and an ad-hoc signature changes with every build - so every
# update would silently lose them (the switch stays on in System Settings but no longer counts). To keep
# the grants stable the installer creates ONE self-signed "WinBar Dev" certificate in your login keychain
# and signs the app with it (same as scripts/make-cert.sh for source builds). Nothing leaves the Mac.
# Start at login: a per-user LaunchAgent (~/Library/LaunchAgents/io.github.alsppg.winbar.plist) opens WinBar
# with the session and reopens it if it ever crashes ("Quit" is a clean exit and is not reopened). It shows
# under System Settings > General > Login Items > Allow in the Background. The app keeps it in sync with the
# "start at login" setting; the installer registers it so WinBar is managed by launchd from the first run.
# Everything stays local: no telemetry, no accounts. Run without sudo.
set -euo pipefail

REPO="alsppg/WinBar"
APP_NAME="WinBar"
BUNDLE_ID="io.github.alsppg.winbar"
DEST="/Applications/$APP_NAME.app"
IDENTITY="WinBar Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
AGENT_PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
DOMAIN="gui/$(id -u)"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "WinBar runs on macOS only."

DOCK_LEFT=0; RESIGN=1; UNINSTALL=0; RESTORE_DOCK=0
for arg in "$@"; do
  case "$arg" in
    --dock-left) DOCK_LEFT=1 ;;
    --no-resign) RESIGN=0 ;;
    --uninstall) UNINSTALL=1 ;;
    --restore-dock) RESTORE_DOCK=1 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

restore_dock() {
  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock autohide -bool false
  defaults delete com.apple.dock wvous-br-corner 2>/dev/null || true
  defaults delete com.apple.dock wvous-br-modifier 2>/dev/null || true
  killall Dock 2>/dev/null || true
  say "Dock back at the bottom; bottom-right Hot Corner restored to the macOS default."
}

reset_grants() {
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset AppleEvents "$BUNDLE_ID" >/dev/null 2>&1 || true
}

# Stops a running copy whether launchd or the user started it (bootout first, or launchd would reopen it).
stop_app() {
  launchctl bootout "$DOMAIN/$BUNDLE_ID" 2>/dev/null || true
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
}

# Writes the LaunchAgent and loads it; loading starts the app (RunAtLoad). Returns 1 if launchd refused.
install_agent() {
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$BUNDLE_ID</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/$APP_NAME</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
PLIST
  chmod 644 "$AGENT_PLIST"
  launchctl enable "$DOMAIN/$BUNDLE_ID" 2>/dev/null || true
  launchctl bootstrap "$DOMAIN" "$AGENT_PLIST" 2>/dev/null
}

# Captured output, not "| grep -q": under pipefail, grep -q closing the pipe early fails the producer (SIGPIPE).
has_identity() {
  local ids; ids="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  case "$ids" in *"\"$IDENTITY\""*) return 0;; esac; return 1
}

# Creates the self-signed code-signing certificate once (private key stays in the login keychain).
make_identity() {
  local tmp pass
  tmp="$(mktemp -d)"; chmod 700 "$tmp"
  cat > "$tmp/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$tmp/openssl.cnf" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" >/dev/null 2>&1
  chmod 600 "$tmp/key.pem"
  pass="$(openssl rand -hex 16)"
  openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$IDENTITY" \
    -out "$tmp/cert.p12" -passout "pass:$pass" -legacy 2>/dev/null \
    || openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$IDENTITY" \
         -out "$tmp/cert.p12" -passout "pass:$pass"
  security import "$tmp/cert.p12" -k "$KEYCHAIN" -P "$pass" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
  say "macOS may now ask for your login password to trust the local certificate (one time)."
  security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem" \
    || say "Trust settings not changed; trying to sign anyway."
  rm -rf "$tmp"
}

if [ "$UNINSTALL" = 1 ]; then
  say "Quitting ${APP_NAME}..."
  stop_app
  say "Removing app, start-at-login agent, settings, pinned apps, logs and caches..."
  rm -f "$AGENT_PLIST"
  rm -rf "$DEST" "$HOME/Applications/$APP_NAME.app" \
         "$HOME/Library/Application Support/$APP_NAME" \
         "$HOME/Library/Logs/$APP_NAME" \
         "$HOME/Library/Caches/$BUNDLE_ID" \
         "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  say "Revoking Accessibility and Screen Recording grants..."
  reset_grants
  say "Removing the local signing certificate..."
  security delete-identity -c "$IDENTITY" "$KEYCHAIN" 2>/dev/null \
    || security delete-certificate -c "$IDENTITY" "$KEYCHAIN" 2>/dev/null || true
  if [ "$RESTORE_DOCK" = 1 ]; then restore_dock; fi
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
NEW="$tmp/out/$APP_NAME.app"
[ -d "$NEW" ] || die "Unexpected archive layout."
# Ad-hoc signed app: Gatekeeper would block it. Clearing the quarantine flag equals "Open Anyway".
xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || true

# Was the installed copy signed with the stable local identity? If not, its grants cannot survive.
# (-dvv: the Authority= lines only appear at verbosity 2.)
old_stable=0
if [ -d "$DEST" ]; then
  sig="$(codesign -dvv "$DEST" 2>&1 || true)"
  case "$sig" in *"Authority=$IDENTITY"*) old_stable=1;; esac
fi

signed=0
if [ "$RESIGN" = 1 ]; then
  if ! has_identity; then make_identity || say "Could not create the local certificate."; fi
  if has_identity && codesign --force --deep --sign "$IDENTITY" --timestamp=none "$NEW" 2>/dev/null \
     && codesign --verify --deep "$NEW" 2>/dev/null; then
    signed=1
    say "Signed with the local \"$IDENTITY\" identity (permissions survive future updates)."
  else
    say "Could not sign with \"$IDENTITY\"; keeping the ad-hoc signature (permissions must be re-granted after each update)."
  fi
fi

if [ "$DOCK_LEFT" = 1 ]; then
  defaults write com.apple.dock orientation -string left
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock wvous-br-corner -int 1
  defaults write com.apple.dock wvous-br-modifier -int 0
  killall Dock 2>/dev/null || true
  say "Dock moved to the left (auto-hide on); bottom-right Hot Corner disabled."
fi

stop_app
upgrade=0; [ -d "$DEST" ] && upgrade=1
rm -rf "$DEST"
cp -R "$NEW" "$DEST"

# On an upgrade whose signature changed, the old grants are stale: the switches look on but do nothing.
# Clear them so macOS prompts cleanly and the welcome window asks again.
regrant=0
if [ "$upgrade" = 1 ] && { [ "$old_stable" = 0 ] || [ "$signed" = 0 ]; }; then
  reset_grants; regrant=1
fi

if install_agent; then
  say "Installed $DEST - started by launchd; opens at login and reopens if it crashes."
else
  open -n "$DEST"
  say "Installed $DEST (launchd refused the agent; the app registers it itself on first run)."
fi
if [ "$regrant" = 1 ]; then
  cat <<'EOF'
The app signature changed with this update, so macOS dropped the old permissions: in the welcome window
grant Accessibility again (and Screen Recording for thumbnails), then click "Relaunch". From now on
updates keep the permissions.
EOF
else
  cat <<'EOF'
Next: in the welcome window grant Accessibility (required) and Screen Recording (window thumbnails),
then click "Relaunch". Right-click the bar for settings. Uninstall: install.sh --uninstall
EOF
fi
