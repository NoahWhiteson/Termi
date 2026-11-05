import XCTest
import AppKit
import SwiftUI
@testable import Termi

final class AddressTests: XCTestCase {
    func testLocalhostUsesHTTP() {
        XCTAssertEqual(AddressResolver.resolve("localhost:3000/test")?.absoluteString, "http://localhost:3000/test")
        XCTAssertEqual(AddressResolver.resolve("127.0.0.1:8080")?.scheme, "http")
    }
    func testWebAddressesAndSearch() {
        XCTAssertEqual(AddressResolver.resolve("example.com/docs")?.absoluteString, "https://example.com/docs")
        XCTAssertEqual(AddressResolver.resolve("https://example.com/a?q=b")?.query, "q=b")
        XCTAssertEqual(URLComponents(url: AddressResolver.resolve("swift async await")!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "swift async await")
    }
    func testRejectsUnsupportedSchemes() {
        XCTAssertNil(AddressResolver.resolve("file:///etc/passwd"))
        XCTAssertNil(AddressResolver.resolve("javascript://alert(1)"))
        XCTAssertNil(AddressResolver.resolve("  "))
    }
}

@MainActor
final class NativeLayoutTests: XCTestCase {
    func testReferenceLayoutAndNativeControls() async throws {
        _ = NSApplication.shared
        let defaults = UserDefaults(suiteName: "TermiLayoutTests-\(UUID().uuidString)")!
        let store = AppStore(defaults: defaults, restore: false)
        let first = store.selected!
        first.title = "termi"
        store.newTerminal(directory: NSHomeDirectory() + "/Developer")
        store.selected!.title = "developer"
        store.newTerminal(directory: NSHomeDirectory() + "/api")
        store.selected!.title = "api dev"
        store.newBrowser()
        for tab in store.tabs { for session in tab.sessions { session.started = true } }
        store.select(first)
        first.session!.view.feed(text: "\u{1b}[1;38;2;229;228;222mtermi\u{1b}[0m\u{1b}[38;2;105;104;98m v1.0.0 · ⌘⇧P for commands\u{1b}[0m\r\n\r\n~ ❯ ")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        let host = NSHostingView(rootView: ContentView(store: store).preferredColorScheme(.dark))
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 720)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(window.isOpaque)
        let close = try XCTUnwrap(window.standardWindowButton(.closeButton))
        XCTAssertTrue(close.superview is NativeWindowControls.Host)
        let terminalOrigin = first.session!.view.convert(NSPoint.zero, to: host)
        XCTAssertEqual(terminalOrigin.x, 267, accuracy: 2)
        XCTAssertGreaterThan(first.session!.view.frame.height, 650)
        let sidebarHeight = first.session!.view.frame.height
        let originalSession = first.session!.id
        store.sidebarVisible = false
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(250))
        host.layoutSubtreeIfNeeded()
        XCTAssertTrue(close.superview is NativeWindowControls.Host)
        XCTAssertEqual(first.session!.view.convert(NSPoint.zero, to: host).x, 17, accuracy: 2)
        XCTAssertLessThan(first.session!.view.frame.height, sidebarHeight)
        XCTAssertGreaterThan(first.session!.view.frame.height, sidebarHeight - 80)
        XCTAssertEqual(store.selectedID, first.id)
        XCTAssertEqual(first.session!.id, originalSession)
        let originalHost = first.session!.view.superview
        store.select(store.tabs[1])
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.selected?.title, "developer")
        XCTAssertTrue(first.session!.view.window === window)
        XCTAssertTrue(first.session!.view.superview === originalHost)
        store.select(first)
        XCTAssertTrue(window.firstResponder === first.session!.view)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(first.session!.id, originalSession)
        XCTAssertTrue(first.session!.view.getTerminal().getBufferAsData().count > 0)
        for _ in 0..<12 { store.select(store.tabs[1]); store.select(first) }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(window.firstResponder === first.session!.view)
        XCTAssertTrue(first.session!.view.superview === originalHost)
        let browser = store.tabs.first { $0.kind == .browser }!
        store.select(browser)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(window.firstResponder === first.session!.view)
        store.shutdown()
        window.contentView = nil
    }
}

@MainActor
final class WorkspaceTests: XCTestCase {
    var defaults: UserDefaults!
    var store: AppStore!
    override func setUp() async throws {
        _ = NSApplication.shared
        defaults = UserDefaults(suiteName: "TermiTests-\(UUID().uuidString)")!
        store = AppStore(defaults: defaults, restore: false)
    }
    func testCloseReopenAndLastTab() {
        store.newTerminal(directory: "/tmp")
        let tab = store.selected!
        tab.title = "Project"
        store.close(tab)
        XCTAssertEqual(store.tabs.count, 1)
        store.reopen()
        XCTAssertEqual(store.selected?.title, "Project")
        XCTAssertEqual(store.selected?.directory, "/tmp")
        store.close(store.selected!)
        store.close(store.selected!)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertNotNil(store.selected)
    }
    func testPersistenceAndReordering() {
        store.newBrowser(url: "https://example.com")
        let browser = store.selected!
        store.togglePin(browser)
        store.move(browser.id.uuidString, before: store.tabs[0])
        store.save()
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.tabs.count, 2)
        XCTAssertEqual(restored.tabs[0].kind, .browser)
        XCTAssertTrue(restored.tabs[0].pinned)
        XCTAssertEqual(restored.selected?.address, "https://example.com")
    }
    func testSplitLimitAndFocus() {
        store.split(); store.split()
        XCTAssertEqual(store.selected?.sessions.count, 2)
        store.closeSplit(store.selected!, index: 1)
        XCTAssertEqual(store.selected?.sessions.count, 1)
        XCTAssertEqual(store.selected?.focusedPane, 0)
    }
    func testBrandIconsPersistDuplicateAndReopen() {
        let original = store.selected!
        store.setIcon(.claude, for: original)
        store.duplicate(original)
        XCTAssertEqual(store.selected?.appearance.preset, .claude)
        store.setIcon(.docker, for: store.selected!)
        XCTAssertEqual(original.appearance.preset, .claude)
        store.close(store.selected!)
        store.reopen()
        XCTAssertEqual(store.selected?.appearance.preset, .docker)
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.tabs.map(\.appearance.preset), [.claude, .docker])
    }
    func testCustomIconPersistsAsPortablePNG() throws {
        let tab = store.selected!
        let image = try XCTUnwrap(IconImages.bundled("docker"))
        let source = try XCTUnwrap(image.tiffRepresentation)
        try store.setCustomIcon(source, for: tab)
        let png = try XCTUnwrap(tab.appearance.customImage)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(bitmap.pixelsWide, 128)
        XCTAssertEqual(bitmap.pixelsHigh, 128)
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.selected?.appearance.customImage, png)
        store.duplicate(tab)
        XCTAssertEqual(store.selected?.appearance.customImage, png)
        store.setIcon(.codex, for: store.selected!)
        XCTAssertNil(store.selected?.appearance.customImage)
        XCTAssertEqual(tab.appearance.customImage, png)
    }
    func testOldWorkspaceAndInvalidUpload() throws {
        let legacy = Data("[{\"title\":\"Existing\",\"kind\":\"terminal\",\"directory\":\"/tmp\",\"pinned\":false}]".utf8)
        defaults.set(legacy, forKey: "workspace")
        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.selected?.title, "Existing")
        XCTAssertEqual(restored.selected?.appearance, TabAppearance())
        store.setIcon(.codex, for: store.selected!)
        XCTAssertThrowsError(try store.setCustomIcon(Data("invalid image".utf8), for: store.selected!))
        XCTAssertEqual(store.selected?.appearance.preset, .codex)
    }
    func testRapidClosePreventsDelayedShellLaunch() {
        store.newTerminal(directory: "/tmp")
        let tab = store.selected!
        let session = tab.session!
        store.close(tab)
        session.start(shell: "/bin/zsh")
        XCTAssertTrue(session.isClosed)
        XCTAssertFalse(session.started)
        XCTAssertFalse(session.isRunning)
        XCTAssertEqual(session.view.process.shellPid, 0)
        store.select(tab)
        XCTAssertNotEqual(store.selectedID, tab.id)
    }
}

@MainActor
final class IconAssetTests: XCTestCase {
    func testAllBrandMarksLoad() throws {
        _ = NSApplication.shared
        for name in ["claude", "codex", "opencode", "docker", "github"] {
            let image = try XCTUnwrap(IconImages.bundled(name), "Missing or unsupported \(name) icon")
            XCTAssertTrue(image.isValid)
        }
    }
}

@MainActor
final class TerminalPTYTests: XCTestCase {
    func waitUntil(_ condition: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Terminal condition did not become true within ten seconds", file: file, line: line)
    }

    func testRealShellOutputDirectoryAndInterrupt() async throws {
        _ = NSApplication.shared
        let shellHome = FileManager.default.temporaryDirectory.appendingPathComponent("termi-shell-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: shellHome, withIntermediateDirectories: true)
        let session = TerminalSession(directory: "/tmp")
        session.start(shell: "/bin/zsh", environmentOverrides: ["HOME": shellHome.path, "ZDOTDIR": shellHome.path])
        defer { session.stop(); try? FileManager.default.removeItem(at: shellHome) }
        XCTAssertTrue(session.isRunning)
        XCTAssertGreaterThan(session.view.process.shellPid, 0)
        session.view.send(txt: "printf '\\033[32mTERMI_PTY_%s\\033[0m\\n' OK\r")
        try await waitUntil { String(data: session.view.getTerminal().getBufferAsData(), encoding: .utf8)?.contains("TERMI_PTY_OK") == true }
        session.view.send(txt: "cd /\r")
        try await waitUntil { session.directory == "/" }
        session.view.send(txt: "cd /tmp\r")
        try await waitUntil { session.directory == "/tmp" }
        session.view.send(txt: "sleep 30\r")
        try await waitUntil { session.hasForegroundJob }
        session.view.send(txt: "\u{03}")
        try await waitUntil { !session.hasForegroundJob }
        session.view.send(txt: "printf 'TERMI_INTERRUPT_%s\\n' OK\r")
        try await waitUntil { String(data: session.view.getTerminal().getBufferAsData(), encoding: .utf8)?.contains("TERMI_INTERRUPT_OK") == true }
        XCTAssertTrue(session.isRunning)
    }
}
