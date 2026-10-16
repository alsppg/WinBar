#!/bin/bash
# Instala o build local (build/WinBar.app) em /Applications e abre. Opcional: --dock-left move o Dock para a esquerda
# e ativa o auto-ocultar, deixando a borda inferior livre para a barra.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d build/WinBar.app ] || ./scripts/make-app.sh release

if [ "${1:-}" = "--dock-left" ]; then
  defaults write com.apple.dock orientation -string left
  defaults write com.apple.dock autohide -bool true
  # Canto inferior direito do macOS vem com "Nota Rápida" (Hot Corner); desliga para o clique no botão
  # "Mostrar área de trabalho" ser certeiro. Reativar: Ajustes do Sistema > Mesa e Dock > Cantos Ativos.
  defaults write com.apple.dock wvous-br-corner -int 1
  defaults write com.apple.dock wvous-br-modifier -int 0
  killall Dock || true
  echo "==> Dock movido para a esquerda com auto-ocultar; Hot Corner inferior direito desligado."
fi

launchctl bootout "gui/$(id -u)/io.github.alsppg.winbar" 2>/dev/null || true   # senao o launchd reabre a copia antiga
pkill -x WinBar 2>/dev/null || true
rm -rf /Applications/WinBar.app
cp -R build/WinBar.app /Applications/WinBar.app
open -n /Applications/WinBar.app
cat <<'EOF'
==> WinBar instalado em /Applications (build local).
    1) Conceda Acessibilidade e Gravação de Tela na janela de boas-vindas (ou em Ajustes do Sistema > Privacidade e Segurança).
    2) Depois de conceder Acessibilidade, clique em "Relançar".
    3) Ajustes: clique direito na barra > Ajustes…   ou o ícone do WinBar na barra de menus.
EOF
