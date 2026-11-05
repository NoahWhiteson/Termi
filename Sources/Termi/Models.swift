import SwiftUI
import AppKit
import WebKit
import SwiftTerm
import Darwin

enum TabKind: String, Codable { case terminal, browser }

enum TermiResources {
    static var bundle: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Termi_Termi.bundle"), let packaged = Bundle(url: url) { return packaged }
        return Bundle.module
    }
}

struct SavedTab: Codable {
    var title: String
    var kind: TabKind
    var directory: String
    var url: String?
    var pinned: Bool
    var appearance: TabAppearance? = nil
}

enum AddressResolver {
    static func resolve(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil { return url }
        if value.contains("://") { return nil }
        if value.contains(" ") || (!value.contains(".") && !value.hasPrefix("localhost")) {
            var components = URLComponents(string: "https://www.google.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: value)]
            return components.url
        }
        return URL(string: (value.hasPrefix("localhost") || value.hasPrefix("127.0.0.1") || value.hasPrefix("[::1]") ? "http://" : "https://") + value)
    }
}

@MainActor
final class TerminalSession: NSObject, ObservableObject, Identifiable, @preconcurrency LocalProcessTerminalViewDelegate {
    let id = UUID()
    let view: LocalProcessTerminalView
    @Published var directory: String
    @Published var isRunning = false
    @Published var exitCode: Int32?
    @Published var columns = 80
    @Published var rows = 24
    var onChange: (() -> Void)?
    var started = false
    private(set) var isClosed = false

    init(directory: String) {
        self.directory = directory
        view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        super.init()
        view.processDelegate = self
        view.nativeBackgroundColor = Palette.terminal
        view.nativeForegroundColor = NSColor(hex: 0xd6d5cf)
        view.caretColor = NSColor(hex: 0xc2c1ba)
        view.selectedTextBackgroundColor = NSColor(hex: 0x494840)
        view.font = .monospacedSystemFont(ofSize: UserDefaults.standard.double(forKey: "fontSize").nonZero ?? 14, weight: .regular)
        view.optionAsMetaKey = true
    }

    func start(shell overrideShell: String? = nil, environmentOverrides: [String: String] = [:]) {
        guard !started, !isClosed else { return }
        started = true
        var environment = ProcessInfo.processInfo.environment.merging(environmentOverrides) { _, override in override }
        // Do not pass the hosting agent's process-specific environment into a new login shell.
        for key in ["TERM_SESSION_ID", "TERM_PROGRAM_VERSION", "XPC_SERVICE_NAME", "XPC_FLAGS"] { environment.removeValue(forKey: key) }
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = "Termi"
        environment["TERM_PROGRAM_VERSION"] = "1.0.0"
        let shell = (overrideShell ?? environment["SHELL"]).flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil } ?? "/bin/zsh"
        if shell.hasSuffix("/zsh"), let resources = TermiResources.bundle.resourceURL {
            let integration = resources.appendingPathComponent("Shell").path
            environment["TERMI_ORIGINAL_ZDOTDIR"] = environment["ZDOTDIR"] ?? NSHomeDirectory()
            environment["TERMI_INTEGRATION_DIR"] = integration
            environment["ZDOTDIR"] = integration
            environment["TERMI_WELCOME"] = "1"
            environment["TERMI_MINIMAL_PROMPT"] = UserDefaults.standard.object(forKey: "minimalPrompt") as? Bool == false ? "0" : "1"
        }
        let path = FileManager.default.fileExists(atPath: directory) ? directory : NSHomeDirectory()
        isRunning = true
        view.startProcess(executable: shell, args: ["-l"], environment: environment.map { "\($0.key)=\($0.value)" }, currentDirectory: path)
        if view.process.shellPid == 0 { isRunning = false; view.feed(text: "\r\nCould not start \(shell). Open a new terminal to try again.\r\n") }
    }

    func focus() { view.window?.makeFirstResponder(view) }
    var hasForegroundJob: Bool {
        guard started, isRunning, view.process.childfd >= 0 else { return false }
        let group = tcgetpgrp(view.process.childfd)
        return group > 0 && group != view.process.shellPid
    }
    func stop() {
        isClosed = true
        if started && isRunning {
            let group = tcgetpgrp(view.process.childfd)
            if group > 0 && group != view.process.shellPid { kill(-group, SIGHUP) }
            if view.process.shellPid > 0 { kill(view.process.shellPid, SIGHUP) }
            view.terminate(); isRunning = false
        }
    }
    func clear() { view.feed(text: "\u{1b}[2J\u{1b}[3J\u{1b}[H"); view.send(txt: "\u{0c}") }
    func find() {
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        view.performTextFinderAction(item)
    }
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) { columns = newCols; rows = newRows }
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = URL(string: directory), url.isFileURL else { return }
        self.directory = url.path
        onChange?()
    }
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !isClosed else { return }
        isRunning = false; self.exitCode = exitCode
        view.feed(text: "\r\n\u{1b}[38;2;147;157;148mSession ended. Press ⌘T to start fresh.\u{1b}[0m\r\n")
        onChange?()
    }
}

extension Double { var nonZero: Double? { self > 0 ? self : nil } }

@MainActor
final class Tab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String
    let kind: TabKind
    @Published var pinned: Bool
    @Published var sessions: [TerminalSession] = []
    @Published var focusedPane = 0
    @Published var address = ""
    @Published var pageTitle = "New tab"
    @Published var isLoading = false
    @Published var browserError: String?
    @Published var appearance: TabAppearance
    var webView: WKWebView?
    var browserDelegate: BrowserDelegate?
    var onChange: (() -> Void)?

    init(title: String, kind: TabKind = .terminal, directory: String = NSHomeDirectory(), pinned: Bool = false, url: String? = nil, appearance: TabAppearance = TabAppearance()) {
        self.title = title; self.kind = kind; self.pinned = pinned
        self.appearance = appearance
        if kind == .terminal { sessions = [TerminalSession(directory: directory)] }
        else { address = url ?? "" }
    }
    var session: TerminalSession? { sessions.indices.contains(focusedPane) ? sessions[focusedPane] : sessions.first }
    var directory: String { session?.directory ?? NSHomeDirectory() }
    var icon: String { kind == .browser ? "globe" : (sessions.count > 1 ? "rectangle.split.2x1" : "terminal") }
    var saved: SavedTab { SavedTab(title: title, kind: kind, directory: directory, url: webView?.url?.absoluteString ?? (address.isEmpty ? nil : address), pinned: pinned, appearance: appearance) }
    func stop() { sessions.forEach { $0.stop() }; webView?.stopLoading() }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selectedID: UUID?
    @Published var sidebarVisible = true
    @Published var paletteVisible = false
    @Published var settingsVisible = false
    @Published var iconPickerTab: Tab?
    @Published var fontSize: Double = 14
    @Published var filter = ""
    @Published var toast: String?
    private var closedTabs: [SavedTab] = []
    private var toastTask: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, restore: Bool = true) {
        self.defaults = defaults
        fontSize = defaults.double(forKey: "fontSize").nonZero ?? 14
        if restore, let data = defaults.data(forKey: "workspace"), let saved = try? JSONDecoder().decode([SavedTab].self, from: data), !saved.isEmpty {
            for item in saved { append(Tab(title: item.title, kind: item.kind, directory: item.directory, pinned: item.pinned, url: item.url, appearance: item.appearance ?? TabAppearance())) }
            let index = min(max(0, defaults.integer(forKey: "selectedIndex")), tabs.count - 1)
            selectedID = tabs[index].id
        } else { append(Tab(title: "Home", pinned: true)); selectedID = tabs.first?.id }
    }
    var selected: Tab? { tabs.first { $0.id == selectedID } }
    var visibleTabs: [Tab] { filter.isEmpty ? tabs : tabs.filter { $0.title.localizedCaseInsensitiveContains(filter) || $0.directory.localizedCaseInsensitiveContains(filter) } }

    private func append(_ tab: Tab) {
        tab.onChange = { [weak self] in self?.save() }
        for session in tab.sessions { session.onChange = { [weak self] in self?.objectWillChange.send(); self?.save() } }
        tabs.append(tab)
    }
    func select(_ tab: Tab) {
        guard tabs.contains(where: { $0.id == tab.id }) else { return }
        selectedID = tab.id
        focusSelectedSession()
        defaults.set(tabs.firstIndex(where: { $0.id == selectedID }) ?? 0, forKey: "selectedIndex")
    }
    private func focusSelectedSession() {
        let intendedID = selectedID
        if focusSessionIfReady(intendedID) { return }
        DispatchQueue.main.async { [weak self] in
            self?.focusSessionIfReady(intendedID)
        }
    }
    @discardableResult
    private func focusSessionIfReady(_ intendedID: UUID?) -> Bool {
        guard selectedID == intendedID, !paletteVisible, !settingsVisible, iconPickerTab == nil else { return true }
        if let session = selected?.session {
            guard session.view.window != nil else { return false }
            session.focus()
        } else {
            let window = selected?.webView?.window ?? NSApp.keyWindow
                ?? tabs.lazy.flatMap(\.sessions).compactMap { $0.view.window }.first
            guard let window else { return false }
            window.makeFirstResponder(selected?.webView)
        }
        return true
    }
    func newTerminal(directory: String? = nil) {
        let dir = directory ?? selected?.directory ?? NSHomeDirectory()
        let title = dir == NSHomeDirectory() ? "Terminal" : URL(fileURLWithPath: dir).lastPathComponent
        let tab = Tab(title: title, directory: dir)
        append(tab); select(tab); save()
    }
    func newBrowser(url: String? = nil) {
        let tab = Tab(title: "Browser", kind: .browser, url: url)
        append(tab); select(tab); save()
    }
    func close(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        if tab.sessions.contains(where: \.hasForegroundJob), !confirmClose() { return }
        closedTabs.append(tab.saved)
        if closedTabs.count > 20 { closedTabs.removeFirst() }
        tab.stop(); tabs.remove(at: index)
        if selectedID == tab.id { selectedID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id }
        if tabs.isEmpty { newTerminal(directory: NSHomeDirectory()) }
        save()
        focusSelectedSession()
    }
    func reopen() {
        guard let saved = closedTabs.popLast() else { return }
        let tab = Tab(title: saved.title, kind: saved.kind, directory: saved.directory, pinned: saved.pinned, url: saved.url, appearance: saved.appearance ?? TabAppearance())
        append(tab); select(tab); save()
    }
    func duplicate(_ source: Tab) {
        let tab = Tab(title: source.title, kind: source.kind, directory: source.directory, url: source.webView?.url?.absoluteString ?? source.address, appearance: source.appearance)
        append(tab); select(tab); save()
    }
    func setIcon(_ preset: TabIcon, for tab: Tab) {
        tab.appearance = TabAppearance(preset: preset)
        save()
    }
    func setCustomIcon(_ data: Data, for tab: Tab) throws {
        let image = try IconImages.normalizedPNG(data)
        tab.appearance = TabAppearance(customImage: image)
        save()
    }
    func chooseCustomIcon(for tab: Tab) throws {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use icon"
        panel.message = "Choose an image for this tab. A copy is saved with the tab."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= IconImages.maximumFileSize else { throw IconImportError.tooLarge }
        try setCustomIcon(Data(contentsOf: url), for: tab)
    }
    func cycle(_ delta: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == selectedID }), !tabs.isEmpty else { return }
        select(tabs[(index + delta + tabs.count) % tabs.count])
    }
    func move(_ id: String, before tab: Tab) {
        guard let source = tabs.firstIndex(where: { $0.id.uuidString == id }), let target = tabs.firstIndex(where: { $0.id == tab.id }), source != target else { return }
        let moved = tabs.remove(at: source); tabs.insert(moved, at: target); save()
    }
    func togglePin(_ tab: Tab) { tab.pinned.toggle(); objectWillChange.send(); save() }
    func rename(_ tab: Tab) {
        let alert = NSAlert(); alert.messageText = "Rename tab"; alert.informativeText = "Give this space a name that makes sense to you."
        let field = NSTextField(string: tab.title); field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field; alert.addButton(withTitle: "Rename"); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
            tab.title = String(field.stringValue.prefix(80)); objectWillChange.send(); save()
        }
    }
    func split() {
        guard let tab = selected, tab.kind == .terminal else { return }
        guard tab.sessions.count < 2 else { notify("Two panes, one little space."); return }
        let session = TerminalSession(directory: tab.directory)
        session.onChange = { [weak self] in self?.objectWillChange.send(); self?.save() }
        tab.sessions.append(session); tab.focusedPane = 1
        objectWillChange.send()
    }
    func closeSplit(_ tab: Tab, index: Int) {
        guard tab.sessions.count > 1, tab.sessions.indices.contains(index) else { return }
        if tab.sessions[index].hasForegroundJob, !confirmClose() { return }
        tab.sessions[index].stop(); tab.sessions.remove(at: index); tab.focusedPane = 0
        objectWillChange.send(); tab.session?.focus()
    }
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Open terminal here"; panel.message = "A new space for your project."
        if panel.runModal() == .OK, let url = panel.url { newTerminal(directory: url.path) }
    }
    func setFont(_ value: Double) {
        fontSize = min(24, max(10, value)); defaults.set(fontSize, forKey: "fontSize")
        for tab in tabs { for session in tab.sessions { session.view.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular) } }
    }
    func exportScrollback() {
        guard let session = selected?.session else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(selected?.title ?? "Terminal").txt"; panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do { try session.view.getTerminal().getBufferAsData().write(to: url); notify("Scrollback saved.") }
            catch { notify("Couldn’t save: \(error.localizedDescription)") }
        }
    }
    func notify(_ message: String) {
        toastTask?.cancel(); toast = message
        toastTask = Task { try? await Task.sleep(for: .seconds(3)); if !Task.isCancelled { toast = nil } }
    }
    func save() {
        if let data = try? JSONEncoder().encode(tabs.map(\.saved)) { defaults.set(data, forKey: "workspace") }
        defaults.set(tabs.firstIndex(where: { $0.id == selectedID }) ?? 0, forKey: "selectedIndex")
    }
    func confirmClose() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close a running process?"
        alert.informativeText = "A command is still running in this terminal. Closing it will end the process."
        alert.addButton(withTitle: "Keep Running"); alert.addButton(withTitle: "Close Terminal")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func shutdown() { save(); tabs.forEach { $0.stop() } }
}
