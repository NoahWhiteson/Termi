import SwiftUI
import AppKit

enum TabMotion {
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var layout: Animation {
        reduced ? .linear(duration: 0) : .spring(response: 0.18, dampingFraction: 1)
    }
    static var selection: Animation {
        reduced ? .linear(duration: 0) : .spring(response: 0.2, dampingFraction: 0.95)
    }
    static var content: Animation { .linear(duration: reduced ? 0 : 0.10) }
    static var scroll: Animation? { reduced ? nil : .easeOut(duration: 0.22) }
    static func tabTransition(horizontal: Bool) -> AnyTransition {
        if reduced { return .identity }
        return .asymmetric(
            insertion: .move(edge: horizontal ? .trailing : .leading),
            removal: .move(edge: horizontal ? .trailing : .leading)
        )
    }
}

extension View {
    @ViewBuilder
    func tabSelectionGeometry(in namespace: Namespace.ID) -> some View {
        if TabMotion.reduced { self.transition(.identity) }
        else { self.matchedGeometryEffect(id: "selected-tab", in: namespace).transition(.identity) }
    }
}

/// Keep visited pages mounted so switching preserves native terminal selection,
/// scroll positions, split sizes, web forms, and keyboard responders.
struct TabDeck: View {
    @ObservedObject var store: AppStore
    @State private var visited: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    private var staged: [Tab] { store.tabs.filter { visited.contains($0.id) || $0.id == store.selectedID } }
    var body: some View {
        ZStack {
            Palette.background
            ForEach(staged) { tab in
                let active = tab.id == store.selectedID
                TabPage(store: store, tab: tab)
                    .opacity(active ? 1 : 0)
                    .allowsHitTesting(active)
                    .accessibilityHidden(!active)
                    .zIndex(active ? 1 : 0)
                    .transition(reducedMotion ? .identity : .opacity)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(TabMotion.content, value: store.selectedID)
            .onAppear { if let id = store.selectedID { visited.insert(id) } }
            .onChange(of: store.selectedID) { _, id in
                // Staging is bookkeeping, not a second content transition.
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { if let id { visited.insert(id) } }
            }
            .onChange(of: store.tabs.map(\.id)) { _, ids in visited.formIntersection(ids) }
    }
}

private struct TabPage: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    var body: some View {
        Group {
            if tab.kind == .terminal { TerminalContent(store: store, tab: tab) }
            else { BrowserContent(tab: tab) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
