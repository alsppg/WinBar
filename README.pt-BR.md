# WinBar

**Uma barra de tarefas no estilo do Windows 10 para macOS.** Apps e janelas abertos numa barra na borda inferior da tela, apps fixados ao lado de um menu Iniciar, miniaturas das janelas ao vivo, relógio com calendário, seletor de Mesas (áreas de trabalho) e botão "mostrar área de trabalho" — 100 % local, sem conta, sem telemetria, gratuito e de código aberto.

🇺🇸 [Read in English](README.md)

[![CI](https://github.com/alsppg/WinBar/actions/workflows/ci.yml/badge.svg)](https://github.com/alsppg/WinBar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/alsppg/WinBar?display_name=tag)](https://github.com/alsppg/WinBar/releases/latest)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey)

## Recursos

- **Barra na borda inferior**, em todas as Mesas e telas, acima das janelas; some sozinha em apps em tela cheia; auto‑ocultar opcional.
- **Botões de apps** com o visual do Windows 10: indicador de "em execução", estado ativo, indicador empilhado para várias janelas. Três estilos: só ícones (combinado), ícones com nome do app, ou **clássico** — um botão largo por janela, com o título.
- **Apps fixados** colados ao botão Iniciar (clique direito em qualquer app → *Adicionar à Barra de Tarefas*; ou arraste um `.app` do Finder para a barra). Arraste para reordenar.
- **Miniaturas das janelas** ao passar o mouse (ScreenCaptureKit) — clique ativa, ✕ ou botão do meio fecha.
- **Clique traz para a frente**, sempre (nunca minimiza). Clique direito → nova janela, fixar/remover, mostrar no Finder, ocultar, forçar encerrar, fechar janela(s), sair.
- **Nenhum app fica rodando sem janela**, como no Windows: fechar a última janela de um app — pela barra (✕, botão do meio, *Fechar janela*) ou por qualquer outro meio (botão vermelho, ⌘W) — encerra o app, após 3 s de carência para ele abrir outra janela ou perguntar "Salvar alterações?". Finder nunca. Apps marcados como *Manter em execução sem janelas* (clique direito; ex.: Spotify tocando) continuam na barra como ícone e reabrem a janela ao clicar. Pode ser desligado.
- **Menu Iniciar** com busca, lista A–Z de todos os apps instalados (mesma cobertura do app *Apps* do macOS, Finder incluído), atalhos para Documentos/Downloads e ações de energia (suspender, bloquear, encerrar sessão, reiniciar, desligar). Atalho: Control + Esc.
- **Seletor de Mesas** à esquerda do relógio: atual/total, clique para escolher, rolagem para alternar, clique direito abre o Mission Control.
- **Relógio** em duas linhas com calendário do mês; botão **Mostrar área de trabalho** no canto inferior direito (ou clique em qualquer área vazia da barra) — usa o atalho nativo *Mostrar Mesa* do Mission Control: todas as janelas saem de uma vez e voltam no próximo clique.
- **Janelas sempre acima da barra**: janelas maximizadas ou movidas são redimensionadas para terminar na barra, como a área de trabalho do Windows.
- Alturas 30/40/48/56 pt, variante escura ou na cor de destaque, transparência ligada/desligada. Control+Option+1…9 ativa o botão N.
- **Inicia com o macOS** e volta sozinho se algum dia cair: um LaunchAgent do usuário, ligado por padrão (*Ajustes › Inicialização* para desligar; aparece em *Ajustes do Sistema › Geral › Itens de Início › Permitir em segundo plano*). *Sair* é respeitado até o próximo login.

## Instalação

Requer **macOS 14 Sonoma ou mais novo** (Apple Silicon ou Intel).

### Opção 1 — uma linha (recomendada)

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --dock-left
```

Baixa a [versão mais recente](https://github.com/alsppg/WinBar/releases/latest), confere o SHA‑256, instala em `/Applications/WinBar.app` e abre. O `--dock-left` move o Dock do macOS para a esquerda com auto‑ocultar e desliga o Canto Ativo inferior direito, para a borda de baixo ficar com o WinBar (omita para não mexer no Dock).

O instalador também cria um certificado local auto‑assinado ("WinBar Dev") no seu Keychain de login e assina o app com ele. O macOS amarra as permissões de Acessibilidade e Gravação de Tela à assinatura do app, e a assinatura ad‑hoc de uma release muda a cada build — sem isso, toda atualização perderia as permissões em silêncio. Nada sai do seu Mac; o macOS pode pedir sua senha de login uma vez. `--no-resign` pula essa etapa.

### Opção 2 — download manual

1. Baixe `WinBar-vX.Y.Z.zip` na [versão mais recente](https://github.com/alsppg/WinBar/releases/latest) e descompacte.
2. Mova `WinBar.app` para `/Applications`.
3. O WinBar é assinado ad‑hoc (sem certificado pago da Apple), então o Gatekeeper avisa uma vez. Rode `xattr -dr com.apple.quarantine /Applications/WinBar.app` no Terminal, ou abra o app e depois libere em *Ajustes do Sistema › Privacidade e Segurança › Abrir Mesmo Assim*.
4. Depois de cada atualização manual, desligue e ligue o WinBar de novo em *Ajustes do Sistema › Privacidade e Segurança › Acessibilidade* (e Gravação de Tela): as permissões ficam presas à assinatura, que muda a cada release. O instalador de uma linha evita isso.

### Opção 3 — compilar do código‑fonte

Precisa do Xcode Command Line Tools (`xcode-select --install`). Sem projeto Xcode, sem dependências.

```bash
git clone https://github.com/alsppg/WinBar.git && cd WinBar
./scripts/make-cert.sh                      # uma vez: identidade de assinatura local, mantém as permissões entre builds
./scripts/make-app.sh release               # gera build/WinBar.app com o swiftc
./scripts/install-from-source.sh --dock-left
```

### Primeira abertura

O WinBar pede duas permissões na janela de boas‑vindas:

| Permissão | Para quê | Obrigatória |
| --- | --- | --- |
| **Acessibilidade** | listar, ativar, redimensionar e fechar janelas dos outros apps | sim |
| **Gravação de Tela** | miniaturas ao vivo das janelas (sem ela, o card mostra só ícone + título) | não |

Conceda em *Ajustes do Sistema › Privacidade e Segurança* e clique em **Relançar**. O app não tem ícone no Dock: vive na barra e num ícone pequeno na barra de menus (Ajustes / Relançar / Sair). Ele é iniciado e supervisionado pelo launchd: `launchctl print gui/$(id -u)/io.github.alsppg.winbar` mostra o estado.

**Atualizou e a barra não mostra nenhuma janela?** A permissão de Acessibilidade fica presa à assinatura do app; desligue e ligue o WinBar em *Acessibilidade* (a janela de boas‑vindas reabre avisando isso). Instalar pela linha única deixa a assinatura estável e isso para de acontecer.

## Como usar

| Ação | Resultado |
| --- | --- |
| Clique num app | traz a(s) janela(s) para a frente; abre se estiver fechado |
| Passar o mouse num app | miniaturas das janelas (clique = ativar, ✕ / botão do meio = fechar) |
| Clique direito num app | Nova janela · Adicionar/Remover da Barra de Tarefas · Mostrar no Finder · Ocultar · Manter em execução sem janelas · Forçar encerrar · Fechar janela(s) · Sair |
| Clique direito na barra | Mostrar área de trabalho · Mission Control · Auto‑ocultar · Manter janelas acima da barra · Encerrar apps que ficam sem janela · Estilo dos botões · Altura da barra · Ajustes |
| Clique em área vazia | mostrar área de trabalho / restaurar |
| Botão Iniciar ou Control + Esc | lista de apps com busca; Enter abre o primeiro resultado |
| Botão de Mesas | escolher uma Mesa; rolagem alterna; clique direito = Mission Control |
| Shift+clique / botão do meio | nova janela · Cmd+clique: mostrar no Finder · Option+clique: ocultar |

Dica: `scripts/fast-animations.sh` encurta as animações de minimizar/restaurar do macOS (reversível com `--undo`).

## Privacidade e segurança

- Nenhum acesso à rede, sem analytics, sem conta, sem verificador de atualização. Confira com `nettop -p WinBar`.
- Os dados ficam só em `~/Library/Preferences/io.github.alsppg.winbar.plist`, `~/Library/Application Support/WinBar/pins.json` (modo 600) e `~/Library/Logs/WinBar/winbar.log` (rotação em 1 MB; nunca contém títulos de janela nem caminhos pessoais).

## Desinstalar

Uma linha remove tudo que o WinBar criou — app, agente de início com o sistema, ajustes, apps fixados, logs, caches, o certificado local "WinBar Dev" e as permissões de Acessibilidade / Gravação de Tela:

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --uninstall
```

Acrescente `--restore-dock` para também devolver o Dock do macOS à borda inferior e reativar o Canto Ativo inferior direito (desfaz o `--dock-left`):

```bash
curl -fsSL https://raw.githubusercontent.com/alsppg/WinBar/main/install.sh | bash -s -- --uninstall --restore-dock
```

Equivalente manual, se preferir ver cada passo:

```bash
launchctl bootout gui/$(id -u)/io.github.alsppg.winbar; rm -f ~/Library/LaunchAgents/io.github.alsppg.winbar.plist
pkill -x WinBar
rm -rf /Applications/WinBar.app ~/Library/Application\ Support/WinBar ~/Library/Logs/WinBar ~/Library/Caches/io.github.alsppg.winbar
defaults delete io.github.alsppg.winbar
tccutil reset Accessibility io.github.alsppg.winbar && tccutil reset ScreenCapture io.github.alsppg.winbar
```

Se o WinBar ainda aparecer em *Ajustes do Sistema › Geral › Itens de Início*, desligue ali. Compilou do fonte? Apague também a pasta clonada (`./scripts/make-cert.sh --remove` apaga a identidade "WinBar Dev" se você não usar a linha única).

## Limitações conhecidas

- O macOS não permite que apps de terceiros reservem área de tela; o WinBar redimensiona as janelas que o invadem (pode desligar: *Manter janelas acima da barra*). As janelas terminam 6 pt por baixo da barra para a alça de redimensionar nunca aparecer sobre ela.
- A troca de Mesa usa os atalhos do sistema: se *Alternar para a Mesa N* (Control+N) estiver ativado em *Ajustes do Sistema › Teclado › Atalhos › Mission Control* o pulo é direto; senão o WinBar anda com Control+←/→.
- *Mostrar área de trabalho* depende do atalho do sistema *Mission Control › Mostrar Mesa* (padrão F11). Se você o desativou, o WinBar recorre a ocultar todos os apps.
- A interface está em português (pt‑BR). Interface em inglês está no [roadmap](CHANGELOG.md).

## Contribuindo

Issues e pull requests são bem‑vindos — veja [CONTRIBUTING.md](CONTRIBUTING.md). A referência de comportamento é sempre a Barra de Tarefas do Windows 10. Leia o [Código de Conduta](CODE_OF_CONDUCT.md) e a [política de segurança](SECURITY.md).

## Licença

[MIT](LICENSE) © 2026 Alessandro (alsppg). O WinBar é um projeto independente, sem vínculo com Microsoft ou Apple; "Windows" e "macOS" são marcas de seus respectivos donos.
