#!/bin/bash
# Compila o WinBar e monta build/WinBar.app assinado.
# Uso: ./scripts/make-app.sh [debug|release]   (padrão: release)
# Compila com swiftc direto (sem SwiftPM): o pacote não tem dependências, e o swift-package
# do Command Line Tools às vezes vem quebrado. Se preferir SwiftPM: WINBAR_USE_SPM=1.
# O SDK é escolhido testando um "hello world" contra cada SDK instalado, porque o CLT pode vir com
# SDK mais novo que o compilador (erro "this SDK is not supported by the compiler").
# Forçar um SDK: WINBAR_SDK=/caminho/MacOSX26.sdk
# Assinatura: usa a identidade "WinBar Dev" se existir no Keychain (ver make-cert.sh); senão ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/WinBar.app"
IDENTITY="${WINBAR_SIGN_IDENTITY:-WinBar Dev}"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macosx14.0"
mkdir -p build

pick_sdk() {
  local probe; probe="$(mktemp -d)"
  echo 'import AppKit; import SwiftUI; let _ = NSApplication.shared' > "$probe/probe.swift"
  local candidates=()
  [ -n "${WINBAR_SDK:-}" ] && candidates+=("$WINBAR_SDK")
  local xs; xs="$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || true)"; [ -n "$xs" ] && candidates+=("$xs")
  # Demais SDKs do CLT e de qualquer Xcode instalado, do mais novo para o mais antigo
  while IFS= read -r d; do candidates+=("$d"); done < <(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk \
      /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk 2>/dev/null | sort -rV)
  local seen=" " sdk
  for sdk in "${candidates[@]}"; do
    [ -d "$sdk" ] || continue
    case "$seen" in *" $sdk "*) continue;; esac; seen="$seen$sdk "
    if xcrun swiftc -swift-version 5 -target "$TARGET" -sdk "$sdk" -framework AppKit -framework SwiftUI \
         "$probe/probe.swift" -o "$probe/probe" >"$probe/log" 2>&1; then
      rm -rf "$probe"; echo "$sdk"; return 0
    fi
  done
  echo "" ; rm -rf "$probe"; return 1
}

if [ "${WINBAR_USE_SPM:-0}" = "1" ]; then
  echo "==> swift build -c $CONFIG"
  swift build -c "$CONFIG"
  BIN="$(swift build -c "$CONFIG" --show-bin-path)/WinBar"
else
  echo "==> compilador: $(xcrun swiftc --version 2>&1 | head -1)"
  SDK="$(pick_sdk || true)"
  if [ -z "$SDK" ]; then
    cat >&2 <<'EOF'
ERRO: nenhum SDK instalado compila com o compilador Swift atual (SDK mais novo que o compilador).
Correção: reinstalar o Command Line Tools e rodar este script de novo:
    sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install
(ou instalar o Xcode pela App Store e rodar: sudo xcode-select -s /Applications/Xcode.app)
EOF
    exit 1
  fi
  OPT="-O"; [ "$CONFIG" = "debug" ] && OPT="-Onone -g"
  echo "==> swiftc ($ARCH, $CONFIG, SDK $(basename "$SDK"))"
  # shellcheck disable=SC2046
  xcrun swiftc $OPT -swift-version 5 -module-name WinBar \
    -target "$TARGET" -sdk "$SDK" \
    -framework AppKit -framework SwiftUI -framework ScreenCaptureKit -framework Carbon -framework ServiceManagement \
    $(find Sources/WinBar -name '*.swift' | sort) \
    -o build/WinBar
  BIN="build/WinBar"
fi
[ -x "$BIN" ] || { echo "binário não encontrado em $BIN"; exit 1; }

echo "==> montando $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WinBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -n "${WINBAR_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${WINBAR_VERSION#v}" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "$APP/Contents/Info.plist"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -d Resources/AppIcon.iconset ]; then
  iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null \
    && echo "==> ícone gerado" || echo "aviso: iconutil falhou; app fica com ícone genérico"
fi

chmod 755 "$APP/Contents/MacOS/WinBar"
find "$APP" -type d -exec chmod 755 {} +
find "$APP" -type f -not -path "*/MacOS/*" -exec chmod 644 {} +

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
  echo "==> assinando com \"$IDENTITY\" (identidade estável: o macOS não pede Acessibilidade de novo a cada build)"
  codesign --force --deep --sign "$IDENTITY" --timestamp=none "$APP"
else
  echo "==> assinando ad-hoc (rode ./scripts/make-cert.sh uma vez para ter identidade estável)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --verbose=2 "$APP" && echo "==> OK: $APP"
