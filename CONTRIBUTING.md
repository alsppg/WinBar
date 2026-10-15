# Contributing to WinBar / Contribuindo com o WinBar

Thanks for helping! / Obrigado por ajudar! Issues and pull requests in English or Portuguese are both welcome.

## Ground rules / Regras básicas

- **Reference behaviour is the Windows 10 taskbar.** When in doubt about how something should work, do what Windows 10 does; macOS conventions come second.
- **Local only.** WinBar makes no network calls, collects nothing and stores nothing outside `~/Library`. PRs that add telemetry, update checkers or remote calls will not be merged.
- **No dependencies.** Plain Swift + AppKit/SwiftUI, compiled with `swiftc`. Keep it that way unless there is a very strong reason.
- **Clean room.** Do not copy code, assets, icons or text from other taskbar/dock products. Only public Apple APIs, plus the very few private symbols already isolated behind `dlsym` with public fallbacks.
- **Security by default.** Minimum permissions, files with mode 600 for user data, no secrets in the repo, no personal data in logs.

## Development / Desenvolvimento

```bash
git clone https://github.com/alsppg/WinBar.git && cd WinBar
./scripts/make-cert.sh                 # once
./scripts/make-app.sh debug            # or release
./scripts/install-from-source.sh       # installs to /Applications and launches
tail -f ~/Library/Logs/WinBar/winbar.log
```

Layout: `Sources/WinBar/{App,Bar,Flyouts,Start,Tray,System,Theme}`. All colours and sizes live in `Theme/Win10Theme.swift` and `App/SettingsStore.swift` (`BarSize`); never hard-code them in views.

## Pull requests

1. Open an issue first for anything beyond a small fix, so we agree on the behaviour.
2. One topic per PR; keep the diff focused.
3. Fill in the PR template (build passes, tested macOS version, no network, docs updated in **both** READMEs when user-visible).
4. Commit messages in English, imperative mood: `Add Spaces switcher scroll support`.

## Reporting bugs / Relatando bugs

Use the bug template. Please include the macOS version and, if possible, the relevant lines of `~/Library/Logs/WinBar/winbar.log` (it never contains window titles or personal paths).
