import SwiftUI
import AppKit

@main
struct TermiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AppStore()
    var body: some Scene {
        Window("Termi", id: "main") {
            ContentView(store: store).preferredColorScheme(.dark)
                .onAppear { delegate.store = store; NSApp.activate(ignoringOtherApps: true) }
        }.windowStyle(.hiddenTitleBar).defaultSize(width: 1220, height: 780)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New Terminal Tab") { store.newTerminal() }.keyboardShortcut("t")
                    Button("New Browser Tab") { store.newBrowser() }.keyboardShortcut("b", modifiers: [.command, .shift])
                    Button("Open Project Folder…") { store.chooseFolder() }.keyboardShortcut("o")
                    Button("Reopen Closed Tab") { store.reopen() }.keyboardShortcut("t", modifiers: [.command, .shift])
                }
                CommandGroup(replacing: .saveItem) { Button("Save Scrollback…") { store.exportScrollback() }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(store.selected?.kind != .terminal) }
                CommandGroup(replacing: .appSettings) { Button("Settings…") { store.settingsVisible = true }.keyboardShortcut(",") }
                CommandGroup(replacing: .textEditing) {
                    Button("Find in Terminal…") { store.selected?.session?.find() }.keyboardShortcut("f").disabled(store.selected?.kind != .terminal)
                }
                CommandGroup(before: .windowArrangement) {
                    Button("Close Tab") { if let tab = store.selected { store.close(tab) } }.keyboardShortcut("w")
                    Button("Next Tab") { store.cycle(1) }.keyboardShortcut("]", modifiers: [.command, .shift])
                    Button("Previous Tab") { store.cycle(-1) }.keyboardShortcut("[", modifiers: [.command, .shift])
                    Divider()
                }
                CommandMenu("Terminal") {
                    Button("Split Pane") { store.split() }.keyboardShortcut("d").disabled(store.selected?.kind != .terminal)
                    Button("Clear Terminal") { store.selected?.session?.clear() }.keyboardShortcut("k").disabled(store.selected?.kind != .terminal)
                    Button("Rename Tab…") { if let tab = store.selected { store.rename(tab) } }.keyboardShortcut("r", modifiers: [.command, .shift])
                    Divider()
                    Button("Increase Text Size") { store.setFont(store.fontSize + 1) }.keyboardShortcut("+")
                    Button("Decrease Text Size") { store.setFont(store.fontSize - 1) }.keyboardShortcut("-")
                    Button("Reset Text Size") { store.setFont(14) }.keyboardShortcut("0")
                    Divider()
                    Button("Toggle Sidebar") { store.sidebarVisible.toggle() }.keyboardShortcut("b")
                    Button("Jump to Anything…") { store.paletteVisible.toggle() }.keyboardShortcut("p", modifiers: [.command, .shift])
                }
                CommandMenu("Tabs") {
                    ForEach(Array(store.tabs.prefix(9).enumerated()), id: \.element.id) { index, tab in
                        Button(tab.title) { store.select(tab) }.keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                    }
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: AppStore?
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular) }
    func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let store, store.tabs.contains(where: { $0.sessions.contains(where: \.hasForegroundJob) }), !store.confirmClose() { return .terminateCancel }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
