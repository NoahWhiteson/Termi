import SwiftUI
import SwiftTerm

struct TerminalHost: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    var active: Bool
    final class Coordinator {
        var mounted = true
        var active = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let coordinator = context.coordinator
        coordinator.active = active
        DispatchQueue.main.async { [weak coordinator] in
            guard let coordinator, coordinator.mounted, !session.isClosed else { return }
            session.start()
            if coordinator.active { session.focus() }
        }
        return session.view
    }
    func updateNSView(_ view: LocalProcessTerminalView, context: Context) { context.coordinator.active = active }
    static func dismantleNSView(_ view: LocalProcessTerminalView, coordinator: Coordinator) { coordinator.mounted = false }
    // The Tab owns the native view and PTY, so SwiftUI can detach it without ending the shell.
}

struct TerminalContent: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                ForEach(Array(tab.sessions.enumerated()), id: \.element.id) { index, session in
                    VStack(spacing: 0) {
                        if tab.sessions.count > 1 {
                            HStack {
                                Circle().fill(tab.focusedPane == index ? Palette.accent : Palette.dim).frame(width: 5, height: 5)
                                Text("\(index + 1)  ·  \(displayPath(session.directory))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                Spacer()
                                IconButton(icon: "xmark", help: "Close pane", size: 22) { store.closeSplit(tab, index: index) }
                            }.padding(.horizontal, 18).frame(height: 32).background(Color.white.opacity(0.015))
                        }
                        TerminalHost(session: session, active: store.selectedID == tab.id && tab.focusedPane == index)
                            .padding(.horizontal, 17).padding(.top, 17).padding(.bottom, 12)
                            .onTapGesture { tab.focusedPane = index; session.focus() }
                    }.frame(minWidth: 230, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.background(Palette.background)
    }
}

func displayPath(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
}
