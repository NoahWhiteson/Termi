import SwiftUI

struct PaletteAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let shortcut: String
    let run: () -> Void
}

struct CommandPalette: View {
    @ObservedObject var store: AppStore
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool
    var actions: [PaletteAction] {
        var result = [
            PaletteAction(id: "terminal", title: "New terminal tab", icon: "terminal", shortcut: "⌘T") { store.newTerminal() },
            PaletteAction(id: "browser", title: "New browser tab", icon: "globe", shortcut: "⌘⇧B") { store.newBrowser() },
            PaletteAction(id: "folder", title: "Open project folder…", icon: "folder", shortcut: "⌘O") { store.chooseFolder() },
            PaletteAction(id: "split", title: "Split terminal", icon: "rectangle.split.2x1", shortcut: "⌘D") { store.split() },
            PaletteAction(id: "search", title: "Find in terminal", icon: "magnifyingglass", shortcut: "⌘F") { store.selected?.session?.find() },
            PaletteAction(id: "clear", title: "Clear terminal", icon: "sparkles", shortcut: "⌘K") { store.selected?.session?.clear() },
            PaletteAction(id: "reopen", title: "Reopen closed tab", icon: "arrow.uturn.backward", shortcut: "⌘⇧T") { store.reopen() },
            PaletteAction(id: "sidebar", title: "Toggle sidebar", icon: "sidebar.left", shortcut: "⌘B") { store.sidebarVisible.toggle() },
            PaletteAction(id: "settings", title: "Settings", icon: "gearshape", shortcut: "⌘,") { store.settingsVisible = true }
        ]
        result += store.tabs.map { tab in
            PaletteAction(id: tab.id.uuidString, title: "Go to \(tab.title)", icon: tab.icon, shortcut: "TAB") { store.select(tab) }
        }
        return query.isEmpty ? result : result.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.48).contentShape(Rectangle()).onTapGesture { store.paletteVisible = false }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.accent)
                    TextField("Where would you like to go?", text: $query).textFieldStyle(.plain).font(.system(size: 15)).focused($focused).onSubmit { execute() }
                    Shortcut(label: "esc")
                }.padding(20)
                Rectangle().fill(Palette.line).frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 3) {
                            if actions.isEmpty { Text("No matching tabs or commands.").foregroundStyle(Palette.muted).padding(30) }
                            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                                Button { selection = index; execute() } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: action.icon).font(.system(size: 13)).foregroundStyle(index == selection ? Palette.accent : Palette.muted).frame(width: 21)
                                        Text(action.title).font(.system(size: 13))
                                        Spacer()
                                        Shortcut(label: action.shortcut)
                                    }.padding(.horizontal, 14).frame(height: 42)
                                        .background(index == selection ? Palette.selected : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
                                }.buttonStyle(.plain).id(index)
                            }
                        }.padding(8)
                    }.frame(maxHeight: 340).onChange(of: selection) { _, value in proxy.scrollTo(value) }
                }
                HStack { Text("Commands & tabs"); Spacer(); Text("↑ ↓ to navigate   ↵ to open") }.font(.system(size: 10)).foregroundStyle(Palette.dim).padding(14).overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }.frame(width: 510).background(Palette.sidebar, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12))).shadow(color: .black.opacity(0.35), radius: 40, y: 20).padding(.top, 100)
        }.onAppear { focused = true }
            .onChange(of: query) { _, _ in selection = 0 }
            .onKeyPress(.downArrow) { if !actions.isEmpty { selection = min(selection + 1, actions.count - 1) }; return .handled }
            .onKeyPress(.upArrow) { selection = max(0, selection - 1); return .handled }
    }
    func execute() {
        guard actions.indices.contains(selection) else { return }
        let action = actions[selection]
        store.paletteVisible = false
        DispatchQueue.main.async { action.run() }
    }
}

struct SettingsPanel: View {
    @ObservedObject var store: AppStore
    @AppStorage("minimalPrompt") private var minimalPrompt = true
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings").font(.system(size: 24, weight: .medium)).tracking(-0.5)
                    Text("Terminal appearance").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
                IconButton(icon: "xmark", help: "Close settings") { store.settingsVisible = false }
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 14) {
                Text("TERMINAL").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.dim)
                HStack { Text("Text size"); Spacer(); Text("\(Int(store.fontSize)) pt").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.accent) }
                Slider(value: Binding(get: { store.fontSize }, set: { store.setFont($0) }), in: 10...24, step: 1).tint(Palette.accent)
                Text("The quick brown fox jumps over the lazy dog.").font(.system(size: store.fontSize, design: .monospaced)).foregroundStyle(Palette.muted).frame(height: 52).frame(maxWidth: .infinity).background(Palette.background, in: RoundedRectangle(cornerRadius: 7)).clipped()
                Toggle("Use Termi’s minimal prompt", isOn: $minimalPrompt).toggleStyle(.switch).tint(Palette.accent)
                Text("Applies to new zsh sessions. Turn off to keep your own prompt. Your existing shell configuration is always loaded.").font(.system(size: 11)).foregroundStyle(Palette.dim).lineSpacing(3)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                Text("A FEW SHORTCUTS").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.dim)
                HStack { Text("New terminal"); Spacer(); Shortcut(label: "⌘T") }
                HStack { Text("Split pane"); Spacer(); Shortcut(label: "⌘D") }
                HStack { Text("Jump to anything"); Spacer(); Shortcut(label: "⌘⇧P") }
                HStack { Text("Next / previous tab"); Spacer(); Shortcut(label: "⌘⇧] / ⌘⇧[") }
            }.font(.system(size: 12)).foregroundStyle(Palette.muted)
            HStack { Text("TERMI  1.0").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(Palette.dim); Spacer(); Button("Done") { store.settingsVisible = false }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Palette.selected) }
        }.padding(30).frame(width: 490).background(Palette.sidebar).foregroundStyle(Palette.text).preferredColorScheme(.dark)
    }
}
