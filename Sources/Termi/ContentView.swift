import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ZStack {
            DesktopMaterial()
            Color(hex: 0x34312c).opacity(0.28)
            HStack(spacing: 0) {
                if store.sidebarVisible {
                    Sidebar(store: store).frame(width: 250)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                terminalSurface
            }
            if store.paletteVisible { CommandPalette(store: store).zIndex(10) }
            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast).font(.system(size: 12)).padding(.horizontal, 18).padding(.vertical, 11)
                        .nativeGlass(in: Capsule()).padding(.bottom, 24)
                }.allowsHitTesting(false)
            }
        }.foregroundStyle(Palette.text).font(.system(size: 14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 0.7).allowsHitTesting(false))
            .frame(minWidth: 700, minHeight: 440).ignoresSafeArea()
            .background(WindowConfigurator())
            .sheet(isPresented: $store.settingsVisible) { SettingsPanel(store: store) }
            .sheet(item: $store.iconPickerTab) { tab in IconPicker(store: store, tab: tab) }
            .onExitCommand { store.paletteVisible = false }
    }

    private var terminalSurface: some View {
        VStack(spacing: 0) {
            if !store.sidebarVisible {
                TopTabBar(store: store)
            }
            TabDeck(store: store)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black.opacity(0.25), lineWidth: 0.5).allowsHitTesting(false))
        }.padding(.top, store.sidebarVisible ? 7 : 0).padding(.trailing, 7).padding(.bottom, 7)
    }
}

struct Sidebar: View {
    @ObservedObject var store: AppStore
    @Namespace private var selection
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                NativeWindowControls().frame(width: 72, height: 58)
                Spacer(minLength: 12)
                GlassCircleButton(icon: "plus", help: "New terminal  ⌘T") { store.newTerminal() }
                    .contextMenu {
                        Button("New terminal", systemImage: "terminal") { store.newTerminal() }
                        Button("New browser tab", systemImage: "globe") { store.newBrowser() }
                        Button("Open folder…", systemImage: "folder") { store.chooseFolder() }
                    }
                GlassCircleButton(icon: "sidebar.left", help: "Hide sidebar  ⌘B") {
                    withAnimation(.smooth(duration: 0.22)) { store.sidebarVisible = false }
                }
            }.padding(.leading, 20).padding(.trailing, 10).frame(height: 64)
                .background(WindowDragArea())
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(store.visibleTabs) { tab in
                            SidebarRow(store: store, tab: tab, selection: selection).id(tab.id)
                                .transition(TabMotion.tabTransition(horizontal: false))
                        }
                    }.padding(.horizontal, 12).padding(.top, 3).padding(.bottom, 18)
                        .animation(TabMotion.layout, value: store.tabs.map(\.id))
                        .animation(TabMotion.selection, value: store.selectedID)
                }.scrollIndicators(.hidden)
                    .onChange(of: store.selectedID) { _, id in
                        if let id { withAnimation(TabMotion.scroll) { proxy.scrollTo(id, anchor: .center) } }
                    }
            }
        }.frame(maxHeight: .infinity)
            .contextMenu {
                Button("New terminal") { store.newTerminal() }
                Button("New browser tab") { store.newBrowser() }
                Button("Open folder…") { store.chooseFolder() }
                Divider()
                Button("Jump to tab…") { store.paletteVisible = true }
                Button("Settings…") { store.settingsVisible = true }
            }
    }
}

struct SidebarRow: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    let selection: Namespace.ID
    @State private var hovered = false
    var selected: Bool { store.selectedID == tab.id }
    var body: some View {
        HStack(spacing: 3) {
            Button { store.select(tab) } label: {
                HStack(spacing: 12) {
                    SessionBadge(tab: tab, selected: selected)
                        .modifier(ReorderableTab(store: store, tab: tab)).help("Drag icon to reorder")
                    Text(tab.title).font(.system(size: 15, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Palette.text : Palette.muted).lineLimit(1)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity).frame(height: 40).contentShape(Rectangle())
            }.buttonStyle(.plain)
            TabCloseButton(title: tab.title) { store.close(tab) }
        }.padding(.leading, 8).padding(.trailing, 6).frame(height: 40)
            .compositingGroup()
            .background {
                if selected {
                    TabGlassBackground().clipShape(Capsule()).allowsHitTesting(false)
                        .tabSelectionGeometry(in: selection)
                } else if hovered { Capsule().fill(.white.opacity(0.04)) }
            }
            .contentShape(Capsule())
            .onHover { hovered = $0 }
            .contextMenu { TabContextMenu(store: store, tab: tab) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(tab.title), \(selected ? "selected tab" : "tab")")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.select(tab) }
    }
}

struct SessionBadge: View {
    @ObservedObject var tab: Tab
    var selected: Bool
    private var isProject: Bool { tab.kind == .terminal && tab.directory != NSHomeDirectory() }
    var body: some View {
        TabIconView(appearance: tab.appearance, fallback: tab.kind == .browser ? .globe : isProject ? .folder : .terminal, selected: selected)
    }
}

struct TopTabBar: View {
    @ObservedObject var store: AppStore
    @Namespace private var selection
    var body: some View {
        HStack(spacing: 10) {
            NativeWindowControls().frame(width: 72, height: 52)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.tabs) { tab in
                            TopTab(store: store, tab: tab, selection: selection).id(tab.id)
                                .transition(TabMotion.tabTransition(horizontal: true))
                        }
                    }.padding(.horizontal, 3).padding(.vertical, 7)
                        .animation(TabMotion.layout, value: store.tabs.map(\.id))
                        .animation(TabMotion.selection, value: store.selectedID)
                }.onChange(of: store.selectedID) { _, id in
                    if let id { withAnimation(TabMotion.scroll) { proxy.scrollTo(id, anchor: .center) } }
                }.onAppear { if let id = store.selectedID { proxy.scrollTo(id, anchor: .center) } }
            }
            GlassCircleButton(icon: "plus", help: "New terminal  ⌘T", size: 34) { store.newTerminal() }
                .contextMenu {
                    Button("New terminal") { store.newTerminal() }
                    Button("New browser tab") { store.newBrowser() }
                    Button("Open folder…") { store.chooseFolder() }
                }
            GlassCircleButton(icon: "sidebar.left", help: "Show sidebar  ⌘B", size: 34) {
                withAnimation(.smooth(duration: 0.22)) { store.sidebarVisible = true }
            }
        }.padding(.leading, 20).padding(.trailing, 10).frame(height: 58)
            .background(WindowDragArea()).accessibilityIdentifier("top-tab-bar")
    }
}

struct TopTab: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    let selection: Namespace.ID
    @State private var hovered = false
    private var selected: Bool { store.selectedID == tab.id }
    var body: some View {
        HStack(spacing: 3) {
            Button { store.select(tab) } label: {
                HStack(spacing: 9) {
                    TabIconView(appearance: tab.appearance, fallback: tab.kind == .browser ? .globe : tab.directory == NSHomeDirectory() ? .terminal : .folder, selected: selected, size: 23)
                        .modifier(ReorderableTab(store: store, tab: tab)).help("Drag icon to reorder")
                    Text(tab.title).font(.system(size: 12, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Palette.text : Palette.muted).lineLimit(1)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity).frame(height: 36).contentShape(Rectangle())
            }.buttonStyle(.plain)
            TabCloseButton(title: tab.title) { store.close(tab) }
        }.padding(.leading, 8).padding(.trailing, 4).frame(width: 166, height: 36)
            .compositingGroup()
            .background {
                if selected {
                    TabGlassBackground().clipShape(Capsule()).allowsHitTesting(false)
                        .tabSelectionGeometry(in: selection)
                }
                else if hovered { Capsule().fill(.white.opacity(0.04)) }
            }
            .contentShape(Capsule())
            .onHover { hovered = $0 }
            .contextMenu { TabContextMenu(store: store, tab: tab) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(tab.title), \(selected ? "selected tab" : "tab")")
            .accessibilityIdentifier("top-tab-\(tab.id)")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.select(tab) }
    }
}

struct TabCloseButton: View {
    let title: String
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovered ? Color.white : Palette.text)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white.opacity(hovered ? 0.18 : 0.075)))
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 }
            .help("Close \(title)").accessibilityLabel("Close \(title)")
    }
}

struct ReorderableTab: ViewModifier {
    @ObservedObject var store: AppStore
    let tab: Tab
    func body(content: Content) -> some View {
        content.onDrag { NSItemProvider(object: tab.id.uuidString as NSString) }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: String.self) { value, _ in
                    if let value { Task { @MainActor in store.move(value, before: tab) } }
                }
                return true
            }
    }
}

struct TabContextMenu: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    var body: some View {
        Button("Change icon…", systemImage: "photo.circle") { store.iconPickerTab = tab }
        Button("Rename…") { store.rename(tab) }
        Button(tab.pinned ? "Unpin tab" : "Pin tab") { store.togglePin(tab) }
        Button("Duplicate") { store.duplicate(tab) }
        if tab.kind == .terminal {
            Divider()
            Button("Split terminal") { store.select(tab); store.split() }
            Button("Find…") { store.select(tab); tab.session?.find() }
            Button("Save scrollback…") { store.select(tab); store.exportScrollback() }
            Button("Reveal in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tab.directory) }
        }
        Divider()
        Button("Close tab") { store.close(tab) }
    }
}

/// Reparent NSWindow's real buttons, preserving native traffic-light behavior.
struct NativeWindowControls: NSViewRepresentable {
    final class Host: NSView {
        private var buttons: [NSButton] = []
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
            for button in buttons { addSubview(button) }
            needsLayout = true
        }
        override func layout() {
            super.layout()
            for (index, button) in buttons.enumerated() {
                button.setFrameOrigin(NSPoint(x: CGFloat(index) * 24, y: (bounds.height - button.frame.height) / 2))
            }
        }
    }
    func makeNSView(context: Context) -> Host { Host() }
    func updateNSView(_ view: Host, context: Context) {}
}

struct WindowConfigurator: NSViewRepresentable {
    final class Host: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovableByWindowBackground = false
            window.setFrameAutosaveName("TermiMainWindow")
        }
    }
    func makeNSView(context: Context) -> NSView { Host() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) }
            else { window?.performDrag(with: event) }
        }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
