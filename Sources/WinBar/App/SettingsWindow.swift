import SwiftUI
import AppKit
import ServiceManagement

/// Janela de Ajustes (SwiftUI nativo). Sem registro, licença, conta ou atualizador.
struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @State private var axOK = PermissionGate.accessibility
    @State private var srOK = PermissionGate.screenRecording
    @State private var newExcluded = ""
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            barTab.tabItem { Label("Barra", systemImage: "rectangle.bottomthird.inset.filled") }
            buttonsTab.tabItem { Label("Botões", systemImage: "square.grid.3x1.below.line.grid.1x2") }
            generalTab.tabItem { Label("Geral", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 440)
        .onReceive(timer) { _ in axOK = PermissionGate.accessibility; srOK = PermissionGate.screenRecording }
    }

    private var barTab: some View {
        Form {
            Section("Aparência") {
                Toggle("Usar a cor de destaque na barra", isOn: $store.settings.useAccentColor)
                Toggle("Transparência", isOn: $store.settings.transparency)
                Picker("Altura da barra", selection: $store.settings.barSize) {
                    ForEach(BarSize.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Comportamento") {
                Toggle("Ocultar automaticamente a barra", isOn: $store.settings.autoHide)
                Toggle("Manter janelas acima da barra (encurta/sobe janelas que invadem a barra)", isOn: $store.settings.keepWindowsAboveBar)
                Button("Ajustar janelas à barra agora") { WindowHerder.shared.herdAll(expandFullHeight: true) }
                Toggle("Mostrar em todas as telas", isOn: $store.settings.allScreens)
            }
            Section("Bandeja") {
                Toggle("Mostrar relógio", isOn: $store.settings.showClock)
                Toggle("Mostrar botão de Mesas (áreas de trabalho)", isOn: $store.settings.showSpaces)
                Toggle("Mostrar botão \"Mostrar área de trabalho\"", isOn: $store.settings.showDesktopButton)
            }
        }
        .formStyle(.grouped)
    }

    private var buttonsTab: some View {
        Form {
            Section("Combinar botões") {
                Picker("Modo", selection: $store.settings.combineButtons) {
                    ForEach(CombineMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Toggle("Mostrar rótulos (nome do app) nos botões combinados", isOn: $store.settings.showLabels)
                    .disabled(store.settings.combineButtons == .never)
            }
            Section("Cliques") {
                Toggle("Clicar no app ativo minimiza a janela", isOn: $store.settings.clickActiveMinimizes)
                Toggle("Encerrar o app ao fechar sua última janela pela barra (como no Windows)", isOn: $store.settings.quitOnLastWindowClose)
                Stepper("Atraso da miniatura ao passar o mouse: \(store.settings.previewDelayMs) ms",
                        value: $store.settings.previewDelayMs, in: 100...2000, step: 100)
            }
            Section("Apps") {
                Toggle("Ocultar apps em execução sem janelas (exceto fixados)", isOn: $store.settings.excludeNoWindowApps)
                HStack {
                    TextField("Bundle ID a excluir (ex.: com.apple.Music)", text: $newExcluded)
                    Button("Excluir") {
                        let v = newExcluded.trimmingCharacters(in: .whitespaces)
                        if !v.isEmpty, !store.settings.excludedBundleIDs.contains(v) { store.settings.excludedBundleIDs.append(v) }
                        newExcluded = ""
                    }
                }
                ForEach(store.settings.excludedBundleIDs, id: \.self) { bid in
                    HStack { Text(bid); Spacer(); Button("Remover") { store.settings.excludedBundleIDs.removeAll { $0 == bid } } }
                }
                Button("Restaurar ordem automática dos botões") { store.settings.manualOrder = [] }
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section("Inicialização") {
                Toggle("Abrir o WinBar ao iniciar a sessão", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { on in store.settings.launchAtLogin = on; LoginItem.set(enabled: on) }))
            }
            Section("Atalhos") {
                Text("Iniciar: Control + Esc   ·   Ativar botão N: Control + Option + 1…9")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Permissões") {
                permissionRow("Acessibilidade", ok: axOK, detail: "Listar, ativar, minimizar e fechar janelas.") { PermissionGate.openAccessibilitySettings() }
                permissionRow("Gravação de Tela", ok: srOK, detail: "Miniaturas das janelas. Sem ela, o card mostra só o título.") { PermissionGate.openScreenRecordingSettings() }
                Button("Relançar o WinBar") { PermissionGate.relaunch() }
            }
            Section("Sobre") {
                Text("WinBar \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") — barra de tarefas para macOS, 100 % local, sem rede.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(_ title: String, ok: Bool, detail: String, open: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(title); Text(ok ? "Concedida" : "Pendente").font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(ok ? Color.green.opacity(0.25) : Color.orange.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 4)) }
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !ok { Button("Abrir Ajustes do Sistema", action: open) }
        }
    }
}

enum LoginItem {
    static func set(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { Log.warn("login item: \(error.localizedDescription)") }
    }
}

/// Primeira execução: pede as duas permissões e explica o que cada uma faz.
struct OnboardingView: View {
    @State private var axOK = PermissionGate.accessibility
    @State private var srOK = PermissionGate.screenRecording
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bem-vindo ao WinBar").font(.title2).bold()
            Text("Para funcionar como barra de tarefas, o WinBar precisa de duas permissões do macOS. Nada sai do seu Mac.")
                .foregroundStyle(.secondary)
            row("1. Acessibilidade (obrigatória)", ok: axOK,
                detail: "Permite listar, ativar, minimizar e fechar as janelas dos outros apps.") {
                PermissionGate.requestAccessibility(); PermissionGate.openAccessibilitySettings()
            }
            row("2. Gravação de Tela (recomendada)", ok: srOK,
                detail: "Permite mostrar miniaturas ao vivo das janelas. Sem ela, só o título aparece.") {
                PermissionGate.requestScreenRecording(); PermissionGate.openScreenRecordingSettings()
            }
            Text("Dica: mova o Dock para a esquerda ou direita e ative \"Ocultar e mostrar o Dock automaticamente\" para a barra ficar livre na parte de baixo.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Relançar agora") { PermissionGate.relaunch() }
                Button(axOK ? "Concluir" : "Continuar sem Acessibilidade") { onDone() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onReceive(timer) { _ in axOK = PermissionGate.accessibility; srOK = PermissionGate.screenRecording }
    }

    private func row(_ title: String, ok: Bool, detail: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle").foregroundStyle(ok ? Color.green : Color.orange).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).bold()
                Text(detail).font(.callout).foregroundStyle(.secondary)
                if !ok { Button("Conceder…", action: action) }
            }
        }
    }
}
