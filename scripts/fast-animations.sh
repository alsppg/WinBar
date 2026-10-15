#!/bin/bash
# Encurta as animações do macOS ao alternar/restaurar janelas (ajustes do sistema, não do WinBar).
# Reverter: ./scripts/fast-animations.sh --undo
set -euo pipefail

if [ "${1:-}" = "--undo" ]; then
  defaults delete com.apple.dock mineffect 2>/dev/null || true
  defaults delete -g NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
  defaults delete -g NSWindowResizeTime 2>/dev/null || true
  defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
  killall Dock || true
  echo "==> Animações restauradas ao padrão (apps abertos só mudam depois de reabertos)."
  exit 0
fi

# 1) Minimizar/restaurar: efeito "Escala" (bem mais curto que o "Gênio")
defaults write com.apple.dock mineffect -string scale
# 2) Mission Control / Mostrar área de trabalho: animação de 0,1 s em vez de ~0,3 s
defaults write com.apple.dock expose-animation-duration -float 0.1
# 3) Abrir/fechar/redimensionar janelas dos apps Cocoa: sem zoom e resize instantâneo
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
killall Dock || true

cat <<'EOF'
==> Aplicado: minimizar em "Escala", Mission Control em 0,1 s, janelas sem animação de abrir/redimensionar.
    Apps já abertos passam a valer depois de reabertos.
    A troca de Mesa (deslizar) só encurta por um ajuste que o macOS não expõe no terminal:
    Ajustes do Sistema > Acessibilidade > Tela > "Reduzir movimento" (vira um fade rápido em vez de deslizar).
EOF
